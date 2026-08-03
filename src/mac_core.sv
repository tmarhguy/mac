`timescale 1ns/1ps
// Deep Learning Hardware Accelerator Core
// Precision: BFloat16 (BF16) Multiplication -> IEEE-754 FP32 Accumulation
// Architecture: 2-Stage Pipeline (Fetch-Compute / Accumulate)
// Target Workload: Neural Network Inference / Training Kernels

module mac_core (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    input  logic        clr_acc, // Clear accumulator signal
    input  logic [15:0] a,       // Activation Tensor (BF16)
    input  logic [15:0] b,       // Weight Tensor (BF16)
    output logic [31:0] result,  // FP32
    output logic        overflow,
    output logic        valid
);

    localparam logic [31:0] FP32_QNAN = 32'h7FC00000;

    // =========================================================================
    // Pipeline Stage 1: Tensor Product
    // BF16 (1.8.7) -> FP32 (1.8.23) Expansion
    // =========================================================================

    // BF16 Format: [15] Sign, [14:7] Exp, [6:0] Mantissa (bias 127)
    // Subnormals treated as 0 (flush-to-zero).

    logic [31:0] product_fp32;
    logic        valid_s1;
    logic        overflow_s1;

    wire is_zero_a = (a[14:0] == 15'b0);
    wire is_zero_b = (b[14:0] == 15'b0);

    wire a_nan = (a[14:7] == 8'hFF) && (a[6:0] != 7'b0);
    wire b_nan = (b[14:7] == 8'hFF) && (b[6:0] != 7'b0);
    wire a_inf = (a[14:7] == 8'hFF) && (a[6:0] == 7'b0);
    wire b_inf = (b[14:7] == 8'hFF) && (b[6:0] == 7'b0);

    logic        new_sign;
    logic [8:0]  exp_sum;
    logic [7:0]  ma, mb;
    logic [15:0] m_prod;
    logic [8:0]  final_exp_wide;
    logic [7:0]  final_exp;
    logic [22:0] final_mant;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_fp32 <= 32'b0;
            valid_s1     <= 1'b0;
            overflow_s1  <= 1'b0;
        end else if (en) begin
            valid_s1    <= 1'b1;
            overflow_s1 <= 1'b0;
            new_sign    = a[15] ^ b[15];

            if (a_nan || b_nan) begin
                product_fp32 <= FP32_QNAN;
            end else if ((a_inf && is_zero_b) || (b_inf && is_zero_a)) begin
                product_fp32 <= FP32_QNAN;
            end else if (a_inf || b_inf) begin
                product_fp32 <= {new_sign, 8'hFF, 23'b0};
            end else if (is_zero_a || is_zero_b) begin
                product_fp32 <= 32'b0;
            end else begin
                exp_sum = {1'b0, a[14:7]} + {1'b0, b[14:7]};

                ma    = {1'b1, a[6:0]};
                mb    = {1'b1, b[6:0]};
                m_prod = ma * mb;

                if (m_prod[15]) begin
                    final_exp_wide = {1'b0, exp_sum} - 9'd127 + 9'd1;
                    final_mant     = {m_prod[14:0], 8'b0};
                end else begin
                    final_exp_wide = {1'b0, exp_sum} - 9'd127;
                    final_mant     = {m_prod[13:0], 9'b0};
                end

                if (final_exp_wide >= 9'd255) begin
                    product_fp32 <= {new_sign, 8'hFF, 23'b0};
                    overflow_s1  <= 1'b1;
                end else if (final_exp_wide == 9'd0 || final_exp_wide[8]) begin
                    product_fp32 <= 32'b0;
                end else begin
                    final_exp      = final_exp_wide[7:0];
                    product_fp32 <= {new_sign, final_exp, final_mant};
                end
            end
        end else begin
            valid_s1 <= 1'b0;
        end
    end

    // =========================================================================
    // Pipeline Stage 2: Partial Sum Accumulation
    // FP32 Adder with Dynamic Normalization
    // =========================================================================
    logic [31:0] acc_reg;

    wire fp32_nan_acc  = (acc_reg[30:23] == 8'hFF) && (acc_reg[22:0] != 23'b0);
    wire fp32_nan_prod = (product_fp32[30:23] == 8'hFF) && (product_fp32[22:0] != 23'b0);
    wire fp32_inf_acc  = (acc_reg[30:23] == 8'hFF) && (acc_reg[22:0] == 23'b0);
    wire fp32_inf_prod = (product_fp32[30:23] == 8'hFF) && (product_fp32[22:0] == 23'b0);

    logic        sa, sb;
    logic [7:0]  ea, eb;
    logic [23:0] ma_s2, mb_s2;
    logic [8:0]  e_res_wide;
    logic [7:0]  e_res;
    logic [27:0] ma_aligned, mb_aligned;
    logic [27:0] m_sum;
    logic        s_res;
    logic [31:0] next_acc;
    logic        overflow_add;

    logic [4:0]  shift_amt;
    integer      i;
    logic [27:0] m_sum_shifted;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg  <= 32'b0;
            overflow <= 1'b0;
            valid    <= 1'b0;
        end else if (clr_acc) begin
            acc_reg  <= 32'b0;
            overflow <= 1'b0;
            valid    <= 1'b0;
        end else if (valid_s1) begin
            overflow_add = 1'b0;

            if (fp32_nan_acc || fp32_nan_prod) begin
                next_acc = FP32_QNAN;
            end else if (fp32_inf_acc && fp32_inf_prod && (acc_reg[31] != product_fp32[31])) begin
                next_acc = FP32_QNAN;
            end else if (fp32_inf_acc) begin
                next_acc = acc_reg;
            end else if (fp32_inf_prod) begin
                next_acc = product_fp32;
            end else begin
                sa = acc_reg[31];
                ea = acc_reg[30:23];
                ma_s2 = {1'b1, acc_reg[22:0]};
                if (acc_reg[30:23] == 8'b0) ma_s2 = 24'b0;

                sb = product_fp32[31];
                eb = product_fp32[30:23];
                mb_s2 = {1'b1, product_fp32[22:0]};
                if (product_fp32[30:23] == 8'b0) mb_s2 = 24'b0;

                if (ea >= eb) begin
                    e_res        = ea;
                    ma_aligned   = {ma_s2, 3'b0};
                    mb_aligned   = {mb_s2, 3'b0} >> (ea - eb);
                end else begin
                    e_res        = eb;
                    ma_aligned   = {ma_s2, 3'b0} >> (eb - ea);
                    mb_aligned   = {mb_s2, 3'b0};
                end

                if (sa == sb) begin
                    s_res = sa;
                    m_sum = ma_aligned + mb_aligned;
                end else begin
                    if (ma_aligned >= mb_aligned) begin
                        s_res = sa;
                        m_sum = ma_aligned - mb_aligned;
                    end else begin
                        s_res = sb;
                        m_sum = mb_aligned - ma_aligned;
                    end
                end

                if (m_sum[27]) begin
                    if (e_res >= 8'd254) begin
                        next_acc     = {s_res, 8'hFF, 23'b0};
                        overflow_add = 1'b1;
                    end else begin
                        e_res_wide   = {1'b0, e_res} + 9'd1;
                        next_acc     = {s_res, e_res_wide[7:0], m_sum[26:4]};
                    end
                end else begin
                    shift_amt = 5'd27;

                    for (i = 26; i >= 0; i = i - 1) begin
                        if (m_sum[i] && (shift_amt == 5'd27)) begin
                            shift_amt = 26 - i[4:0];
                        end
                    end

                    if (shift_amt == 5'd27) begin
                        next_acc = 32'b0;
                    end else if (e_res <= shift_amt) begin
                        next_acc = 32'b0;
                    end else begin
                        e_res_wide = {1'b0, e_res} - {4'b0, shift_amt};
                        if (e_res_wide[8]) begin
                            next_acc = 32'b0;
                        end else begin
                            e_res          = e_res_wide[7:0];
                            m_sum_shifted  = m_sum << shift_amt;
                            next_acc       = {s_res, e_res, m_sum_shifted[25:3]};
                        end
                    end
                end
            end

            acc_reg  <= next_acc;
            overflow <= overflow | overflow_s1 | overflow_add;
            valid    <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end

    assign result = acc_reg;

endmodule

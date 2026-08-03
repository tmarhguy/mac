`timescale 1ns/1ps
// Tensor Processing Unit (TPU) Wrapper
// Interface: 4-Cycle Streaming Tensor Bus
// Target: TinyTapeout 07 Process Node

module tt_um_tensor_mac (
    input  wire [7:0] ui_in,    // Data Input (Time multiplexed)
    output wire [7:0] uo_out,   // Result Output Low/High
    input  wire [7:0] uio_in,   // Unused (or secondary config?)
    output wire [7:0] uio_out,  // Result Output Low/High
    output wire [7:0] uio_oe,   // Direction control
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // =========================================================================
    // IO Configuration
    // =========================================================================
    // uio is ALWAYS OUTPUT in this design to maximize bandwidth
    assign uio_oe = 8'hFF; 

    // =========================================================================
    // Internal Signals
    // =========================================================================
    reg [1:0]  state_cnt; // 0..3 counter
    reg [15:0] operand_a;
    reg [15:0] operand_b;
    wire [31:0] result;
    wire        overflow, valid;
    reg         compute_trigger;

    // Output Registers (Buffer result to keep it stable during 4-cycle load)
    reg [31:0] result_buffer;

    // =========================================================================
    // FSM / Streaming Controller
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_cnt <= 2'b00;
            operand_a <= 16'b0;
            operand_b <= 16'b0;
            compute_trigger <= 1'b0;
            result_buffer <= 32'b0;
        end else if (ena) begin
            // Free running 4-cycle counter
            state_cnt <= state_cnt + 1;
            
            case (state_cnt)
                2'b00: begin
                    operand_a[7:0] <= ui_in; // Latch Activation [7:0]
                    compute_trigger <= 1'b0;
                    // Update Output Buffer at start of new cycle (from previous MAC)
                    // If Valid was high last cycle? 
                    // Let's just update buffer freely or when valid?
                    // For streaming, we assume valid completes.
                    // Let's capture result if valid? Or just async assign?
                end
                2'b01: begin
                    operand_a[15:8] <= ui_in; // Latch Activation [15:8]
                end
                2'b10: begin
                    operand_b[7:0] <= ui_in; // Latch Weight [7:0]
                    // If we have a valid result from previous OP, buffer it now?
                    // Actually, result updates after compute_trigger.
                end
                2'b11: begin
                    operand_b[15:8] <= ui_in; // Latch Weight [15:8]
                    compute_trigger <= 1'b1;  // Execute Kernel
                end
            endcase
            
            // Result Buffer Logic
            // The MAC core takes valid inputs and produces valid output in same/next cycle?
            // Our MAC is pipeline stage 1 (mult) -> stage 2 (acc).
            // compute_trigger High at T3.
            // T4(T0): S1 validates.
            // T5(T1): S2 validates. Result ready at T1 of NEXT cycle.
            // So we should capture result when `valid` is high.
            if (valid) begin
                result_buffer <= result;
            end
        end
    end

    // Instance
    mac_core mac_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(compute_trigger),
        .clr_acc(1'b0), // Accumulate only. Reset via rst_n.
        .a(operand_a),
        .b(operand_b),
        .result(result),
        .overflow(overflow), // Ignore for now
        .valid(valid)
    );

    // =========================================================================
    // Output Multiplexing
    // =========================================================================
    // Cycles 0,1: Show Lower 16 bits
    // Cycles 2,3: Show Upper 16 bits
    
    // Using result_buffer to ensure stability during read
    wire [15:0] out_word;
    assign out_word = (state_cnt[1] == 1'b0) ? result_buffer[15:0] : result_buffer[31:16];
    
    assign uo_out  = out_word[7:0];
    assign uio_out = out_word[15:8];

endmodule

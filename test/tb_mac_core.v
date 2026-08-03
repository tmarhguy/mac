`default_nettype none
`timescale 1ns / 1ps

module tb_mac_core ();

    initial begin
        $dumpfile("tb_mac_core.vcd");
        $dumpvars(0, tb_mac_core);
        #1;
    end

    reg clk;
    reg rst_n;
    reg en;
    reg clr_acc;
    reg [15:0] a;
    reg [15:0] b;
    wire [31:0] result;
    wire overflow;
    wire valid;

    mac_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .clr_acc(clr_acc),
        .a(a),
        .b(b),
        .result(result),
        .overflow(overflow),
        .valid(valid)
    );

endmodule

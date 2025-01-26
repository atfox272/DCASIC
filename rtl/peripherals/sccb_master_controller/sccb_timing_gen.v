/*

The minimum of SIO_C cycle is 10us -> maximum frequency is 100kHz -> maximum toggle frequency is 200kHz

*/
module sccb_timing_gen #(
    parameter INTERNAL_CLK_FREQ = 125_000_000,
    parameter MAX_SCCB_FREQ     = 100_000,
    // Configuarion Bus 
    parameter DATA_W            = 8
) (
    // Input declaration
    input                   clk,
    input                   rst_n,
    // -- SCCB FSM
    input                   cntr_en_i,
    // -- Configuration registers
    // TODO: Add configuration registers
    input [DATA_W-1:0]      prescaler_i,

    // Output declaration
    // -- SCCB FSM 
    output                  tick_en_o,
    output                  sio_c_tgl_en_o
);

    // Local parameters declaration
    localparam SIOC_HCYC_CNT    = INTERNAL_CLK_FREQ / (MAX_SCCB_FREQ*2); // SIO_C half cycle counter
    localparam SIOC_HCYC_CNT_W  = $clog2(SIOC_HCYC_CNT);

    // Internal signals declaration
    // -- reg
    reg    [SIOC_HCYC_CNT_W-1:0]    sio_c_hcyc_cnt;

    // Comnbination logic
    assign tick_en_o = ~|(sio_c_hcyc_cnt ^ (SIOC_HCYC_CNT>>1));
    assign sio_c_tgl_en_o = ~|(sio_c_hcyc_cnt ^ (SIOC_HCYC_CNT-1));
    // Flip-flops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sio_c_hcyc_cnt <= {SIOC_HCYC_CNT_W{1'b0}};
        end 
        else begin
            if (cntr_en_i) begin
                if (~|(sio_c_hcyc_cnt ^ (SIOC_HCYC_CNT-1))) begin
                    sio_c_hcyc_cnt <= {SIOC_HCYC_CNT_W{1'b0}};
                end else begin
                    sio_c_hcyc_cnt <= sio_c_hcyc_cnt + 1'b1;
                end
            end
            else begin
                sio_c_hcyc_cnt <= {SIOC_HCYC_CNT_W{1'b0}};
            end
        end
    end
endmodule
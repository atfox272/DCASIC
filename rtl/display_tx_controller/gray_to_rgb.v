module gray_to_rgb 
#(
    parameter GRAY_PXL_W    = 8,
    parameter RGB_PXL_W     = 16,
    parameter RGB_SPLIT_W   = 8
)
(
    // Input declaration 
    input                       clk,
    input                       rst_n,
    // -- To AXI4 FIFO
    input   [GRAY_PXL_W-1:0]    gray_pxl_dat_i,
    input                       gray_pxl_vld_i,
    // -- To DBI TX FSM
    input                       rgb_pxl_rdy_i,
    // Output declaration
    // -- To AXI4 FIFO
    output                      gray_pxl_rdy_o,
    // -- To DBI TX FSM
    output  [RGB_SPLIT_W-1:0]   rgb_pxl_dat_o,
    output                      rgb_pxl_vld_o
);
    // Internal signal
    // -- wire
    // -- -- RGB565
    wire    [4:0]               pxl_r_dat;
    wire    [5:0]               pxl_g_dat;
    wire    [4:0]               pxl_b_dat;
    wire    [RGB_PXL_W-1:0]     rgb_pxl_dat; 
    wire    [RGB_SPLIT_W-1:0]   rgb_pxl_dat_hi; 
    wire    [RGB_SPLIT_W-1:0]   rgb_pxl_dat_lo; 
    wire                        rgb_pxl_hsk;
    // -- reg
    reg                         rgb_pxl_lo_flag;

    // Combination logic
    assign rgb_pxl_dat_o    = rgb_pxl_lo_flag ? rgb_pxl_dat_lo : rgb_pxl_dat_hi;
    assign rgb_pxl_vld_o    = gray_pxl_vld_i;
    assign gray_pxl_rdy_o   = rgb_pxl_lo_flag & rgb_pxl_rdy_i;
    assign rgb_pxl_hsk      = rgb_pxl_vld_o & rgb_pxl_rdy_i;
    assign rgb_pxl_dat_hi   = rgb_pxl_dat[RGB_PXL_W-1-:RGB_SPLIT_W];
    assign rgb_pxl_dat_lo   = rgb_pxl_dat[RGB_SPLIT_W-1-:RGB_SPLIT_W];
    assign rgb_pxl_dat      = {pxl_r_dat, pxl_g_dat, pxl_b_dat};
    assign pxl_r_dat        = gray_pxl_dat_i[4:0];
    assign pxl_g_dat        = gray_pxl_dat_i[5:0];
    assign pxl_b_dat        = gray_pxl_dat_i[4:0];
    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rgb_pxl_lo_flag = 1'b0;
        end
        else if (rgb_pxl_hsk) begin
            rgb_pxl_lo_flag = ~rgb_pxl_lo_flag;
        end
    end
endmodule
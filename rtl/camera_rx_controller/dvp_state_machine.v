// This state machine is a gate for data collection and error detection
module dvp_state_machine
#(
    parameter DVP_DATA_W        = 8,
    parameter PXL_INFO_W        = DVP_DATA_W + 1 + 1,   // FIFO_W =  VSYNC + HSYNC + PIXEL_W
    parameter RGB_PXL_W         = 16,
    parameter GS_PXL_W          = 8
)
(
    // Input declaration
    // -- Global
    input                       clk,
    input                       rst_n,
    // -- Pixel FIFO
    input   [PXL_INFO_W-1:0]    pxl_info_i,
    input                       pxl_info_vld_i,
    // -- DVP configuration register
    input                       dcr_cam_start_i,
    // -- Gray-scale
    input                       rgb_pxl_rdy_i,
    // Output declaration
    // -- Pixel FIFO
    output                      pxl_info_rdy_o,
    // -- Gray-scale 
    output  [RGB_PXL_W-1:0]     rgb_pxl_o,
    output                      rgb_pxl_vld_o
);
    // Local parameter 
    localparam IDLE_ST  = 1'd0;
    localparam WORK_ST  = 1'd1;
    // Internal signal 
    // -- wire
    wire    [DVP_DATA_W-1:0]    dvp_pxl_data;
    reg                         dvp_st_d;
    wire                        pxl_info_vld;
    wire                        pxl_info_rdy;
    // -- reg
    reg                         dvp_st_q;
    
    // Internal module
    sync_fifo 
    #(
        .FIFO_TYPE      (3),        // Concat FIFO
        .DATA_WIDTH     (RGB_PXL_W),
        .IN_DATA_WIDTH  (DVP_DATA_W),
        .CONCAT_ORDER   ("MSB")
    ) concat_fifo (
        .clk            (clk),
        .data_i         (dvp_pxl_data),
        .data_o         (rgb_pxl_o),
        .wr_valid_i     (pxl_info_vld),
        .wr_ready_o     (pxl_info_rdy),
        .rd_valid_i     (rgb_pxl_rdy_i),
        .rd_ready_o     (rgb_pxl_vld_o),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    
    // Combination logic
    assign pxl_info_rdy_o = pxl_info_rdy & (~|(dvp_st_q^WORK_ST));
    assign pxl_info_vld = pxl_info_vld_i & (~|(dvp_st_q^WORK_ST));
    assign dvp_pxl_data =  pxl_info_i[DVP_DATA_W-1:0];
    always @* begin
        dvp_st_d = dvp_st_q;
        case(dvp_st_q) 
            IDLE_ST: begin
                if(dcr_cam_start_i) begin
                    dvp_st_d = WORK_ST;
                end
            end
            WORK_ST: begin
                // Updated in next versions 
                // - Check VSYNC & HSYNC -> Error Interrupt
                // - Collect signle frame mode
                // - Stall mode
            end
        endcase
    end
    
    // Flip-flop 
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dvp_st_q <= 1'd0;
        end
        else begin
            dvp_st_q <= dvp_st_d;
        end
    end
endmodule

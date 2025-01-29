module pixel_downscaler_fifo
#(
    // Downscaler method configuration 
    parameter DOWNSCALE_TYPE    = 1,    // 0: AveragePooling || 1" MaxPooling
    // Pixel configuration
    parameter GS_PXL_W          = 8,
    parameter COL_NUM           = 640,
    parameter ROW_NUM           = 480
)
(
    // Input declaration
    // -- Global
    input                   clk,
    input                   rst_n,
    // -- DVP State machine
    input   [GS_PXL_W-1:0]  dsm_pxl_i,
    input                   dsm_pxl_vld_i,
    // -- Pixel AXI4 Master TX
    input                   pat_rdy_i,
    // Output declaration
    // -- DVP State machine
    output                  dsm_pxl_rdy_o,
    // -- Pixel AXI4 Master TX
    output  [GS_PXL_W-1:0]  pat_pxl_o,
    output                  pat_pxl_vld_o
);
    // Local parameter 
    localparam COL_CTN_W = $clog2(COL_NUM);
    localparam ROW_CTN_W = $clog2(ROW_NUM);
    
    // Internal signal
    // -- wire
    wire                    hsm_hsk;    // DSM handshake
    wire                    col_last;
    wire    [COL_CTN_W-1:0] col_ctn_d;
    wire                    row_odd_d;
    wire    [GS_PXL_W-1:0]  pf_data_o_map   [0:3];
    wire                    pf_wr_rdy_map   [0:3];
    wire                    pf_wr_vld_map   [0:3];
    wire                    pf_rd_rdy_map   [0:3];
    wire                    pf_rd_vld_map   [0:3];
    wire                    pat_rdy;
    wire                    pat_hsk;
    // -- reg
    reg     [COL_CTN_W-1:0] col_ctn_q;
    reg                     row_odd_q;
    
    // Internal module
    // -- Pixel FIFO for FIRST PIXEL in scaling block
    sync_fifo #(
        .FIFO_TYPE  (1),        // Non-registered output -> If VIOLATED timing path -> Set it to "2"
        .DATA_WIDTH (GS_PXL_W),
        .FIFO_DEPTH (1<<$clog2(COL_NUM/2))
    ) frist_pixel_fifo (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_i         (dsm_pxl_i),
        .data_o         (pf_data_o_map[0]),
        .wr_valid_i     (pf_wr_vld_map[0]),
        .rd_valid_i     (pat_hsk),
        .empty_o        (),
        .full_o         (),
        .wr_ready_o     (pf_wr_rdy_map[0]),
        .rd_ready_o     (pf_rd_rdy_map[0]),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        ()
    );
    // -- Pixel FIFO for SECOND PIXEL in scaling block
    sync_fifo #(
        .FIFO_TYPE  (1),        // Non-registered output -> If VIOLATED timing path -> Set it to "2"
        .DATA_WIDTH (GS_PXL_W),
        .FIFO_DEPTH (1<<$clog2(COL_NUM/2))
    ) second_pixel_fifo (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_i         (dsm_pxl_i),
        .data_o         (pf_data_o_map[1]),
        .wr_valid_i     (pf_wr_vld_map[1]),
        .rd_valid_i     (pat_hsk),
        .empty_o        (),
        .full_o         (),
        .wr_ready_o     (pf_wr_rdy_map[1]),
        .rd_ready_o     (pf_rd_rdy_map[1]),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        ()
    );
    // -- Pixel FIFO for THIRD PIXEL in scaling block
    sync_fifo #(
        .FIFO_TYPE  (1),        // Non-registered output -> If VIOLATED timing path -> Set it to "2"
        .DATA_WIDTH (GS_PXL_W),
        .FIFO_DEPTH (2)
    ) third_pixel_fifo (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_i         (dsm_pxl_i),
        .data_o         (pf_data_o_map[2]),
        .wr_valid_i     (pf_wr_vld_map[2]),
        .rd_valid_i     (pat_hsk),
        .empty_o        (),
        .full_o         (),
        .wr_ready_o     (pf_wr_rdy_map[2]),
        .rd_ready_o     (pf_rd_rdy_map[2]),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        ()
    );
    // -- Pixel FIFO for FOURTH PIXEL in scaling block
    sync_fifo #(
        .FIFO_TYPE  (1),        // Non-registered output -> If VIOLATED timing path -> Set it to "2"
        .DATA_WIDTH (GS_PXL_W),
        .FIFO_DEPTH (2)
    ) fourth_pixel_fifo (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_i         (dsm_pxl_i),
        .data_o         (pf_data_o_map[3]),
        .wr_valid_i     (pf_wr_vld_map[3]),
        .rd_valid_i     (pat_hsk),
        .empty_o        (),
        .full_o         (),
        .wr_ready_o     (pf_wr_rdy_map[3]),
        .rd_ready_o     (pf_rd_rdy_map[3]),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        ()
    );
    // Combination logic
    assign dsm_pxl_rdy_o    = pf_wr_rdy_map[{row_odd_q, col_ctn_q[0]}];
    assign pat_pxl_vld_o    = (pf_rd_rdy_map[0] & pf_rd_rdy_map[1] & pf_rd_rdy_map[2] & pf_rd_rdy_map[3]);
    assign pat_rdy          = pat_rdy_i;
    assign pat_hsk          = pat_pxl_vld_o & pat_rdy;
    assign hsm_hsk          = dsm_pxl_vld_i & dsm_pxl_rdy_o;
    assign col_last         = ~|(col_ctn_q^(COL_NUM - 1));
    assign col_ctn_d        = (col_last) ? {COL_CTN_W{1'b0}} : col_ctn_q + 1'b1;
    assign row_odd_d        = row_odd_q + col_last;
    assign pf_wr_vld_map[0] = dsm_pxl_vld_i & ((~col_ctn_q[0]) & (~row_odd_q));
    assign pf_wr_vld_map[1] = dsm_pxl_vld_i & (col_ctn_q[0]    & (~row_odd_q));
    assign pf_wr_vld_map[2] = dsm_pxl_vld_i & ((~col_ctn_q[0]) & row_odd_q);
    assign pf_wr_vld_map[3] = dsm_pxl_vld_i & (col_ctn_q[0]    & row_odd_q);
    generate
    if(DOWNSCALE_TYPE == 0) begin : AVG_POOL
        assign pat_pxl_o = (pf_data_o_map[0] + pf_data_o_map[1] + pf_data_o_map[2] + pf_data_o_map[3]) >> 2;
    end
    else if(DOWNSCALE_TYPE == 1) begin : MAX_POOL
        wire [GS_PXL_W-1:0] pxl_tournament_0;
        wire [GS_PXL_W-1:0] pxl_tournament_1;
        assign pxl_tournament_0 = (pf_data_o_map[0] > pf_data_o_map[1]) ? pf_data_o_map[0] : pf_data_o_map[1];
        assign pxl_tournament_1 = (pf_data_o_map[2] > pf_data_o_map[3]) ? pf_data_o_map[2] : pf_data_o_map[3];
        assign pat_pxl_o        = (pxl_tournament_0 > pxl_tournament_1) ? pxl_tournament_0 : pxl_tournament_1;
    end
    endgenerate
    // Flip-flop
    // -- Column counter
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            col_ctn_q <= {COL_CTN_W{1'b0}};
        end
        else if(hsm_hsk) begin
            col_ctn_q <= col_ctn_d;
        end
    end
    // -- Odd row flag 
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            row_odd_q <= 1'b0;
        end
        else if(hsm_hsk) begin
            row_odd_q <= row_odd_d;
        end
    end
endmodule

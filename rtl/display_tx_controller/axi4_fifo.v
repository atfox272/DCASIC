module axi4_fifo 
#(
    // AXI4 Interface
    parameter DATA_W            = 256,
    parameter ADDR_W            = 32,
    parameter MST_ID_W          = 5,
    parameter TRANS_DATA_LEN_W  = 8,
    parameter TRANS_DATA_SIZE_W = 3,
    parameter TRANS_RESP_W      = 2,
    // Memory Mapping
    parameter BASE_ADDR         = 32'h2000_0000,
    // Module configuration
    parameter DBI_IF_D_W        = 8,
    parameter W_FIFO_CAPAC      = 2    // x 256bit-width (carefully)
) 
(
    // Input declaration
    input                       clk,
    input                       rst_n,
    // -- To AXI4 Master
    // -- -- AW channel
    input   [MST_ID_W-1:0]      m_awid_i,
    input   [ADDR_W-1:0]        m_awaddr_i,
    input                       m_awvalid_i,
    // -- -- W channel
    input   [DATA_W-1:0]        m_wdata_i,
    input                       m_wlast_i,
    input                       m_wvalid_i,
    // -- -- B channel
    input                       m_bready_i,
    // -- To DBI TX PHY
    input                       dtp_d_rdy_i,
    // Output declaration
    // -- To AXI4 Master
    // -- -- AW channel
    output                      m_awready_o,
    // -- -- W channel
    output                      m_wready_o,
    // -- -- B channel
    output  [MST_ID_W-1:0]      m_bid_o,
    output  [TRANS_RESP_W-1:0]  m_bresp_o,
    output                      m_bvalid_o,
    // -- To DBI TX PHY
    output  [DBI_IF_D_W-1:0]    dtp_d_data_o,
    output                      dtp_d_vld_o

);
    // Local parameters
    localparam AW_INFO_W    = MST_ID_W + ADDR_W;
    localparam W_INFO_W     = DATA_W + 1;
    localparam B_INFO_W     = MST_ID_W + TRANS_RESP_W;

    // Internal signal
    // -- wire
    wire [AW_INFO_W-1:0]    bwd_aw_info;
    wire [AW_INFO_W-1:0]    fwd_aw_info;
    wire [MST_ID_W-1:0]     fwd_aw_awid;
    wire [ADDR_W-1:0]       fwd_aw_awaddr;
    wire                    fwd_aw_vld;
    wire                    fwd_aw_rdy;

    wire [B_INFO_W-1:0]     bwd_b_info;
    wire [MST_ID_W-1:0]     bwd_b_bid;
    wire [TRANS_RESP_W-1:0] bwd_b_bresp;
    wire                    bwd_b_vld;
    wire                    bwd_b_rdy;
    wire [B_INFO_W-1:0]     fwd_b_info;
    wire [MST_ID_W-1:0]     fwd_b_bid;
    wire [TRANS_RESP_W-1:0] fwd_b_bresp;

    wire [W_INFO_W-1:0]     wb_wr_data;
    wire [W_INFO_W-1:0]     wb_rd_data;
    wire                    wb_rd_wlast;
    wire [DATA_W-1:0]       wb_rd_wdata;
    wire                    wb_wr_vld;
    wire                    wb_wr_rdy;
    wire                    wb_rd_vld;
    wire                    wb_rd_rdy;

    wire                    aw_map_vld;   // Valid address mapping
    wire                    bwd_w_hsk;    // W channel handshaking   

    // Internal module
    // -- AW channel buffer
    skid_buffer #(
        .SBUF_TYPE      (2),      // Light-weight
        .DATA_WIDTH     (AW_INFO_W)
    ) aw_buf (  
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_data_i     (bwd_aw_info),
        .bwd_valid_i    (m_awvalid_i),
        .fwd_ready_i    (fwd_aw_rdy),
        .fwd_data_o     (fwd_aw_info),
        .bwd_ready_o    (m_awready_o),
        .fwd_valid_o    (fwd_aw_vld)
    );
    // -- W channel
    // -- -- Front-FIFO
    sync_fifo #(
        .FIFO_TYPE      (1),             // Normal FIFO  
        .DATA_WIDTH     (W_INFO_W),      // WDATA + WLAST
        .FIFO_DEPTH     (W_FIFO_CAPAC)
    ) w_buf (
        .clk            (clk),
        .data_i         (wb_wr_data),
        .data_o         (wb_rd_data),
        .wr_valid_i     (wb_wr_vld),
        .rd_valid_i     (wb_rd_vld),
        .empty_o        (),
        .full_o         (),
        .wr_ready_o     (wb_wr_rdy),
        .rd_ready_o     (wb_rd_rdy),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    // -- -- Back-FIFO (Deconcat FIFO)
    sync_fifo #(
        .FIFO_TYPE      (4),     // Deconcat FIFO  
        .DATA_WIDTH     (),      // Don't care
        .IN_DATA_WIDTH  (DATA_W),
        .OUT_DATA_WIDTH (DBI_IF_D_W),
        .FIFO_DEPTH     ()       // Don't care
    ) dbi_d_buf (   
        .clk            (clk),
        .data_i         (wb_rd_wdata),
        .data_o         (dtp_d_data_o),
        .wr_valid_i     (wb_rd_rdy),
        .rd_valid_i     (dtp_d_rdy_i),
        .empty_o        (),
        .full_o         (),
        .wr_ready_o     (wb_rd_vld),
        .rd_ready_o     (dtp_d_vld_o),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    // -- B channel buffer
    skid_buffer #(
        .SBUF_TYPE      (2),      // Light-weight
        .DATA_WIDTH     (B_INFO_W)
    ) b_buf (   
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_data_i     (bwd_b_info),
        .bwd_valid_i    (bwd_b_vld),
        .fwd_ready_i    (m_bready_i),
        .fwd_data_o     (fwd_b_info),
        .bwd_ready_o    (/* N/C */),
        .fwd_valid_o    (m_bvalid_o)
    );

    // Combination logic
    assign m_wready_o   = fwd_aw_vld & (wb_wr_rdy | (~aw_map_vld)); // Wrong mapping -> Fake handshaking to skip all W transfers
    assign m_bid_o      = fwd_b_bid;
    assign m_bresp_o    = fwd_b_bresp;

    // AW channel
    assign bwd_aw_info  = {m_awid_i, m_awaddr_i};
    assign fwd_aw_rdy   = bwd_w_hsk & m_wlast_i;
    assign {fwd_aw_awid, fwd_aw_awaddr} = fwd_aw_info;

    // W channel
    assign wb_wr_vld    = fwd_aw_vld & aw_map_vld & m_wvalid_i;     // Just buffer VALID mapped transfers    
    assign wb_wr_data   = {m_wlast_i, m_wdata_i};
    assign bwd_w_hsk    = m_wvalid_i & m_wready_o;
    assign {wb_rd_wlast, wb_rd_wdata} = wb_rd_data;

    // B channel
    assign bwd_b_info   = {bwd_b_bid, bwd_b_bresp};
    assign bwd_b_bid    = fwd_aw_awid;
    assign bwd_b_bresp  = aw_map_vld ? 2'b00 : 2'b11;
    assign bwd_b_vld    = bwd_w_hsk & m_wlast_i;
    assign {fwd_b_bid, fwd_b_bresp} = fwd_b_info;

    // Common
    assign aw_map_vld   = ~|(fwd_aw_awaddr^(BASE_ADDR));

endmodule
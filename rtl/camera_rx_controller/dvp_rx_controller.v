module dvp_rx_controller
#(
    // System
    parameter INTERNAL_CLK          = 125_000_000,
    // Downscaler
    parameter DOWNSCALE_TYPE        = 1,    // 0: AveragePooling || 1" MaxPooling
    // AXI configuration
    // -- For AXI4 Slave interface  (DVP Configuration)
    parameter DATA_W                = 32,
    // -- For AXI4 Master interface (Pixel AXI4 TX)
    parameter TX_DATA_W             = 256,
    // -- Common    
    parameter ADDR_W                = 32,
    parameter MST_ID_W              = 5,
    parameter TRANS_DATA_LEN_W      = 8,
    parameter TRANS_DATA_SIZE_W     = 3,
    parameter TRANS_RESP_W          = 2,
    // Memory Mapping
    parameter IP_CONF_BASE_ADDR     = 32'h4000_0000,        // Memory mapping - BASE
    parameter IP_CONF_OFFSET_ADDR   = 32'h04,               // Memory mapping - OFFSET
    // DVP configuration
    parameter DVP_DATA_W            = 8,
    parameter PXL_INFO_W            = DVP_DATA_W + 1 + 1,   // FIFO_W =  VSYNC + HSYNC + PIXEL_W
    parameter RGB_PXL_W             = 16,
    parameter GS_PXL_W              = 8
)
(
    // Input declaration
    input                           clk,
    input                           rst_n,
    // -- DVP RX interface
    input   [DVP_DATA_W-1:0]        dvp_d_i,
    input                           dvp_href_i,
    input                           dvp_vsync_i,
    input                           dvp_hsync_i,
    input                           dvp_pclk_i,
    // -- AXI4 interface (pixel transfer)
    // -- -- AW channel
    input                           s_awready_i,
    // -- -- W channel
    input                           s_wready_i,
    // -- -- B channel
    input   [MST_ID_W-1:0]          s_bid_i,
    input   [TRANS_RESP_W-1:0]      s_bresp_i,
    input                           s_bvalid_i,
    // -- AXI4 interface (configuration)
    // -- -- AW channel
    input   [MST_ID_W-1:0]          m_awid_i,
    input   [ADDR_W-1:0]            m_awaddr_i,
    input                           m_awvalid_i,
    // -- -- W channel
    input   [DATA_W-1:0]            m_wdata_i,
    input                           m_wvalid_i,
    // -- -- B channel
    input                           m_bready_i,
    // -- -- AR channel
    input   [MST_ID_W-1:0]          m_arid_i,
    input   [ADDR_W-1:0]            m_araddr_i,
    input                           m_arvalid_i,
    // -- -- R channel
    input                           m_rready_i,
    // Output declaration
    // -- DVP RX interface
    output                          dvp_xclk_o,
    output                          dvp_pwdn_o,
    // -- AXI4 interface (pixels transfer)
    // -- -- AW channel
    output  [MST_ID_W-1:0]          s_awid_o,
    output  [ADDR_W-1:0]            s_awaddr_o,
    output                          s_awvalid_o,
    // -- -- W channel
    output  [TX_DATA_W-1:0]         s_wdata_o,
    output                          s_wlast_o,
    output                          s_wvalid_o,
    // -- -- B channel
    output                          s_bready_o,
    // -- AXI4 interface (configuration)
    // -- -- AW channel
    output                          m_awready_o,
    // -- -- W channel
    output                          m_wready_o,
    // -- -- B channel
    output  [MST_ID_W-1:0]          m_bid_o,
    output  [TRANS_RESP_W-1:0]      m_bresp_o,
    output                          m_bvalid_o,
    // -- -- AR channel
    output                          m_arready_o,
    // -- -- R channel 
    output  [MST_ID_W-1:0]          m_rid_o,
    output  [DATA_W-1:0]            m_rdata_o,
    output  [TRANS_RESP_W-1:0]      m_rresp_o,
    output                          m_rvalid_o
);
    // Internal signal
    // -- Configuration line
    wire    [DATA_W-1:0]            dvp_cam_conf;
    wire    [ADDR_W-1:0]            pxl_mem_addr;
    wire                            dvp_cam_st;
    wire                            dvp_cam_pwdn;
    wire                            pclk_sync;
    // PF -- DSM
    wire    [PXL_INFO_W-1:0]        pf_dsm_pxl_info;
    wire                            pf_dsm_pxl_vld;
    wire                            dsm_pf_pxl_rdy;
    // DSM -- PGS
    wire    [RGB_PXL_W-1:0]         dsm_pgs_pxl;
    wire                            dsm_pgs_pxl_vld;
    wire                            pgs_dsm_pxl_rdy;
    // PGS -- PDF
    wire    [GS_PXL_W-1:0]          pgs_pdf_gs_pxl;
    wire                            pgs_pdf_vld;
    wire                            pdf_pgs_rdy;
    // PDS -- PAT
    wire    [GS_PXL_W-1:0]          pdf_pat_pxl;
    wire                            pdf_pat_vld;
    wire                            pat_pdf_rdy;
    
    // Configuration register field
    assign dvp_cam_st   = dvp_cam_conf[5'h00];  // Start
    assign dvp_cam_pwdn = dvp_cam_conf[5'h01];  // Power down

    dvp_camera_controller #(
        .INTL_CLK_PERIOD(INTERNAL_CLK),
        .DVP_CAM_CFG_W  (DATA_W)
    ) dcc (
        .clk            (clk),
        .rst_n          (rst_n),
        .dcr_cam_cfg_i  (dvp_cam_conf),
        .dvp_xclk_o     (dvp_xclk_o),
        .dvp_pwdn_o     (dvp_pwdn_o)
    );
    
    dvp_pclk_sync dps (
        .clk            (clk),
        .rst_n          (rst_n),
        .dvp_pclk_i     (dvp_pclk_i),
        .pf_pclk_sync_o (pclk_sync)
    );
    
    dvp_state_machine #(
        .DVP_DATA_W     (DVP_DATA_W),
        .PXL_INFO_W     (PXL_INFO_W),
        .RGB_PXL_W      (RGB_PXL_W),
        .GS_PXL_W       (GS_PXL_W)
    ) dsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .pxl_info_i     (pf_dsm_pxl_info),
        .pxl_info_vld_i (pf_dsm_pxl_vld),
        .dcr_cam_start_i(dvp_cam_st),
        .rgb_pxl_rdy_i  (pgs_dsm_pxl_rdy),
        .pxl_info_rdy_o (dsm_pf_pxl_rdy),
        .rgb_pxl_o      (dsm_pgs_pxl),
        .rgb_pxl_vld_o  (dsm_pgs_pxl_vld)
    );
    
    dvp_config #(
        .BASE_ADDR      (IP_CONF_BASE_ADDR),
        .CONF_OFFSET    (IP_CONF_OFFSET_ADDR),
        .DATA_W         (DATA_W),
        .ADDR_W         (ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .TRANS_DATA_LEN_W(TRANS_DATA_LEN_W),
        .TRANS_DATA_SIZE_W(TRANS_DATA_SIZE_W),
        .TRANS_RESP_W   (TRANS_RESP_W)
    ) dcr (
        .clk            (clk),
        .rst_n          (rst_n),
        .m_awid_i       (m_awid_i),
        .m_awaddr_i     (m_awaddr_i ),
        .m_awvalid_i    (m_awvalid_i),
        .m_wdata_i      (m_wdata_i  ),
        .m_wvalid_i     (m_wvalid_i ),
        .m_bready_i     (m_bready_i ),
        .m_arid_i       (m_arid_i   ),
        .m_araddr_i     (m_araddr_i ),
        .m_arvalid_i    (m_arvalid_i),
        .m_rready_i     (m_rready_i ),
        .m_awready_o    (m_awready_o),
        .m_wready_o     (m_wready_o ),
        .m_bid_o        (m_bid_o    ),
        .m_bresp_o      (m_bresp_o  ),
        .m_bvalid_o     (m_bvalid_o ),
        .m_arready_o    (m_arready_o),
        .m_rid_o        (m_rid_o    ),
        .m_rdata_o      (m_rdata_o  ),
        .m_rresp_o      (m_rresp_o  ),
        .m_rvalid_o     (m_rvalid_o ),
        .dvp_conf_o     (dvp_cam_conf),
        .scaler_conf_o  (),
        .pxl_mem_base_o (pxl_mem_addr)
    );
    
    pixel_fifo #(
        .DVP_DATA_W     (DVP_DATA_W),
        .PXL_INFO_W     (PXL_INFO_W),
        .PXL_FIFO_D     (32)
    ) pf (
        .clk            (clk),
        .rst_n          (rst_n),
        .dcr_cam_start_i(dvp_cam_st),
        .dvp_d_i        (dvp_d_i),
        .dvp_href_i     (dvp_href_i),
        .dvp_vsync_i    (dvp_vsync_i),
        .dvp_hsync_i    (dvp_hsync_i),
        .dps_pclk_sync_i(pclk_sync),
        .dsm_pxl_rdy_i  (dsm_pf_pxl_rdy),
        .dsm_pxl_o      (pf_dsm_pxl_info),
        .dsm_pxl_vld_o  (pf_dsm_pxl_vld)
    );
    
    pixel_gray_scale #(
        .RGB_PXL_W      (RGB_PXL_W),
        .GS_PXL_W       (GS_PXL_W)
    ) pgs (
        .rgb_pxl_i       (dsm_pgs_pxl),   
        .rgb_pxl_vld_i   (dsm_pgs_pxl_vld),
        .gs_pxl_rdy_i    (pdf_pgs_rdy),
        .rgb_pxl_rdy_o   (pgs_dsm_pxl_rdy),
        .gs_pxl_o        (pgs_pdf_gs_pxl),
        .gs_pxl_vld_o    (pgs_pdf_vld)
    );
    
    pixel_downscaler_fifo #(
        .DOWNSCALE_TYPE (DOWNSCALE_TYPE),
        .GS_PXL_W       (GS_PXL_W)
    ) pdf (
        .clk            (clk),
        .rst_n          (rst_n),
        .dsm_pxl_i      (pgs_pdf_gs_pxl),
        .dsm_pxl_vld_i  (pgs_pdf_vld),
        .pat_rdy_i      (pat_pdf_rdy),
        .dsm_pxl_rdy_o  (pdf_pgs_rdy),
        .pat_pxl_o      (pdf_pat_pxl),
        .pat_pxl_vld_o  (pdf_pat_vld)
    );
    
    pixel_axi4_tx #(
        .MST_ID         ({MST_ID_W{1'b0}}),
        .DATA_W         (TX_DATA_W),
        .ADDR_W         (ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .TRANS_DATA_SIZE_W(TRANS_DATA_SIZE_W),
        .TRANS_RESP_W   (TRANS_RESP_W),
        .TX_PER_TXN     ()
    ) pat (
        .clk            (clk),
        .rst_n          (rst_n),
        .pdf_pxl_i      (pdf_pat_pxl),
        .pdf_vld_i      (pdf_pat_vld),
        .dcr_pxl_addr_i (pxl_mem_addr),
        .s_awready_i    (s_awready_i),
        .s_wready_i     (s_wready_i),
        .s_bid_i        (s_bid_i),
        .s_bresp_i      (s_bresp_i),
        .s_bvalid_i     (s_bvalid_i),
        .pdf_rdy_o      (pat_pdf_rdy),
        .s_awid_o       (s_awid_o),
        .s_awaddr_o     (s_awaddr_o),
        .s_awvalid_o    (s_awvalid_o),
        .s_wdata_o      (s_wdata_o),
        .s_wlast_o      (s_wlast_o),
        .s_wvalid_o     (s_wvalid_o),
        .s_bready_o     (s_bready_o)
    );
endmodule

/* 
This IP does not need to use AXI4 (memory mapping) protocol for DMA interface. 
However, in future versions, this ASIC can have multiple virtual channels for 
multiple camera sensors, which means this ASIC should support multiple display interfaces.
Therefore, "Memory Mapping" protocol is the best solution in this case
*/
module dbi_tx_controller 
#(
    parameter INTERNAL_CLK          = 125000000,
    // AXI4 Interface
    // -- DMA
    parameter DMA_DATA_W            = 256,
    parameter ADDR_W                = 32,
    // -- Master Configuration BUS 
    parameter MC_DATA_W             = 8,
    // -- Common
    parameter MST_ID_W              = 5,
    parameter TRANS_DATA_LEN_W      = 8,
    parameter TRANS_DATA_SIZE_W     = 3,
    parameter TRANS_RESP_W          = 2,
    // Memory Mapping
    parameter IP_DATA_BASE_ADDR     = 32'h2000_0000,
    parameter IP_CONF_BASE_ADDR     = 32'h3000_0000,
    parameter IP_CONF_OFFSET_ADDR   = 32'h01,
    // DBI Interface
    parameter DBI_IF_D_W            = 8
    
) (
    // Input declaration
    input                       clk,
    input                       rst_n,
    // -- AXI4 Master DMA
    // -- -- AW channel
    input   [MST_ID_W-1:0]      m_awid_i,
    input   [ADDR_W-1:0]        m_awaddr_i,
    input                       m_awvalid_i,
    // -- -- W channel
    input   [DMA_DATA_W-1:0]    m_wdata_i,
    input                       m_wlast_i,
    input                       m_wvalid_i,
    // -- -- B channel
    input                       m_bready_i,
    // -- AXI4 Master configuration line (master)
    // -- -- AW channel
    input   [MST_ID_W-1:0]      mc_awid_i,
    input   [ADDR_W-1:0]        mc_awaddr_i,
    input                       mc_awvalid_i,
    // -- -- W channel
    input   [MC_DATA_W-1:0]     mc_wdata_i,
    input                       mc_wvalid_i,
    // -- -- B channel
    input                       mc_bready_i,
    // -- -- AR channel
    input   [MST_ID_W-1:0]      mc_arid_i,
    input   [ADDR_W-1:0]        mc_araddr_i,
    input                       mc_arvalid_i,
    // -- -- R channel
    input                       mc_rready_i,
    // Output declaration
    // -- AXI4 DMA (master)
    // -- -- AW channel
    output                      m_awready_o,
    // -- -- W channel
    output                      m_wready_o,
    // -- -- B channel
    output  [MST_ID_W-1:0]      m_bid_o,
    output  [TRANS_RESP_W-1:0]  m_bresp_o,
    output                      m_bvalid_o,
    // -- AXI4 Master configuration line
    // -- -- AW channel
    output                      mc_awready_o,
    // -- -- W channel
    output                      mc_wready_o,
    // -- -- B channel
    output  [MST_ID_W-1:0]      mc_bid_o,
    output  [TRANS_RESP_W-1:0]  mc_bresp_o,
    output                      mc_bvalid_o,
    // -- -- AR channel
    output                      mc_arready_o,
    // -- -- R channel
    output  [MST_ID_W-1:0]      mc_rid_o,
    output  [MC_DATA_W-1:0]     mc_rdata_o,
    output  [TRANS_RESP_W-1:0]  mc_rresp_o,
    output                      mc_rvalid_o,
    // -- DBI TX interface
    output                      dbi_dcx_o,
    output                      dbi_csx_o,
    output                      dbi_resx_o,
    output                      dbi_rdx_o,
    output                      dbi_wrx_o,
    inout   [DBI_IF_D_W-1:0]    dbi_d_o 
);
    wire                        dbi_tx_start;
    wire    [DBI_IF_D_W-1:0]    addr_soft_rst;
    wire    [DBI_IF_D_W-1:0]    addr_disp_on;
    wire    [DBI_IF_D_W-1:0]    addr_col;
    wire    [DBI_IF_D_W-1:0]    addr_row;
    wire    [DBI_IF_D_W-1:0]    addr_acs_ctrl;
    wire    [DBI_IF_D_W-1:0]    addr_mem_wr;
    wire    [DBI_IF_D_W-1:0]    cmd_s_col_h;
    wire    [DBI_IF_D_W-1:0]    cmd_s_col_l;
    wire    [DBI_IF_D_W-1:0]    cmd_e_col_h;
    wire    [DBI_IF_D_W-1:0]    cmd_e_col_l;
    wire    [DBI_IF_D_W-1:0]    cmd_s_row_h;
    wire    [DBI_IF_D_W-1:0]    cmd_s_row_l;
    wire    [DBI_IF_D_W-1:0]    cmd_e_row_h;
    wire    [DBI_IF_D_W-1:0]    cmd_e_row_l;
    wire    [DBI_IF_D_W-1:0]    cmd_acs_ctrl;

    wire                        dtp_d_rdy;
    wire                        dtp_d_vld;
    wire    [DBI_IF_D_W-1:0]    dtp_d_data;

    wire    [DBI_IF_D_W-1:0]    rgb_pxl_dat;
    wire                        rgb_pxl_vld;
    wire                        rgb_pxl_rdy;

    wire                        dtp_dbi_hrst;
    wire    [DBI_IF_D_W-1:0]    dtp_tx_cmd_typ;
    wire    [DBI_IF_D_W-1:0]    dtp_tx_cmd_dat;
    wire                        dtp_tx_last;
    wire                        dtp_tx_no_dat;
    wire                        dtp_tx_vld;
    wire                        dtp_tx_rdy;
    // Internal module
    // -- AXI4 configuration registers file
    axi4_config_reg #(
        .BASE_ADDR          (IP_CONF_BASE_ADDR),
        .CONF_OFFSET        (IP_CONF_OFFSET_ADDR),
        .DATA_W             (MC_DATA_W),
        .ADDR_W             (ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .TRANS_DATA_LEN_W   (TRANS_DATA_LEN_W),
        .TRANS_DATA_SIZE_W  (TRANS_DATA_SIZE_W),
        .TRANS_RESP_W       (TRANS_RESP_W)
    ) acr (
        .clk                (clk),
        .rst_n              (rst_n),
        .m_awid_i           (mc_awid_i),
        .m_awaddr_i         (mc_awaddr_i),
        .m_awvalid_i        (mc_awvalid_i),
        .m_wdata_i          (mc_wdata_i),
        .m_wvalid_i         (mc_wvalid_i),
        .m_bready_i         (mc_bready_i),
        .m_arid_i           (mc_arid_i),
        .m_araddr_i         (mc_araddr_i),
        .m_arvalid_i        (mc_arvalid_i),
        .m_rready_i         (mc_rready_i),
        .m_awready_o        (mc_awready_o),
        .m_wready_o         (mc_wready_o),
        .m_bid_o            (mc_bid_o),
        .m_bresp_o          (mc_bresp_o),
        .m_bvalid_o         (mc_bvalid_o),
        .m_arready_o        (mc_arready_o),
        .m_rid_o            (mc_rid_o),
        .m_rdata_o          (mc_rdata_o),
        .m_rresp_o          (mc_rresp_o),
        .m_rvalid_o         (mc_rvalid_o),
        .dbi_tx_start_o     (dbi_tx_start),
        .addr_soft_rst_o    (addr_soft_rst),
        .addr_disp_on_o     (addr_disp_on),
        .addr_col_o         (addr_col),
        .addr_row_o         (addr_row),
        .addr_acs_ctrl_o    (addr_acs_ctrl),
        .addr_mem_wr_o      (addr_mem_wr),
        .cmd_s_col_h_o      (cmd_s_col_h),
        .cmd_s_col_l_o      (cmd_s_col_l),
        .cmd_e_col_h_o      (cmd_e_col_h),
        .cmd_e_col_l_o      (cmd_e_col_l),
        .cmd_s_row_h_o      (cmd_s_row_h),
        .cmd_s_row_l_o      (cmd_s_row_l),
        .cmd_e_row_h_o      (cmd_e_row_h),
        .cmd_e_row_l_o      (cmd_e_row_l),
        .cmd_acs_ctrl_o     (cmd_acs_ctrl)

    );

    axi4_fifo #(
        .BASE_ADDR          (IP_DATA_BASE_ADDR),
        .DATA_W             (DMA_DATA_W),
        .ADDR_W             (ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .TRANS_DATA_LEN_W   (TRANS_DATA_LEN_W),
        .TRANS_DATA_SIZE_W  (TRANS_DATA_SIZE_W),
        .TRANS_RESP_W       (TRANS_RESP_W)
    ) af (
        .clk                (clk),
        .rst_n              (rst_n),
        .m_awid_i           (m_awid_i),
        .m_awaddr_i         (m_awaddr_i),
        .m_awvalid_i        (m_awvalid_i),
        .m_wdata_i          (m_wdata_i),
        .m_wlast_i          (m_wlast_i),
        .m_wvalid_i         (m_wvalid_i),
        .m_bready_i         (m_bready_i),
        .dtp_d_rdy_i        (dtp_d_rdy),
        .m_awready_o        (m_awready_o),
        .m_wready_o         (m_wready_o),
        .m_bid_o            (m_bid_o),
        .m_bresp_o          (m_bresp_o),
        .m_bvalid_o         (m_bvalid_o),
        .dtp_d_data_o       (dtp_d_data),
        .dtp_d_vld_o        (dtp_d_vld)
    );

    gray_to_rgb #(
        .GRAY_PXL_W         (8),
        .RGB_PXL_W          (16),
        .RGB_SPLIT_W        (8)
    ) g2r (
        .clk                (clk),
        .rst_n              (rst_n),
        .gray_pxl_dat_i     (dtp_d_data),
        .gray_pxl_vld_i     (dtp_d_vld),
        .rgb_pxl_rdy_i      (rgb_pxl_rdy),
        .gray_pxl_rdy_o     (dtp_d_rdy),
        .rgb_pxl_dat_o      (rgb_pxl_dat),
        .rgb_pxl_vld_o      (rgb_pxl_vld)
    );

    dbi_tx_fsm #(
        .INTERNAL_CLK       (INTERNAL_CLK)
    ) dtf (
        .clk                (clk),
        .rst_n              (rst_n),
        .dbi_tx_start_i     (dbi_tx_start),
        .addr_soft_rst_i    (addr_soft_rst),
        .addr_disp_on_i     (addr_disp_on),
        .addr_col_i         (addr_col),
        .addr_row_i         (addr_row),
        .addr_acs_ctrl_i    (addr_acs_ctrl),
        .addr_mem_wr_i      (addr_mem_wr),
        .cmd_s_col_h_i      (cmd_s_col_h),
        .cmd_s_col_l_i      (cmd_s_col_l),
        .cmd_e_col_h_i      (cmd_e_col_h),
        .cmd_e_col_l_i      (cmd_e_col_l),
        .cmd_s_row_h_i      (cmd_s_row_h),
        .cmd_s_row_l_i      (cmd_s_row_l),
        .cmd_e_row_h_i      (cmd_e_row_h),
        .cmd_e_row_l_i      (cmd_e_row_l),
        .cmd_acs_ctrl_i     (cmd_acs_ctrl),
        .pxl_d_i            (rgb_pxl_dat),
        .pxl_vld_i          (rgb_pxl_vld),
        .dtp_tx_rdy_i       (dtp_tx_rdy),
        .pxl_rdy_o          (rgb_pxl_rdy),
        .dtp_dbi_hrst_o     (dtp_dbi_hrst),
        .dtp_tx_cmd_typ_o   (dtp_tx_cmd_typ),
        .dtp_tx_cmd_dat_o   (dtp_tx_cmd_dat),
        .dtp_tx_last_o      (dtp_tx_last),
        .dtp_tx_no_dat_o    (dtp_tx_no_dat),
        .dtp_tx_vld_o       (dtp_tx_vld)
    );

    dbi_tx_phy #(
        .INTERNAL_CLK       (INTERNAL_CLK)
    ) dtp (
        .clk                (clk),
        .rst_n              (rst_n),
        .dtf_dbi_hrst_i     (dtp_dbi_hrst),
        .dtf_tx_cmd_typ_i   (dtp_tx_cmd_typ),
        .dtf_tx_cmd_dat_i   (dtp_tx_cmd_dat),
        .dtf_tx_no_dat_i    (dtp_tx_no_dat),
        .dtf_tx_last_i      (dtp_tx_last),
        .dtf_tx_vld_i       (dtp_tx_vld),
        .dtf_tx_rdy_o       (dtp_tx_rdy),
        .dbi_d_o            (dbi_d_o),
        .dbi_csx_o          (dbi_csx_o),
        .dbi_dcx_o          (dbi_dcx_o),
        .dbi_resx_o         (dbi_resx_o),
        .dbi_rdx_o          (dbi_rdx_o),
        .dbi_wrx_o          (dbi_wrx_o)
    );


endmodule
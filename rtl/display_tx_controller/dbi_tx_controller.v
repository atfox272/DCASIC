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
    parameter IP_STM_BASE_ADDR      = 32'h2000_0000,
    parameter IP_CONF_REG_BASE_ADDR = 32'h3000_0000,
    parameter IP_CONF_TX_BASE_ADDR  = 32'h3100_0000,
    parameter IP_CONF_OFFSET_ADDR   = 32'h01,
    // DBI Interface
    parameter DBI_IF_D_W            = 8
    
) (
    // Input declaration
    input                           clk,
    input                           rst_n,
    // -- AXI4 Master DMA
    // -- -- AW channel
    input   [MST_ID_W-1:0]          m_awid_i,
    input   [ADDR_W-1:0]            m_awaddr_i,
    input                           m_awvalid_i,
    // -- -- W channel
    input   [DMA_DATA_W-1:0]        m_wdata_i,
    input                           m_wlast_i,
    input                           m_wvalid_i,
    // -- -- B channel
    input                           m_bready_i,
    // -- AXI4 Master configuration line (master)
    // -- -- AW channel
    input   [MST_ID_W-1:0]          mc_awid_i,
    input   [ADDR_W-1:0]            mc_awaddr_i,
    input   [1:0]                   mc_awburst_i,        
    input   [TRANS_DATA_LEN_W-1:0]  mc_awlen_i,
    input                           mc_awvalid_i,
    // -- -- W channel
    input   [MC_DATA_W-1:0]         mc_wdata_i,
    input                           mc_wlast_i,
    input                           mc_wvalid_i,
    // -- -- B channel
    input                           mc_bready_i,
    // -- -- AR channel
    input   [MST_ID_W-1:0]          mc_arid_i,
    input   [ADDR_W-1:0]            mc_araddr_i,
    input   [1:0]                   mc_arburst_i,
    input   [TRANS_DATA_LEN_W-1:0]  mc_arlen_i,
    input                           mc_arvalid_i,
    // -- -- R channel
    input                           mc_rready_i,
    // Output declaration
    // -- AXI4 DMA (master)
    // -- -- AW channel
    output                          m_awready_o,
    // -- -- W channel
    output                          m_wready_o,
    // -- -- B channel
    output  [MST_ID_W-1:0]          m_bid_o,
    output  [TRANS_RESP_W-1:0]      m_bresp_o,
    output                          m_bvalid_o,
    // -- AXI4 Master configuration line
    // -- -- AW channel
    output                          mc_awready_o,
    // -- -- W channel
    output                          mc_wready_o,
    // -- -- B channel
    output  [MST_ID_W-1:0]          mc_bid_o,
    output  [TRANS_RESP_W-1:0]      mc_bresp_o,
    output                          mc_bvalid_o,
    // -- -- AR channel
    output                          mc_arready_o,
    // -- -- R channel
    output  [MST_ID_W-1:0]          mc_rid_o,
    output  [MC_DATA_W-1:0]         mc_rdata_o,
    output  [TRANS_RESP_W-1:0]      mc_rresp_o,
    output                          mc_rlast_o,
    output                          mc_rvalid_o,
    // -- DBI TX interface
    output                          dbi_dcx_o,
    output                          dbi_csx_o,
    output                          dbi_resx_o,
    output                          dbi_rdx_o,
    output                          dbi_wrx_o,
    inout   [DBI_IF_D_W-1:0]        dbi_d_o 
);
    // Local parameters 
    localparam DBI_CONF_REG     = 1 + 1;        // DBI_CTRL_ST + DBI_MEM_COM
    localparam DBI_TX_FIFO_NUM  = 1 + 1 + 1;    // TX_TYPE + TX_COM + TX_DATA
    
    // Internal varibles
    genvar conf_reg_idx;
    genvar conf_tx_ff_idx;
    // Internal signal
    wire    [1:0]                   dbi_ctrl_mode;
    wire    [DBI_IF_D_W-1:0]        dbi_mem_com;
    wire    [DBI_IF_D_W-1:0]        conf_reg        [0:DBI_CONF_REG-1];
    wire                            tx_type_rw;
    wire                            tx_type_hrst;
    wire    [2:0]                   tx_type_dat_amt;
    wire                            tx_type_vld;
    wire                            tx_type_rdy;
    wire    [DBI_IF_D_W-1:0]        tx_com;
    wire                            tx_com_vld;
    wire                            tx_com_rdy;
    wire    [DBI_IF_D_W-1:0]        tx_data;
    wire                            tx_data_vld;
    wire                            tx_data_rdy;
    wire    [DBI_IF_D_W-1:0]        tx_fifo_dat     [0:DBI_TX_FIFO_NUM-1];
    wire    [DBI_TX_FIFO_NUM-1:0]   tx_fifo_vld;
    wire    [DBI_TX_FIFO_NUM-1:0]   tx_fifo_rdy;

    wire    [MC_DATA_W*DBI_TX_FIFO_NUM-1:0] tx_fifo_flat;
    wire    [MC_DATA_W*DBI_CONF_REG-1:0]    conf_reg_flat;

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
   
    // Memory mapping
    // -- BASE: 0x3000_0000 - OFFSET: 0-1
    assign dbi_ctrl_mode        = conf_reg   [8'd00][1:0];
    assign dbi_mem_com          = conf_reg   [8'd01];
    // -- BASE: 0x3100_0000 - OFFSET: 0
    assign tx_type_rw           = tx_fifo_dat[8'd00][0];
    assign tx_type_hrst         = tx_fifo_dat[8'd00][1];
    assign tx_type_dat_amt      = tx_fifo_dat[8'd00][4:2];
    assign tx_type_vld          = tx_fifo_vld[8'd00];
    assign tx_fifo_rdy[8'd00]   = tx_type_rdy;
    // -- BASE: 0x3100_0000 - OFFSET: 1
    assign tx_com               = tx_fifo_dat[8'd01];
    assign tx_com_vld           = tx_fifo_vld[8'd01];
    assign tx_fifo_rdy[8'd01]   = tx_com_rdy;
    // -- BASE: 0x3100_0000 - OFFSET: 2
    assign tx_data              = tx_fifo_dat[8'd02];
    assign tx_data_vld          = tx_fifo_vld[8'd02];
    assign tx_fifo_rdy[8'd02]   = tx_data_rdy;

    // De-flatten
generate
    for(conf_reg_idx = 0; conf_reg_idx < DBI_CONF_REG; conf_reg_idx = conf_reg_idx + 1) begin : DEFLAT_0
        assign conf_reg[conf_reg_idx] = conf_reg_flat[(conf_reg_idx+1)*MC_DATA_W-1-:MC_DATA_W];
    end
    for(conf_tx_ff_idx = 0; conf_tx_ff_idx < DBI_TX_FIFO_NUM; conf_tx_ff_idx = conf_tx_ff_idx + 1) begin : DEFLAT_1
        assign tx_fifo_dat[conf_tx_ff_idx] = tx_fifo_flat[(conf_tx_ff_idx+1)*MC_DATA_W-1-:MC_DATA_W];
    end
endgenerate
    // Module instances
    axi4_ctrl #(
        .AXI4_CTRL_CONF     (1),    // CONF_REG:    On
        .AXI4_CTRL_STAT     (0),    // STATUS_REG:  Off
        .AXI4_CTRL_MEM      (0),    // MEM:         Off
        .AXI4_CTRL_WR_ST    (1),    // TX_FIFO:     On
        .AXI4_CTRL_RD_ST    (0),    // RX_FIFO:     Off
        .CONF_BASE_ADDR     (IP_CONF_REG_BASE_ADDR),
        .CONF_OFFSET        (IP_CONF_OFFSET_ADDR),
        .CONF_REG_NUM       (DBI_CONF_REG),
        .ST_WR_BASE_ADDR    (IP_CONF_TX_BASE_ADDR),
        .ST_WR_OFFSET       (IP_CONF_OFFSET_ADDR),
        .ST_WR_FIFO_NUM     (DBI_TX_FIFO_NUM),
        .ST_WR_FIFO_DEPTH   (16),
        .ST_RD_BASE_ADDR    (),
        .ST_RD_OFFSET       (),
        .ST_RD_FIFO_NUM     (),
        .ST_RD_FIFO_DEPTH   (),

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
        .m_awburst_i        (mc_awburst_i),
        .m_awlen_i          (mc_awlen_i),
        .m_awvalid_i        (mc_awvalid_i),
        .m_wdata_i          (mc_wdata_i),
        .m_wlast_i          (mc_wlast_i),
        .m_wvalid_i         (mc_wvalid_i),
        .m_bready_i         (mc_bready_i),
        .m_arid_i           (mc_arid_i),
        .m_araddr_i         (mc_araddr_i),
        .m_arburst_i        (mc_arburst_i),
        .m_arlen_i          (mc_arlen_i),
        .m_arvalid_i        (mc_arvalid_i),
        .m_rready_i         (mc_rready_i),
        .stat_reg_i         (),
        .mem_wr_rdy_i       (),
        .mem_rd_data_i      (),
        .mem_rd_rdy_i       (),
        .wr_st_rd_vld_i     (tx_fifo_rdy),
        .rd_st_wr_data_i    (),
        .rd_st_wr_vld_i     (),
        .m_awready_o        (mc_awready_o),
        .m_wready_o         (mc_wready_o),
        .m_bid_o            (mc_bid_o),
        .m_bresp_o          (mc_bresp_o),
        .m_bvalid_o         (mc_bvalid_o),
        .m_arready_o        (mc_arready_o),
        .m_rid_o            (mc_rid_o),
        .m_rdata_o          (mc_rdata_o),
        .m_rresp_o          (mc_rresp_o),
        .m_rlast_o          (mc_rlast_o),
        .m_rvalid_o         (mc_rvalid_o),
        .conf_reg_o         (conf_reg_flat),
        .mem_wr_data_o      (),
        .mem_wr_addr_o      (), 
        .mem_wr_vld_o       (),
        .mem_rd_addr_o      (),
        .mem_rd_vld_o       (),
        .wr_st_rd_data_o    (tx_fifo_flat),
        .wr_st_rd_rdy_o     (tx_fifo_vld),
        .rd_st_wr_rdy_o     ()
    );

    axi4_fifo #(
        .BASE_ADDR          (IP_STM_BASE_ADDR),
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
        .INTERNAL_CLK       (INTERNAL_CLK),
        .DBI_IF_D_W         (DBI_IF_D_W)
    ) dtf (
        .clk                (clk),
        .rst_n              (rst_n),
        .dbi_ctrl_mode_i    (dbi_ctrl_mode),
        .dbi_mem_com_i      (dbi_mem_com),
        .tx_type_rw_i       (tx_type_rw),
        .tx_type_hrst_i     (tx_type_hrst),
        .tx_type_dat_amt_i  (tx_type_dat_amt),
        .tx_type_vld_i      (tx_type_vld),
        .tx_com_i           (tx_com),
        .tx_com_vld_i       (tx_com_vld),
        .tx_data_i          (tx_data),
        .tx_data_vld_i      (tx_data_vld),
        .pxl_d_i            (rgb_pxl_dat),
        .pxl_vld_i          (rgb_pxl_vld),
        .dtp_tx_rdy_i       (dtp_tx_rdy),
        .tx_type_rdy_o      (tx_type_rdy),
        .tx_com_rdy_o       (tx_com_rdy),
        .tx_data_rdy_o      (tx_data_rdy),
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
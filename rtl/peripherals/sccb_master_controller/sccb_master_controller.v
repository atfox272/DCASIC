module sccb_master_controller #(
    // Memory Mapping
    parameter IP_CONF_BASE_ADDR     = 32'h2000_0000,    // Configuration registers region - BASE
    parameter IP_TX_BASE_ADDR       = 32'h2100_0000,    // SCCB TX FIFO region - BASE
    parameter IP_RX_BASE_ADDR       = 32'h2200_0000,    // SCCB RX FIFO region - BASE
    // FIFO
    parameter SCCB_TX_FIFO_DEPTH    = 8,                // SCCB TX FIFO depth (element's width = 8bit)
    parameter SCCB_RX_FIFO_DEPTH    = 8,                // SCCB RX FIFO depth (element's width = 8bit)
    // AXI4 Bus Configuration
    parameter DATA_W                = 8,
    parameter ADDR_W                = 32,
    parameter MST_ID_W              = 5,
    parameter TRANS_DATA_LEN_W      = 8,
    parameter TRANS_DATA_SIZE_W     = 3,
    parameter TRANS_RESP_W          = 2,
    // Timing configuration 
    parameter INTERNAL_CLK_FREQ     = 125_000_000,
    parameter MAX_SCCB_FREQ         = 100_000
) (
    // Input declaration
    // -- Global 
    input                           clk,
    input                           rst_n,
    // -- AXI4 Interface            
    // -- -- AW channel         
    input   [MST_ID_W-1:0]          m_awid_i,
    input   [ADDR_W-1:0]            m_awaddr_i,
    input   [TRANS_DATA_LEN_W-1:0]  m_awlen_i,
    input                           m_awvalid_i,
    // -- -- W channel          
    input   [DATA_W-1:0]            m_wdata_i,
    input                           m_wlast_i,
    input                           m_wvalid_i,
    // -- -- B channel          
    input                           m_bready_i,
    // -- -- AR channel         
    input   [MST_ID_W-1:0]          m_arid_i,
    input   [ADDR_W-1:0]            m_araddr_i,
    input   [TRANS_DATA_LEN_W-1:0]  m_arlen_i,
    input                           m_arvalid_i,
    // -- -- R channel          
    input                           m_rready_i,
    // Output declaration           
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
    output                          m_rlast_o,
    output                          m_rvalid_o,
    // -- SCCB Master Interface
    output                          sio_c,
    inout                           sio_d
);
    // Local parameters declaration
    localparam CONFIG_REG_NUM   = 2; // SLV_DVC_ADDR + PRESCALER 
    localparam SCCB_TX_FIFO_NUM = 3; // CONTROL_SIGNAL + SUB_ADDR + TX_DATA
    localparam SCCB_RX_FIFO_NUM = 1; // RX_DATA

    // Internal variable
    genvar tx_fifo_idx;
    genvar conf_reg_idx;
    // Internal signal
    // -- wire
    wire [DATA_W-2:0]           slv_dvc_addr;
    wire [DATA_W-1:0]           prescaler;
    wire [1:0]                  phase_amt;
    wire                        trans_type;
    wire                        ctrl_vld;
    wire                        ctrl_rdy;
    wire [DATA_W-1:0]           tx_data;
    wire                        tx_data_vld;
    wire                        tx_data_rdy;
    wire [DATA_W-1:0]           tx_sub_adr;
    wire                        tx_sub_adr_vld;
    wire                        tx_sub_adr_rdy;
    wire [DATA_W-1:0]           rx_data;
    wire                        rx_vld;
    wire                        rx_rdy;
    wire                        cntr_en;
    wire                        tick_en;
    wire                        sio_c_tgl_en;
    wire [DATA_W*CONFIG_REG_NUM-1:0] conf_reg_flat;
    wire [DATA_W-1:0]           conf_reg        [0:CONFIG_REG_NUM-1];
    wire [DATA_W*SCCB_TX_FIFO_NUM-1:0] tx_fifo_flat;
    wire [DATA_W-1:0]           tx_fifo_dat     [0:SCCB_TX_FIFO_NUM-1];
    wire [SCCB_TX_FIFO_NUM-1:0] tx_fifo_vld;
    wire [SCCB_TX_FIFO_NUM-1:0] tx_fifo_rdy;

    // MEMORY MAPPING
    // -- BASE: 0x2000_0000 - OFFSET: 0-1
    assign slv_dvc_addr         = conf_reg   [8'd00];
    assign prescaler            = conf_reg   [8'd01];
    // -- BASE: 0x2100_0000 - OFFSET: 0
    assign phase_amt            = tx_fifo_dat[8'd00][1:0];
    assign trans_type           = tx_fifo_dat[8'd00][2];
    assign ctrl_vld             = tx_fifo_vld[8'd00];
    assign tx_fifo_rdy[8'd00]   = ctrl_rdy;
    // -- BASE: 0x2100_0000 - OFFSET: 1
    assign tx_sub_adr           = tx_fifo_dat[8'd01];
    assign tx_sub_adr_vld       = tx_fifo_vld[8'd01];
    assign tx_fifo_rdy[8'd01]   = tx_sub_adr_rdy;
    // -- BASE: 0x2100_0000 - OFFSET: 2
    assign tx_data              = tx_fifo_dat[8'd02];
    assign tx_data_vld          = tx_fifo_vld[8'd02];
    assign tx_fifo_rdy[8'd02]   = tx_data_rdy;

    // De-flattern
generate
    for(tx_fifo_idx = 0; tx_fifo_idx < SCCB_TX_FIFO_NUM; tx_fifo_idx = tx_fifo_idx + 1) begin : TX_LOGIC_GEN
        assign tx_fifo_dat[tx_fifo_idx] = tx_fifo_flat[(tx_fifo_idx+1)*DATA_W-1-:DATA_W];
    end
    for(conf_reg_idx = 0; conf_reg_idx < CONFIG_REG_NUM; conf_reg_idx = conf_reg_idx + 1) begin : CONF_LOGIC_GEN
        assign conf_reg[conf_reg_idx] = conf_reg_flat[(conf_reg_idx+1)*DATA_W-1-:DATA_W];
    end
endgenerate

    // Module instances
    axi4_ctrl #(
        .AXI4_CTRL_CONF     (1),    // CONF_REG: On
        .AXI4_CTRL_WR_ST    (1),    // TX_FIFO: On
        .AXI4_CTRL_RD_ST    (1),    // RX_FIFO: On
        .CONF_BASE_ADDR     (IP_CONF_BASE_ADDR),
        .CONF_OFFSET        (32'h01),
        .CONF_REG_NUM       (CONFIG_REG_NUM),
        .ST_WR_BASE_ADDR    (IP_TX_BASE_ADDR),
        .ST_WR_OFFSET       (32'h01),
        .ST_WR_FIFO_NUM     (SCCB_TX_FIFO_NUM),
        .ST_WR_FIFO_DEPTH   (SCCB_TX_FIFO_DEPTH),
        .ST_RD_BASE_ADDR    (IP_RX_BASE_ADDR),
        .ST_RD_OFFSET       (32'h01),
        .ST_RD_FIFO_NUM     (SCCB_RX_FIFO_NUM),
        .ST_RD_FIFO_DEPTH   (SCCB_RX_FIFO_DEPTH),

        .DATA_W             (DATA_W),
        .ADDR_W             (ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .TRANS_DATA_LEN_W   (TRANS_DATA_LEN_W),
        .TRANS_DATA_SIZE_W  (TRANS_DATA_SIZE_W),
        .TRANS_RESP_W       (TRANS_RESP_W)
    ) axi4_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),
        .m_awid_i           (m_awid_i),
        .m_awaddr_i         (m_awaddr_i),
        .m_awlen_i          (m_awlen_i),
        .m_awvalid_i        (m_awvalid_i),
        .m_wdata_i          (m_wdata_i),
        .m_wlast_i          (m_wlast_i),
        .m_wvalid_i         (m_wvalid_i),
        .m_bready_i         (m_bready_i),
        .m_arid_i           (m_arid_i),
        .m_araddr_i         (m_araddr_i),
        .m_arlen_i          (m_arlen_i),
        .m_arvalid_i        (m_arvalid_i),
        .m_rready_i         (m_rready_i),
        .mem_wr_rdy_i       (),
        .mem_rd_data_i      (),
        .mem_rd_rdy_i       (),
        .wr_st_rd_vld_i     (tx_fifo_rdy),
        .rd_st_wr_data_i    (rx_data),
        .rd_st_wr_vld_i     (rx_vld),
        .m_awready_o        (m_awready_o),
        .m_wready_o         (m_wready_o),
        .m_bid_o            (m_bid_o),
        .m_bresp_o          (m_bresp_o),
        .m_bvalid_o         (m_bvalid_o),
        .m_arready_o        (m_arready_o),
        .m_rid_o            (m_rid_o),
        .m_rdata_o          (m_rdata_o),
        .m_rresp_o          (m_rresp_o),
        .m_rlast_o          (m_rlast_o),
        .m_rvalid_o         (m_rvalid_o),
        .conf_reg_o         (conf_reg_flat),
        .mem_wr_data_o      (),
        .mem_wr_addr_o      (), 
        .mem_wr_vld_o       (),
        .mem_rd_addr_o      (),
        .mem_rd_vld_o       (),
        .wr_st_rd_data_o    (tx_fifo_flat),
        .wr_st_rd_rdy_o     (tx_fifo_vld),
        .rd_st_wr_rdy_o     (rx_rdy)
    );

    sccb_timing_gen #(
        .INTERNAL_CLK_FREQ  (INTERNAL_CLK_FREQ),
        .MAX_SCCB_FREQ      (MAX_SCCB_FREQ)
    ) sccb_timing_gen (
        .clk                (clk),
        .rst_n              (rst_n),
        .cntr_en_i          (cntr_en),
        .prescaler_i        (prescaler),
        .tick_en_o          (tick_en),
        .sio_c_tgl_en_o     (sio_c_tgl_en)
    );

    sccb_fsm #(
        .DATA_W             (DATA_W)
    ) sccb_fsm (
        .clk                (clk),
        .rst_n              (rst_n),
        .slv_dvc_addr_i     (slv_dvc_addr),
        .trans_type_i       (trans_type),
        .phase_amt_i        (phase_amt),
        .ctrl_vld_i         (ctrl_vld),
        .tx_data_i          (tx_data),
        .tx_data_vld_i      (tx_data_vld),
        .tx_sub_adr_i       (tx_sub_adr),
        .tx_sub_adr_vld_i   (tx_sub_adr_vld),
        .rx_rdy_i           (rx_rdy),
        .tick_en_i          (tick_en),
        .sio_c_tgl_en_i     (sio_c_tgl_en),
        .ctrl_rdy_o         (ctrl_rdy),
        .tx_data_rdy_o      (tx_data_rdy),
        .tx_sub_adr_rdy_o   (tx_sub_adr_rdy),
        .rx_data_o          (rx_data),
        .rx_vld_o           (rx_vld),
        .cntr_en_o          (cntr_en),
        .sio_c              (sio_c),
        .sio_d              (sio_d)
    );
endmodule
`define IMAGE_STREAM_SUBSYS
`define SILICON_DEBUG
module dcasic 
#(
    parameter INTERNAL_CLK      = 50_000_000,
    // DVP Interface
    parameter DVP_DATA_W        = 8,
    // DBI Interface
    parameter DBI_IF_D_W        = 8,
    // Instruction Memory
    parameter IMEM_W            = 8,    // 256 instructions
    parameter BOOTLOADER_FILE   = "L:/Projects/dcasic/bootloader/program_0.hex" // Bootloader file of the system
) (
    input                       sys_clk,
    output                      sys_trap_o,
    input                       rst_n,
    // Camera RX Interface
    input   [DVP_DATA_W-1:0]    dvp_d_i,
    input                       dvp_href_i,
    input                       dvp_vsync_i,
    // input                       dvp_hsync_i,
    input                       dvp_pclk_i,
    output                      dvp_xclk_o,
    output                      dvp_pwdn_o,
    // Display TX Interface
    output                      dbi_dcx_o,
    output                      dbi_csx_o,
    output                      dbi_resx_o,
    output                      dbi_rdx_o,
    output                      dbi_wrx_o,
    inout   [DBI_IF_D_W-1:0]    dbi_d_o,
    // Camera Controller Interface
    output                      sio_c,
    inout                       sio_d

`ifdef SILICON_DEBUG
    ,output                     debug_0
`endif

);
    // Local parameters
    //  Configuration BUS
    localparam CONF_MST_AMT             = 1;    // 1 master - processor
    localparam CONF_SLV_AMT             = 8;    // 8 slaves: IMEM + DSP + CAM + SCCB + DMA + UART
    localparam CONF_DATA_W              = 32;
    localparam CONF_ADDR_W              = 32;
    localparam CONF_MST_ID_W            = 1;    // 1 masters
    localparam CONF_SLV_ID_W            = CONF_MST_ID_W + $clog2(CONF_SLV_AMT);    // 8 slaves
    localparam CONF_TX_BURST_W          = 2;    // Width of xBURST 
    localparam CONF_TX_DAT_LEN_W        = 8;
    localparam CONF_TX_DAT_SZ_W         = 3;
    localparam CONF_TX_RESP_W           = 2;
    localparam CONF_OUST_AMT            = 2;    // Number of outstanding transacitons in the BUS
    localparam CONF_MST_WEIGHT          = 32'd1;// The weight of processor in the BUS

    // -- Instruction Memory
    localparam IMEM_ID_ADDR             = 3'h00;
    localparam IMEM_BASE_ADDR           = {IMEM_ID_ADDR, 29'h0000_0000};        // Base address: 0x0000_0000
    // -- Display TX configuration Memory
    localparam DSP_CONF_ID_ADDR         = 3'h01;
    localparam DSP_CONF_REG_BASE_ADDR   = {DSP_CONF_ID_ADDR, 29'h0000_0000};    // Base address: 0x2000_0000
    localparam DSP_CONF_TX_BASE_ADDR    = {DSP_CONF_ID_ADDR, 29'h0800_0000};    // Base address: 0x2800_0000
    localparam DSP_CONF_OFS             = 32'h01;                               // Offset: Byte
    // -- Camera RX configuration Memory
    localparam CAM_CONF_ID_ADDR         = 3'h02;
    localparam CAM_CONF_BASE_ADDR       = {CAM_CONF_ID_ADDR, 29'h0000_0000};    // Base address: 0x4000_0000
    localparam CAM_CONF_OFS             = 32'h04;                               // Offset: Word
    // -- SCCB Master configuration Memory
    localparam SCCB_ID_ADDR             = 3'h03;
    localparam SCCB_CONF_BASE_ADDR      = {SCCB_ID_ADDR, 29'h0000_0000};        // Base address: 0x6000_0000
    localparam SCCB_TX_BASE_ADDR        = {SCCB_ID_ADDR, 29'h0800_0000};        // Base address: 0x6800_0000
    localparam SCCB_RX_BASE_ADDR        = {SCCB_ID_ADDR, 29'h1800_0000};        // Base address: 0x7800_0000
    
    // Video BUS
    localparam VBUS_ID_W                = CONF_SLV_ID_W;
    localparam VBUS_DATA_W              = 256;
    localparam VBUS_ADDR_W              = 32;
    localparam VBUS_RESP_W              = 2;
    localparam DSP_TX_BASE_ADDR         = 32'h2000_0000;

    // Internal signal
    // -- Processor
    wire    [CONF_ADDR_W-1:0]                       proc_awaddr;
    wire    [CONF_ADDR_W:0]                         proc_araddr;
    // -- Interconnect
    wire    [CONF_MST_ID_W*CONF_MST_AMT-1:0]        icm_awid_flat;
    wire    [CONF_ADDR_W*CONF_MST_AMT-1:0]          icm_awaddr_flat;
    wire    [CONF_TX_BURST_W*CONF_MST_AMT-1:0]      icm_awburst_flat;
    wire    [CONF_TX_DAT_LEN_W*CONF_MST_AMT-1:0]    icm_awlen_flat;
    wire    [CONF_TX_DAT_SZ_W*CONF_MST_AMT-1:0]     icm_awsize_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_awvalid_flat;
    wire    [CONF_DATA_W*CONF_MST_AMT-1:0]          icm_wdata_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_wlast_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_wvalid_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_bready_flat;
    wire    [CONF_MST_ID_W*CONF_MST_AMT-1:0]        icm_arid_flat;
    wire    [CONF_ADDR_W*CONF_MST_AMT-1:0]          icm_araddr_flat;
    wire    [CONF_TX_BURST_W*CONF_MST_AMT-1:0]      icm_arburst_flat;
    wire    [CONF_TX_DAT_LEN_W*CONF_MST_AMT-1:0]    icm_arlen_flat;
    wire    [CONF_TX_DAT_SZ_W*CONF_MST_AMT-1:0]     icm_arsize_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_arvalid_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_rready_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_awready_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_wready_flat;
    wire    [CONF_SLV_ID_W*CONF_SLV_AMT-1:0]        ics_bid_flat;
    wire    [CONF_TX_RESP_W*CONF_SLV_AMT-1:0]       ics_bresp_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_bvalid_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_arready_flat;
    wire    [CONF_SLV_ID_W*CONF_SLV_AMT-1:0]        ics_rid_flat;
    wire    [CONF_DATA_W*CONF_SLV_AMT-1:0]          ics_rdata_flat;
    wire    [CONF_TX_RESP_W*CONF_SLV_AMT-1:0]       ics_rresp_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_rlast_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_rvalid_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_awready_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_wready_flat;
    wire    [CONF_MST_ID_W*CONF_MST_AMT-1:0]        icm_bid_flat;
    wire    [CONF_TX_RESP_W*CONF_MST_AMT-1:0]       icm_bresp_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_bvalid_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_arready_flat;
    wire    [CONF_MST_ID_W*CONF_MST_AMT-1:0]        icm_rid_flat;
    wire    [CONF_DATA_W*CONF_MST_AMT-1:0]          icm_rdata_flat;
    wire    [CONF_TX_RESP_W*CONF_MST_AMT-1:0]       icm_rresp_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_rlast_flat;
    wire    [CONF_MST_AMT-1:0]                      icm_rvalid_flat;
    wire    [CONF_SLV_ID_W*CONF_SLV_AMT-1:0]        ics_awid_flat;
    wire    [CONF_ADDR_W*CONF_SLV_AMT-1:0]          ics_awaddr_flat;
    wire    [CONF_TX_BURST_W*CONF_SLV_AMT-1:0]      ics_awburst_flat;
    wire    [CONF_TX_DAT_LEN_W*CONF_SLV_AMT-1:0]    ics_awlen_flat;
    wire    [CONF_TX_DAT_SZ_W*CONF_SLV_AMT-1:0]     ics_awsize_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_awvalid_flat;
    wire    [CONF_DATA_W*CONF_SLV_AMT-1:0]          ics_wdata_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_wlast_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_wvalid_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_bready_flat;
    wire    [CONF_SLV_ID_W*CONF_SLV_AMT-1:0]        ics_arid_flat;
    wire    [CONF_ADDR_W*CONF_SLV_AMT-1:0]          ics_araddr_flat;
    wire    [CONF_TX_BURST_W*CONF_SLV_AMT-1:0]      ics_arburst_flat;
    wire    [CONF_TX_DAT_LEN_W*CONF_SLV_AMT-1:0]    ics_arlen_flat;
    wire    [CONF_TX_DAT_SZ_W*CONF_SLV_AMT-1:0]     ics_arsize_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_arvalid_flat;
    wire    [CONF_SLV_AMT-1:0]                      ics_rready_flat;

    wire    [CONF_MST_ID_W-1:0]                     icm_awid         [0:CONF_MST_AMT-1];
    wire    [CONF_ADDR_W-1:0]                       icm_awaddr       [0:CONF_MST_AMT-1];
    wire    [CONF_TX_BURST_W-1:0]                   icm_awburst      [0:CONF_MST_AMT-1];
    wire    [CONF_TX_DAT_LEN_W-1:0]                 icm_awlen        [0:CONF_MST_AMT-1];
    wire    [CONF_TX_DAT_SZ_W-1:0]                  icm_awsize       [0:CONF_MST_AMT-1];
    wire                                            icm_awvalid      [0:CONF_MST_AMT-1];
    wire    [CONF_DATA_W-1:0]                       icm_wdata        [0:CONF_MST_AMT-1];
    wire                                            icm_wlast        [0:CONF_MST_AMT-1];
    wire                                            icm_wvalid       [0:CONF_MST_AMT-1];
    wire                                            icm_bready       [0:CONF_MST_AMT-1];
    wire    [CONF_MST_ID_W-1:0]                     icm_arid         [0:CONF_MST_AMT-1];
    wire    [CONF_ADDR_W-1:0]                       icm_araddr       [0:CONF_MST_AMT-1];
    wire    [CONF_TX_BURST_W-1:0]                   icm_arburst      [0:CONF_MST_AMT-1];
    wire    [CONF_TX_DAT_LEN_W-1:0]                 icm_arlen        [0:CONF_MST_AMT-1];
    wire    [CONF_TX_DAT_SZ_W-1:0]                  icm_arsize       [0:CONF_MST_AMT-1];
    wire                                            icm_arvalid      [0:CONF_MST_AMT-1];
    wire                                            icm_rready       [0:CONF_MST_AMT-1];
    wire                                            icm_awready      [0:CONF_MST_AMT-1];
    wire                                            icm_wready       [0:CONF_MST_AMT-1];
    wire    [CONF_MST_ID_W-1:0]                     icm_bid          [0:CONF_MST_AMT-1];
    wire    [CONF_TX_RESP_W-1:0]                    icm_bresp        [0:CONF_MST_AMT-1];
    wire                                            icm_bvalid       [0:CONF_MST_AMT-1];
    wire                                            icm_arready      [0:CONF_MST_AMT-1];
    wire    [CONF_MST_ID_W-1:0]                     icm_rid          [0:CONF_MST_AMT-1];
    wire    [CONF_DATA_W-1:0]                       icm_rdata        [0:CONF_MST_AMT-1];
    wire    [CONF_TX_RESP_W-1:0]                    icm_rresp        [0:CONF_MST_AMT-1];
    wire                                            icm_rlast        [0:CONF_MST_AMT-1];
    wire                                            icm_rvalid       [0:CONF_MST_AMT-1];
    wire                                            ics_awready      [0:CONF_SLV_AMT-1];
    wire                                            ics_wready       [0:CONF_SLV_AMT-1];
    wire    [CONF_SLV_ID_W-1:0]                     ics_bid          [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_RESP_W-1:0]                    ics_bresp        [0:CONF_SLV_AMT-1];
    wire                                            ics_bvalid       [0:CONF_SLV_AMT-1];
    wire                                            ics_arready      [0:CONF_SLV_AMT-1];
    wire    [CONF_SLV_ID_W-1:0]                     ics_rid          [0:CONF_SLV_AMT-1];
    wire    [CONF_DATA_W-1:0]                       ics_rdata        [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_RESP_W-1:0]                    ics_rresp        [0:CONF_SLV_AMT-1];
    wire                                            ics_rlast        [0:CONF_SLV_AMT-1];
    wire                                            ics_rvalid       [0:CONF_SLV_AMT-1];
    wire    [CONF_SLV_ID_W-1:0]                     ics_awid         [0:CONF_SLV_AMT-1];
    wire    [CONF_ADDR_W-1:0]                       ics_awaddr       [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_BURST_W-1:0]                   ics_awburst      [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_DAT_LEN_W-1:0]                 ics_awlen        [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_DAT_SZ_W-1:0]                  ics_awsize       [0:CONF_SLV_AMT-1];
    wire                                            ics_awvalid      [0:CONF_SLV_AMT-1];
    wire    [CONF_DATA_W-1:0]                       ics_wdata        [0:CONF_SLV_AMT-1];
    wire                                            ics_wlast        [0:CONF_SLV_AMT-1];
    wire                                            ics_wvalid       [0:CONF_SLV_AMT-1];
    wire                                            ics_bready       [0:CONF_SLV_AMT-1];
    wire    [CONF_SLV_ID_W-1:0]                     ics_arid         [0:CONF_SLV_AMT-1];
    wire    [CONF_ADDR_W-1:0]                       ics_araddr       [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_BURST_W-1:0]                   ics_arburst      [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_DAT_LEN_W-1:0]                 ics_arlen        [0:CONF_SLV_AMT-1];
    wire    [CONF_TX_DAT_SZ_W-1:0]                  ics_arsize       [0:CONF_SLV_AMT-1];
    wire                                            ics_arvalid      [0:CONF_SLV_AMT-1];
    wire                                            ics_rready       [0:CONF_SLV_AMT-1];
    // --  RX - TX
    wire    [VBUS_ID_W-1:0]                         dvp_dbi_awid;
    wire    [VBUS_ADDR_W-1:0]                       dvp_dbi_awaddr;
    wire                                            dvp_dbi_awvalid;
    wire                                            dvp_dbi_awready;
    wire    [VBUS_DATA_W-1:0]                       dvp_dbi_wdata;
    wire                                            dvp_dbi_wlast;
    wire                                            dvp_dbi_wvalid;
    wire                                            dvp_dbi_wready;
    wire    [VBUS_ID_W-1:0]                         dvp_dbi_bid;
    wire    [VBUS_RESP_W-1:0]                       dvp_dbi_bresp;
    wire                                            dvp_dbi_bvalid;
    wire                                            dvp_dbi_bready;
    // -- RX
    wire                                            dvp_hsync;

    // IP instantiation
    // -- Processor
    picorv32_axi #(
        .ENABLE_COUNTERS        (0),
        .ENABLE_COUNTERS64      (0),
        .ENABLE_REGS_16_31      (0),
        .ENABLE_REGS_DUALPORT   (0),
        .TWO_STAGE_SHIFT        (0),
        .BARREL_SHIFTER         (0),
        .TWO_CYCLE_COMPARE      (0),
        .TWO_CYCLE_ALU          (0),
        .COMPRESSED_ISA         (0),
        .CATCH_MISALIGN         (0),
        .CATCH_ILLINSN          (0),
        .ENABLE_PCPI            (0),
        .ENABLE_MUL             (0),
        .ENABLE_FAST_MUL        (0),
        .ENABLE_DIV             (0),
        .ENABLE_IRQ             (0),
        .ENABLE_IRQ_QREGS       (0),
        .ENABLE_IRQ_TIMER       (0),
        .ENABLE_TRACE           (0),
        .REGS_INIT_ZERO         (0),
        .MASKED_IRQ             (),
        .LATCHED_IRQ            (),
        .PROGADDR_RESET         (IMEM_BASE_ADDR),
        .PROGADDR_IRQ           (),
        .STACKADDR              ()
    ) proc (
        .clk                    (sys_clk),
        .resetn                 (rst_n),
        .trap                   (sys_trap_o),
        .mem_axi_awvalid        (icm_awvalid[0]),
        .mem_axi_awready        (icm_awready[0]),
        .mem_axi_awaddr         (icm_awaddr[0]),
        .mem_axi_awprot         (),
        .mem_axi_wvalid         (icm_wvalid[0]),
        .mem_axi_wready         (icm_wready[0]),
        .mem_axi_wdata          (icm_wdata[0]),
        .mem_axi_wstrb          (),
        .mem_axi_bvalid         (icm_bvalid[0]),
        .mem_axi_bready         (icm_bready[0]),        
        .mem_axi_arvalid        (icm_arvalid[0]),
        .mem_axi_arready        (icm_arready[0]),
        .mem_axi_araddr         (icm_araddr[0]),
        .mem_axi_arprot         (),
        .mem_axi_rvalid         (icm_rvalid[0]),
        .mem_axi_rready         (icm_rready[0]),
        .mem_axi_rdata          (icm_rdata[0]),
        // N/C
        .pcpi_valid             (),
        .pcpi_insn              (),
        .pcpi_rs1               (),
        .pcpi_rs2               (),
        .pcpi_wr                (),
        .pcpi_rd                (),
        .pcpi_wait              (),
        .pcpi_ready             (),
        .irq                    (),
        .eoi                    (),
        .trace_valid            (),
        .trace_data             ()
    );

    // -- Interconnect
    axi_interconnect #(
        .MST_AMT                (CONF_MST_AMT),
        .SLV_AMT                (CONF_SLV_AMT),
        .OUTSTANDING_AMT        (CONF_OUST_AMT),
        .MST_WEIGHT             (CONF_MST_WEIGHT),
        .MST_ID_W               (CONF_MST_ID_W),
        .SLV_ID_W               (CONF_SLV_ID_W),
        .DATA_WIDTH             (CONF_DATA_W),
        .ADDR_WIDTH             (CONF_ADDR_W),
        .TRANS_MST_ID_W         (CONF_MST_ID_W),
        .TRANS_SLV_ID_W         (CONF_SLV_ID_W),
        .TRANS_BURST_W          (CONF_TX_BURST_W),
        .TRANS_DATA_LEN_W       (CONF_TX_DAT_LEN_W),
        .TRANS_DATA_SIZE_W      (CONF_TX_DAT_SZ_W),
        .TRANS_WR_RESP_W        (CONF_TX_RESP_W),
        .SLV_ID_MSB_IDX         (),
        .SLV_ID_LSB_IDX         (),
        .DSP_RDATA_DEPTH        ()
    ) ic (
        .ACLK_i                 (sys_clk),
        .ARESETn_i              (rst_n),
        .m_AWID_i               (icm_awid_flat),
        .m_AWADDR_i             (icm_awaddr_flat),
        .m_AWBURST_i            (icm_awburst_flat),
        .m_AWLEN_i              (icm_awlen_flat),
        .m_AWSIZE_i             (icm_awsize_flat),
        .m_AWVALID_i            (icm_awvalid_flat),
        .m_WDATA_i              (icm_wdata_flat),
        .m_WLAST_i              (icm_wlast_flat),
        .m_WVALID_i             (icm_wvalid_flat),
        .m_BREADY_i             (icm_bready_flat),
        .m_ARID_i               (icm_arid_flat),
        .m_ARADDR_i             (icm_araddr_flat),
        .m_ARBURST_i            (icm_arburst_flat),
        .m_ARLEN_i              (icm_arlen_flat),
        .m_ARSIZE_i             (icm_arsize_flat),
        .m_ARVALID_i            (icm_arvalid_flat),
        .m_RREADY_i             (icm_rready_flat),
        .s_AWREADY_i            (ics_awready_flat),
        .s_WREADY_i             (ics_wready_flat),
        .s_BID_i                (ics_bid_flat),
        .s_BRESP_i              (ics_bresp_flat),
        .s_BVALID_i             (ics_bvalid_flat),
        .s_ARREADY_i            (ics_arready_flat),
        .s_RID_i                (ics_rid_flat),
        .s_RDATA_i              (ics_rdata_flat),
        .s_RRESP_i              (ics_rresp_flat),
        .s_RLAST_i              (ics_rlast_flat),
        .s_RVALID_i             (ics_rvalid_flat),
        .m_AWREADY_o            (icm_awready_flat),
        .m_WREADY_o             (icm_wready_flat),
        .m_BID_o                (icm_bid_flat),
        .m_BRESP_o              (icm_bresp_flat),
        .m_BVALID_o             (icm_bvalid_flat),
        .m_ARREADY_o            (icm_arready_flat),
        .m_RID_o                (icm_rid_flat),
        .m_RDATA_o              (icm_rdata_flat),
        .m_RRESP_o              (icm_rresp_flat),
        .m_RLAST_o              (icm_rlast_flat),
        .m_RVALID_o             (icm_rvalid_flat),
        .s_AWID_o               (ics_awid_flat),
        .s_AWADDR_o             (ics_awaddr_flat),
        .s_AWBURST_o            (ics_awburst_flat),
        .s_AWLEN_o              (ics_awlen_flat),
        .s_AWSIZE_o             (ics_awsize_flat),
        .s_AWVALID_o            (ics_awvalid_flat),
        .s_WDATA_o              (ics_wdata_flat),
        .s_WLAST_o              (ics_wlast_flat),
        .s_WVALID_o             (ics_wvalid_flat),
        .s_BREADY_o             (ics_bready_flat),
        .s_ARID_o               (ics_arid_flat),
        .s_ARADDR_o             (ics_araddr_flat),
        .s_ARBURST_o            (ics_arburst_flat),
        .s_ARLEN_o              (ics_arlen_flat),
        .s_ARSIZE_o             (ics_arsize_flat),
        .s_ARVALID_o            (ics_arvalid_flat),
        .s_RREADY_o             (ics_rready_flat)
    );

    // -- Intruction Memory
    axi4_mem #(
        .DATA_W                 (CONF_DATA_W),
        .ADDR_W                 (CONF_ADDR_W),
        .MST_ID_W               (CONF_SLV_ID_W),
        .TRANS_DATA_LEN_W       (CONF_TX_DAT_LEN_W),
        .TRANS_DATA_SIZE_W      (CONF_TX_DAT_SZ_W),
        .TRANS_RESP_W           (CONF_TX_RESP_W),
        .MEM_BASE_ADDR          (IMEM_BASE_ADDR),
        .MEM_OFFSET             (4),
        .MEM_DATA_W             (CONF_DATA_W),
        .MEM_ADDR_W             (IMEM_W),       // 32bit x (2^10)
        .MEM_LATENCY            (1),
        .MEM_INIT_FILE          (BOOTLOADER_FILE)
    ) im (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        .m_awaddr_i             (ics_awaddr[IMEM_ID_ADDR]>>2),    // Memory: word-access && Processor: byte-access
        .m_awid_i               (ics_awid[IMEM_ID_ADDR]),
        .m_awlen_i              (ics_awlen[IMEM_ID_ADDR]),
        .m_awvalid_i            (ics_awvalid[IMEM_ID_ADDR]),
        .m_wdata_i              (ics_wdata[IMEM_ID_ADDR]),
        .m_wlast_i              (ics_wlast[IMEM_ID_ADDR]),
        .m_wvalid_i             (ics_wvalid[IMEM_ID_ADDR]),
        .m_bready_i             (ics_bready[IMEM_ID_ADDR]),
        .m_arid_i               (ics_arid[IMEM_ID_ADDR]),
        .m_araddr_i             (ics_araddr[IMEM_ID_ADDR]>>2),    // Memory: word-access && Processor: byte-access
        .m_arlen_i              (ics_arlen[IMEM_ID_ADDR]),
        .m_arvalid_i            (ics_arvalid[IMEM_ID_ADDR]),
        .m_rready_i             (ics_rready[IMEM_ID_ADDR]),
        .m_awready_o            (ics_awready[IMEM_ID_ADDR]),
        .m_wready_o             (ics_wready[IMEM_ID_ADDR]),
        .m_bid_o                (ics_bid[IMEM_ID_ADDR]),
        .m_bresp_o              (ics_bresp[IMEM_ID_ADDR]),
        .m_bvalid_o             (ics_bvalid[IMEM_ID_ADDR]),
        .m_arready_o            (ics_arready[IMEM_ID_ADDR]),
        .m_rid_o                (ics_rid[IMEM_ID_ADDR]),
        .m_rdata_o              (ics_rdata[IMEM_ID_ADDR]),
        .m_rresp_o              (ics_rresp[IMEM_ID_ADDR]),
        .m_rlast_o              (ics_rlast[IMEM_ID_ADDR]),
        .m_rvalid_o             (ics_rvalid[IMEM_ID_ADDR])
    );

    // -- Display TX controller
    dbi_tx_controller #(
        .IP_STM_BASE_ADDR       (DSP_TX_BASE_ADDR),
        .IP_CONF_REG_BASE_ADDR  (DSP_CONF_REG_BASE_ADDR),
        .IP_CONF_TX_BASE_ADDR   (DSP_CONF_TX_BASE_ADDR),
        .IP_CONF_OFFSET_ADDR    (DSP_CONF_OFS),
        .INTERNAL_CLK           (INTERNAL_CLK),
        .DMA_DATA_W             (VBUS_DATA_W),
        .MC_DATA_W              (8),
        .ADDR_W                 (VBUS_ADDR_W),
        .MST_ID_W               (CONF_SLV_ID_W),
        .TRANS_DATA_LEN_W       (CONF_TX_DAT_LEN_W),
        .TRANS_DATA_SIZE_W      (CONF_TX_DAT_SZ_W),
        .TRANS_RESP_W           (CONF_TX_RESP_W)
    ) dtc (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        // -- DBI Interface
        .dbi_dcx_o              (dbi_dcx_o),
        .dbi_csx_o              (dbi_csx_o),
        .dbi_resx_o             (dbi_resx_o),
        .dbi_rdx_o              (dbi_rdx_o),
        .dbi_wrx_o              (dbi_wrx_o),
        .dbi_d_o                (dbi_d_o),
        // -- Master Configuration
        .mc_awid_i              (ics_awid[DSP_CONF_ID_ADDR] ),
        .mc_awaddr_i            (ics_awaddr[DSP_CONF_ID_ADDR]),
        .mc_awlen_i             (ics_awlen[DSP_CONF_ID_ADDR]),
        .mc_awvalid_i           (ics_awvalid[DSP_CONF_ID_ADDR]),
        .mc_wdata_i             (ics_wdata[DSP_CONF_ID_ADDR][7:0]), // Just use 8bit
        .mc_wlast_i             (ics_wlast[DSP_CONF_ID_ADDR]),
        .mc_wvalid_i            (ics_wvalid[DSP_CONF_ID_ADDR]),
        .mc_bready_i            (ics_bready[DSP_CONF_ID_ADDR]),
        .mc_arid_i              (ics_arid[DSP_CONF_ID_ADDR]),
        .mc_araddr_i            (ics_araddr[DSP_CONF_ID_ADDR]),
        .mc_arlen_i             (ics_arlen[DSP_CONF_ID_ADDR]),
        .mc_arvalid_i           (ics_arvalid[DSP_CONF_ID_ADDR]),
        .mc_rready_i            (ics_rready[DSP_CONF_ID_ADDR]),
        .mc_awready_o           (ics_awready[DSP_CONF_ID_ADDR]),
        .mc_wready_o            (ics_wready[DSP_CONF_ID_ADDR]),
        .mc_bid_o               (ics_bid[DSP_CONF_ID_ADDR]),
        .mc_bresp_o             (ics_bresp[DSP_CONF_ID_ADDR]),
        .mc_bvalid_o            (ics_bvalid[DSP_CONF_ID_ADDR]),
        .mc_arready_o           (ics_arready[DSP_CONF_ID_ADDR]),
        .mc_rid_o               (ics_rid[DSP_CONF_ID_ADDR]),
        .mc_rdata_o             (ics_rdata[DSP_CONF_ID_ADDR][7:0]), // Just use 8bit
        .mc_rlast_o             (ics_rlast[DSP_CONF_ID_ADDR]),
        .mc_rresp_o             (ics_rresp[DSP_CONF_ID_ADDR]),
        .mc_rvalid_o            (ics_rvalid[DSP_CONF_ID_ADDR]),
`ifdef IMAGE_STREAM_SUBSYS
        // -- Maxter Pixel Streaming
        .m_awid_i               (dvp_dbi_awid),
        .m_awaddr_i             (dvp_dbi_awaddr),
        .m_awvalid_i            (dvp_dbi_awvalid),
        .m_wdata_i              (dvp_dbi_wdata),
        .m_wlast_i              (dvp_dbi_wlast),
        .m_wvalid_i             (dvp_dbi_wvalid),
        .m_bready_i             (dvp_dbi_bready),
        .m_awready_o            (dvp_dbi_awready),
        .m_wready_o             (dvp_dbi_wready),
        .m_bid_o                (dvp_dbi_bid),
        .m_bresp_o              (dvp_dbi_bresp),
        .m_bvalid_o             (dvp_dbi_bvalid)
        // .m_awid_i               (0),
        // .m_awaddr_i             (DSP_TX_BASE_ADDR),
        // .m_awvalid_i            (1'b1),
        // .m_wdata_i              ({{(VBUS_DATA_W*3/4){1'b1}}, {(VBUS_DATA_W*1/4){1'b0}}}),
        // .m_wlast_i              (1'b0),
        // .m_wvalid_i             (1'b1),
        // .m_bready_i             (1'b1),
        // .m_awready_o            (dvp_dbi_awready),
        // .m_wready_o             (dvp_dbi_wready),
        // .m_bid_o                (dvp_dbi_bid),
        // .m_bresp_o              (dvp_dbi_bresp),
        // .m_bvalid_o             (dvp_dbi_bvalid)
`endif
    );

    // -- Camera RX Controller
    dvp_rx_controller #(
        .IP_CONF_BASE_ADDR      (CAM_CONF_BASE_ADDR),
        .IP_CONF_OFFSET_ADDR    (CAM_CONF_OFS),
        .DATA_W                 (CONF_DATA_W),
        .ADDR_W                 (CONF_ADDR_W),
        .MST_ID_W               (CONF_SLV_ID_W),
        .TRANS_DATA_LEN_W       (CONF_TX_DAT_LEN_W),
        .TRANS_DATA_SIZE_W      (CONF_TX_DAT_SZ_W),
        .TRANS_RESP_W           (CONF_TX_RESP_W),
        .TX_DATA_W              (VBUS_DATA_W),
        .INTERNAL_CLK           (INTERNAL_CLK),
        .DOWNSCALE_TYPE         (1) // Max Pooling 
    ) crc (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        // -- DVP Interface
        .dvp_d_i                (dvp_d_i),
        .dvp_href_i             (dvp_href_i),
        .dvp_vsync_i            (dvp_vsync_i),
        .dvp_hsync_i            (dvp_hsync),
        .dvp_pclk_i             (dvp_pclk_i),
        .dvp_xclk_o             (dvp_xclk_o),
        .dvp_pwdn_o             (dvp_pwdn_o),
        // -- Master Configuration
        .m_awid_i               (ics_awid[CAM_CONF_ID_ADDR]),
        .m_awaddr_i             (ics_awaddr[CAM_CONF_ID_ADDR]),
        .m_awvalid_i            (ics_awvalid[CAM_CONF_ID_ADDR]),
        .m_wdata_i              (ics_wdata[CAM_CONF_ID_ADDR]),
        .m_wvalid_i             (ics_wvalid[CAM_CONF_ID_ADDR]),
        .m_bready_i             (ics_bready[CAM_CONF_ID_ADDR]),
        .m_arid_i               (ics_arid[CAM_CONF_ID_ADDR]),
        .m_araddr_i             (ics_araddr[CAM_CONF_ID_ADDR]),
        .m_arvalid_i            (ics_arvalid[CAM_CONF_ID_ADDR]),
        .m_rready_i             (ics_rready[CAM_CONF_ID_ADDR]),
        .m_awready_o            (ics_awready[CAM_CONF_ID_ADDR]),
        .m_wready_o             (ics_wready[CAM_CONF_ID_ADDR]),
        .m_bid_o                (ics_bid[CAM_CONF_ID_ADDR]),
        .m_bresp_o              (ics_bresp[CAM_CONF_ID_ADDR]),
        .m_bvalid_o             (ics_bvalid[CAM_CONF_ID_ADDR]),
        .m_arready_o            (ics_arready[CAM_CONF_ID_ADDR]),
        .m_rid_o                (ics_rid[CAM_CONF_ID_ADDR]),
        .m_rdata_o              (ics_rdata[CAM_CONF_ID_ADDR]),
        .m_rresp_o              (ics_rresp[CAM_CONF_ID_ADDR]),
        .m_rvalid_o             (ics_rvalid[CAM_CONF_ID_ADDR]),
`ifdef IMAGE_STREAM_SUBSYS
        // -- Slave Pixel Buffer
        .s_awid_o               (dvp_dbi_awid),
        .s_awaddr_o             (dvp_dbi_awaddr),
        .s_awvalid_o            (dvp_dbi_awvalid),
        .s_wdata_o              (dvp_dbi_wdata),
        .s_wlast_o              (dvp_dbi_wlast),
        .s_wvalid_o             (dvp_dbi_wvalid),
        .s_bready_o             (dvp_dbi_bready),
        .s_awready_i            (dvp_dbi_awready),
        .s_wready_i             (dvp_dbi_wready),
        .s_bid_i                (dvp_dbi_bid),
        .s_bresp_i              (dvp_dbi_bresp),
        .s_bvalid_i             (dvp_dbi_bvalid)
`endif
    );

    // -- Camera Controller
    sccb_master_controller #(
        .IP_CONF_BASE_ADDR      (SCCB_CONF_BASE_ADDR),
        .IP_TX_BASE_ADDR        (SCCB_TX_BASE_ADDR),
        .IP_RX_BASE_ADDR        (SCCB_RX_BASE_ADDR),
        .SCCB_TX_FIFO_DEPTH     (4),
        .SCCB_RX_FIFO_DEPTH     (4),
        .DATA_W                 (8),
        .ADDR_W                 (CONF_ADDR_W),
        .MST_ID_W               (CONF_SLV_ID_W),
        .TRANS_DATA_LEN_W       (CONF_TX_DAT_LEN_W),
        .TRANS_DATA_SIZE_W      (CONF_TX_DAT_SZ_W),
        .TRANS_RESP_W           (CONF_TX_RESP_W),
        .INTERNAL_CLK_FREQ      (INTERNAL_CLK),
        .MAX_SCCB_FREQ          ()
    ) cc (
        .clk                    (sys_clk),
        .rst_n                  (rst_n),
        .m_awid_i               (ics_awid[SCCB_ID_ADDR]),
        .m_awaddr_i             (ics_awaddr[SCCB_ID_ADDR]),
        .m_awlen_i              (ics_awlen[SCCB_ID_ADDR]),
        .m_awvalid_i            (ics_awvalid[SCCB_ID_ADDR]),
        .m_wdata_i              (ics_wdata[SCCB_ID_ADDR][7:0]),
        .m_wlast_i              (ics_wlast[SCCB_ID_ADDR]),
        .m_wvalid_i             (ics_wvalid[SCCB_ID_ADDR]),
        .m_bready_i             (ics_bready[SCCB_ID_ADDR]),
        .m_arid_i               (ics_arid[SCCB_ID_ADDR]),
        .m_araddr_i             (ics_araddr[SCCB_ID_ADDR]),
        .m_arlen_i              (ics_arlen[SCCB_ID_ADDR]),
        .m_arvalid_i            (ics_arvalid[SCCB_ID_ADDR]),
        .m_rready_i             (ics_rready[SCCB_ID_ADDR]),
        .m_awready_o            (ics_awready[SCCB_ID_ADDR]),
        .m_wready_o             (ics_wready[SCCB_ID_ADDR]),
        .m_bid_o                (ics_bid[SCCB_ID_ADDR]),
        .m_bresp_o              (ics_bresp[SCCB_ID_ADDR]),
        .m_bvalid_o             (ics_bvalid[SCCB_ID_ADDR]),
        .m_arready_o            (ics_arready[SCCB_ID_ADDR]),
        .m_rid_o                (ics_rid[SCCB_ID_ADDR]),
        .m_rdata_o              (ics_rdata[SCCB_ID_ADDR][7:0]),
        .m_rresp_o              (ics_rresp[SCCB_ID_ADDR]),
        .m_rlast_o              (ics_rlast[SCCB_ID_ADDR]),
        .m_rvalid_o             (ics_rvalid[SCCB_ID_ADDR]),
        .sio_c                  (sio_c),
        .sio_d                  (sio_d)
    );

    // Connection
    genvar mst_idx;
    genvar slv_idx;
    assign icm_awid[0]  = {CONF_MST_ID_W{1'b0}};
    assign icm_arid[0]  = {CONF_MST_ID_W{1'b0}};
    assign icm_awlen[0] = {CONF_TX_DAT_LEN_W{1'b0}};
    assign icm_arlen[0] = {CONF_TX_DAT_LEN_W{1'b0}};
    assign icm_wlast[0] = 1'b1;
    assign dvp_hsync    = dvp_href_i;   // HREF and HSYNC share same pin
    generate
        for(mst_idx = 0; mst_idx < CONF_MST_AMT; mst_idx = mst_idx + 1) begin   : AXI4_MST
            assign icm_awid_flat[CONF_MST_ID_W*(mst_idx+1)-1-:CONF_MST_ID_W]            = icm_awid[mst_idx];
            assign icm_awaddr_flat[CONF_ADDR_W*(mst_idx+1)-1-:CONF_ADDR_W]              = icm_awaddr[mst_idx];
            assign icm_awburst_flat[CONF_TX_BURST_W*(mst_idx+1)-1-:CONF_TX_BURST_W]     = icm_awburst[mst_idx];
            assign icm_awlen_flat[CONF_TX_DAT_LEN_W*(mst_idx+1)-1-:CONF_TX_DAT_LEN_W]   = icm_awlen[mst_idx];
            assign icm_awsize_flat[CONF_TX_DAT_SZ_W*(mst_idx+1)-1-:CONF_TX_DAT_SZ_W]    = icm_awsize[mst_idx];
            assign icm_awvalid_flat[mst_idx]                                            = icm_awvalid[mst_idx];
            assign icm_wdata_flat[CONF_DATA_W*(mst_idx+1)-1-:CONF_DATA_W]               = icm_wdata[mst_idx];
            assign icm_wlast_flat[mst_idx]                                              = icm_wlast[mst_idx];
            assign icm_wvalid_flat[mst_idx]                                             = icm_wvalid[mst_idx];
            assign icm_bready_flat[mst_idx]                                             = icm_bready[mst_idx];
            assign icm_arid_flat[CONF_MST_ID_W*(mst_idx+1)-1-:CONF_MST_ID_W]            = icm_arid[mst_idx];
            assign icm_araddr_flat[CONF_ADDR_W*(mst_idx+1)-1-:CONF_ADDR_W]              = icm_araddr[mst_idx];
            assign icm_arburst_flat[CONF_TX_BURST_W*(mst_idx+1)-1-:CONF_TX_BURST_W]     = icm_arburst[mst_idx];
            assign icm_arlen_flat[CONF_TX_DAT_LEN_W*(mst_idx+1)-1-:CONF_TX_DAT_LEN_W]   = icm_arlen[mst_idx];
            assign icm_arsize_flat[CONF_TX_DAT_SZ_W*(mst_idx+1)-1-:CONF_TX_DAT_SZ_W]    = icm_arsize[mst_idx];
            assign icm_arvalid_flat[mst_idx]                                            = icm_arvalid[mst_idx];
            assign icm_rready_flat[mst_idx]                                             = icm_rready[mst_idx];
            assign icm_awready[mst_idx]                                                 = icm_awready_flat[mst_idx];
            assign icm_wready[mst_idx]                                                  = icm_wready_flat[mst_idx];
            assign icm_bid[mst_idx]                                                     = icm_bid_flat[CONF_MST_ID_W*(mst_idx+1)-1-:CONF_MST_ID_W];   
            assign icm_bresp[mst_idx]                                                   = icm_bresp_flat[CONF_TX_RESP_W*(mst_idx+1)-1-:CONF_TX_RESP_W]; 
            assign icm_bvalid[mst_idx]                                                  = icm_bvalid_flat[mst_idx];
            assign icm_arready[mst_idx]                                                 = icm_arready_flat[mst_idx];
            assign icm_rid[mst_idx]                                                     = icm_rid_flat[CONF_MST_ID_W*(mst_idx+1)-1-:CONF_MST_ID_W];   
            assign icm_rdata[mst_idx]                                                   = icm_rdata_flat[CONF_DATA_W*(mst_idx+1)-1-:CONF_DATA_W]; 
            assign icm_rresp[mst_idx]                                                   = icm_rresp_flat[CONF_TX_RESP_W*(mst_idx+1)-1-:CONF_TX_RESP_W]; 
            assign icm_rlast[mst_idx]                                                   = icm_rlast_flat[mst_idx]; 
            assign icm_rvalid[mst_idx]                                                  = icm_rvalid_flat[mst_idx];
        end
        for(slv_idx = 0; slv_idx < CONF_SLV_AMT; slv_idx = slv_idx + 1) begin   : AXI4_SLV
            assign ics_awready_flat[slv_idx]                                            = ics_awready[slv_idx];
            assign ics_wready_flat[slv_idx]                                             = ics_wready[slv_idx];
            assign ics_bid_flat[CONF_SLV_ID_W*(slv_idx+1)-1-:CONF_SLV_ID_W]             = ics_bid[slv_idx];
            assign ics_bresp_flat[CONF_TX_RESP_W*(slv_idx+1)-1-:CONF_TX_RESP_W]         = ics_bresp[slv_idx];
            assign ics_bvalid_flat[slv_idx]                                             = ics_bvalid[slv_idx];
            assign ics_arready_flat[slv_idx]                                            = ics_arready[slv_idx];
            assign ics_rid_flat[CONF_SLV_ID_W*(slv_idx+1)-1-:CONF_SLV_ID_W]             = ics_rid[slv_idx];
            assign ics_rdata_flat[CONF_DATA_W*(slv_idx+1)-1-:CONF_DATA_W]               = ics_rdata[slv_idx];
            assign ics_rresp_flat[CONF_TX_RESP_W*(slv_idx+1)-1-:CONF_TX_RESP_W]         = ics_rresp[slv_idx];
            assign ics_rlast_flat[slv_idx]                                              = ics_rlast[slv_idx];
            assign ics_rvalid_flat[slv_idx]                                             = ics_rvalid[slv_idx];
            assign ics_awid[slv_idx]                                                    = ics_awid_flat[CONF_SLV_ID_W*(slv_idx+1)-1-:CONF_SLV_ID_W];
            assign ics_awaddr[slv_idx]                                                  = ics_awaddr_flat[CONF_ADDR_W*(slv_idx+1)-1-:CONF_ADDR_W];
            assign ics_awburst[slv_idx]                                                 = ics_awburst_flat[CONF_TX_BURST_W*(slv_idx+1)-1-:CONF_TX_BURST_W];
            assign ics_awlen[slv_idx]                                                   = ics_awlen_flat[CONF_TX_DAT_LEN_W*(slv_idx+1)-1-:CONF_TX_DAT_LEN_W];
            assign ics_awsize[slv_idx]                                                  = ics_awsize_flat[CONF_TX_DAT_SZ_W*(slv_idx+1)-1-:CONF_TX_DAT_SZ_W];
            assign ics_awvalid[slv_idx]                                                 = ics_awvalid_flat[slv_idx];
            assign ics_wdata[slv_idx]                                                   = ics_wdata_flat[CONF_DATA_W*(slv_idx+1)-1-:CONF_DATA_W];
            assign ics_wlast[slv_idx]                                                   = ics_wlast_flat[slv_idx];
            assign ics_wvalid[slv_idx]                                                  = ics_wvalid_flat[slv_idx];
            assign ics_bready[slv_idx]                                                  = ics_bready_flat[slv_idx];
            assign ics_arid[slv_idx]                                                    = ics_arid_flat[CONF_SLV_ID_W*(slv_idx+1)-1-:CONF_SLV_ID_W];
            assign ics_araddr[slv_idx]                                                  = ics_araddr_flat[CONF_ADDR_W*(slv_idx+1)-1-:CONF_ADDR_W];
            assign ics_arburst[slv_idx]                                                 = ics_arburst_flat[CONF_TX_BURST_W*(slv_idx+1)-1-:CONF_TX_BURST_W];
            assign ics_arlen[slv_idx]                                                   = ics_arlen_flat[CONF_TX_DAT_LEN_W*(slv_idx+1)-1-:CONF_TX_DAT_LEN_W];
            assign ics_arsize[slv_idx]                                                  = ics_arsize_flat[CONF_TX_DAT_SZ_W*(slv_idx+1)-1-:CONF_TX_DAT_SZ_W];
            assign ics_arvalid[slv_idx]                                                 = ics_arvalid_flat[slv_idx];
            assign ics_rready[slv_idx]                                                  = ics_rready_flat[slv_idx];
        end
    endgenerate
`ifdef SILICON_DEBUG
    assign debug_0 = |ics_araddr[IMEM_ID_ADDR]; // (!= 0)
`endif
endmodule
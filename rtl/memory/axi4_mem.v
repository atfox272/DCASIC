module axi4_mem
#(
    // AXI4 BUS 
    parameter DATA_W            = 8,
    parameter ADDR_W            = 32,
    parameter MST_ID_W          = 5,
    parameter TRANS_DATA_LEN_W  = 8,
    parameter TRANS_DATA_SIZE_W = 3,
    parameter TRANS_RESP_W      = 2,
    // Memory
    parameter MEM_BASE_ADDR     = 32'h2300_0000,    // Address mapping - BASE
    parameter MEM_OFFSET        = (DATA_W/8),       // Address mapping - OFFSET ---> Address (byte-access) = (base + offset*n)
    parameter MEM_DATA_W        = DATA_W,           // Memory's data width
    parameter MEM_ADDR_W        = 10,               // Memory's address width
    parameter MEM_LATENCY       = 1,                // Memory latency
    parameter MEM_INIT_FILE     = ""                // Initial value in Memory
) (
    // Input declaration
    // -- Global 
    input                           clk,
    input                           rst_n,

    // -- to AXI4 Master            
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
    output                          m_rvalid_o
);
    // Internal signal
    wire                    mem_wr_rdy;
    wire [MEM_DATA_W-1:0]   mem_rd_data;
    wire                    mem_rd_rdy;
    wire [MEM_DATA_W-1:0]   mem_wr_data;
    wire [MEM_ADDR_W-1:0]   mem_wr_addr;
    wire                    mem_wr_vld;
    wire [MEM_ADDR_W-1:0]   mem_rd_addr;
    wire                    mem_rd_vld;

    // Module instantiation
    axi4_ctrl #(
        .AXI4_CTRL_CONF     (0),
        .AXI4_CTRL_MEM      (1),
        .AXI4_CTRL_WR_ST    (0),
        .AXI4_CTRL_RD_ST    (0),
        .MEM_BASE_ADDR      (MEM_BASE_ADDR),
        .MEM_OFFSET         (MEM_OFFSET),
        .MEM_DATA_W         (MEM_DATA_W),
        .MEM_ADDR_W         (MEM_ADDR_W),
        .MEM_LATENCY        (MEM_LATENCY),
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
        .mem_wr_rdy_i       (mem_wr_rdy),
        .mem_rd_data_i      (mem_rd_data),
        .mem_rd_rdy_i       (mem_rd_rdy),
        .wr_st_rd_vld_i     (),
        .rd_st_wr_data_i    (),
        .rd_st_wr_vld_i     (),
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
        .conf_reg_o         (),
        .mem_wr_data_o      (mem_wr_data),
        .mem_wr_addr_o      (mem_wr_addr),
        .mem_wr_vld_o       (mem_wr_vld),
        .mem_rd_addr_o      (mem_rd_addr),
        .mem_rd_vld_o       (mem_rd_vld),
        .wr_st_rd_data_o    (),
        .wr_st_rd_rdy_o     (),
        .rd_st_wr_rdy_o     ()
    );

    memory #(
        .DATA_W             (MEM_DATA_W),
        .ADDR_W             (MEM_ADDR_W),
        .MEM_FILE           (MEM_INIT_FILE)
    ) mem (
        .clk                (clk),
        .rst_n              (rst_n),
        .wr_data_i          (mem_wr_data),
        .wr_addr_i          (mem_wr_addr),
        .wr_vld_i           (mem_wr_vld),
        .rd_addr_i          (mem_rd_addr),
        .rd_vld_i           (mem_rd_vld),
        .wr_rdy_o           (mem_wr_rdy),
        .rd_data_o          (mem_rd_data),
        .rd_rdy_o           (mem_rd_rdy)
    );
endmodule
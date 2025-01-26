module pixel_axi4_tx
#(
    // AXI4 Interface
    parameter MST_ID            = 5'h02,
    parameter DATA_W            = 256,
    parameter ADDR_W            = 32,
    parameter MST_ID_W          = 5,
    parameter TRANS_DATA_SIZE_W = 3,
    parameter TRANS_RESP_W      = 2,
    parameter TX_PER_TXN        = 2400, // number of transfers per transaction
    // Pixel configuration
    parameter GS_PXL_W          = 8
)
(
    // Input declaration
    // -- Global
    input                           clk,
    input                           rst_n,
    // -- To pixel downscaler FIFO 
    input   [GS_PXL_W-1:0]          pdf_pxl_i,
    input                           pdf_vld_i,
    // -- To DVP configuration register
    input   [ADDR_W-1:0]            dcr_pxl_addr_i,
    // -- To AXI4 Slave
    // -- -- AW channel
    input                           s_awready_i,
    // -- -- W channel
    input                           s_wready_i,
    // -- -- B channel (Do not use this channel --> Future update: Checking response transfer)
    input   [MST_ID_W-1:0]          s_bid_i,
    input   [TRANS_RESP_W-1:0]      s_bresp_i,
    input                           s_bvalid_i,
    // Output declaration
    // -- To pixel downscaler FIFO 
    output                          pdf_rdy_o,
    // -- To AXI4 Slave
    // -- -- AW channel
    output  [MST_ID_W-1:0]          s_awid_o,
    output  [ADDR_W-1:0]            s_awaddr_o,
    output                          s_awvalid_o,
    // -- -- W channel
    output  [DATA_W-1:0]            s_wdata_o,
    output                          s_wlast_o,
    output                          s_wvalid_o,
    // --- -- B channel
    output                          s_bready_o
);
    // Local parameters
    localparam W_ADPTR_CNT  = DATA_W/GS_PXL_W;
    localparam W_ADPTR_W    = $clog2(W_ADPTR_CNT);
    localparam TX_CNT_W     = $clog2(TX_PER_TXN);
    localparam IDLE_ST      = 2'd0;
    localparam AXI4_TX_ST   = 2'd1;
    // Internal variable
    genvar pxl_idx;
    // Internal signal
    // -- wire
    wire                        pdf_hsk;
    wire                        s_aw_hsk;
    wire                        s_w_hsk;
    reg [1:0]                   pat_st_d;
    reg [TX_CNT_W-1:0]          tx_cnt_d;
    // -- reg
    reg [1:0]                   pat_st;
    reg [TX_CNT_W-1:0]          tx_cnt;
    
    // Internal module
    sync_fifo 
    #(
        .FIFO_TYPE      (3),        // Concat FIFO
        .DATA_WIDTH     (DATA_W),
        .IN_DATA_WIDTH  (GS_PXL_W)
    ) concat_fifo (
        .clk            (clk),
        .data_i         (pdf_pxl_i),
        .data_o         (s_wdata_o),
        .wr_valid_i     (pdf_vld_i),
        .wr_ready_o     (pdf_rdy_o),
        .rd_valid_i     (s_wready_i),
        .rd_ready_o     (s_wvalid_o),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    
    // Combination logic
    assign s_awid_o     = MST_ID;
    assign s_awaddr_o   = dcr_pxl_addr_i;
    
    reg                         s_aw_rd_ptr;
    reg                         s_aw_wr_ptr;
    assign s_awvalid_o  = s_aw_rd_ptr ^ s_aw_wr_ptr;
    assign s_wlast_o    = ~|(tx_cnt^(TX_PER_TXN-1));
    assign s_bready_o   = 1'b1;
    assign s_aw_hsk     = s_awvalid_o & s_awready_i;
    assign s_w_hsk      = s_wvalid_o & s_wready_i;
    always @(*) begin
        pat_st_d        = pat_st;
        tx_cnt_d        = tx_cnt;
        case(pat_st)
            IDLE_ST: begin
                pat_st_d = pdf_vld_i ? AXI4_TX_ST : pat_st;
            end
            AXI4_TX_ST: begin
                tx_cnt_d = s_w_hsk ? (~|(tx_cnt^(TX_PER_TXN-1)) ? {TX_CNT_W{1'b0}} : (tx_cnt + 1'b1)) : tx_cnt;
                // W chn handshake --Yes--> Transfer counter max --Yes--> IDLE
                //                                               --No---> CONCAT state
                pat_st_d = (s_w_hsk & (~|tx_cnt_d)) ? IDLE_ST : pat_st;
            end
        endcase
    end
    
    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pat_st <= 2'd0;
        end
        else begin
            pat_st <= pat_st_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            tx_cnt <= {TX_CNT_W{1'b0}};
        end
        else begin
            tx_cnt <= tx_cnt_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            s_aw_wr_ptr <= 1'b0;
        end
        else if(~|(pat_st^IDLE_ST) & pdf_vld_i) begin
            s_aw_wr_ptr <= ~s_aw_wr_ptr;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            s_aw_rd_ptr <= 1'b0;
        end
        else if(s_aw_hsk) begin
            s_aw_rd_ptr <= ~s_aw_rd_ptr;
        end
    end
endmodule

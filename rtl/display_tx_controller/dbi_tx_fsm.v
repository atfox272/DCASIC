module dbi_tx_fsm 
#(
    parameter INTERNAL_CLK      = 125000000,
    // DBI Interface
    parameter DBI_IF_D_W        = 8
) 
(
    // Input declaration
    input                       clk,
    input                       rst_n,
    // -- To AXI4 Configuration Register
    input   [1:0]               dbi_ctrl_mode_i,
    input   [DBI_IF_D_W-1:0]    dbi_mem_com_i,
    input                       tx_type_rw_i,
    input                       tx_type_hrst_i,
    input   [2:0]               tx_type_dat_amt_i,
    input                       tx_type_vld_i,
    input   [DBI_IF_D_W-1:0]    tx_com_i,
    input                       tx_com_vld_i,
    input   [DBI_IF_D_W-1:0]    tx_data_i,
    input                       tx_data_vld_i,
    // -- To AXI4 FIFO
    input   [DBI_IF_D_W-1:0]    pxl_d_i,
    input                       pxl_vld_i,
    // -- To DBI TX PHY
    input                       dtp_tx_rdy_i,
    // Output declaration
    // -- To AXI4 Configuration Register
    output                      tx_type_rdy_o,
    output                      tx_com_rdy_o,
    output                      tx_data_rdy_o,
    // -- To AXI4 FIFO
    output                      pxl_rdy_o,
    // -- To DBI TX PHY
    output                      dtp_dbi_hrst_o,
    output  [DBI_IF_D_W-1:0]    dtp_tx_cmd_typ_o,
    output  [DBI_IF_D_W-1:0]    dtp_tx_cmd_dat_o,
    output                      dtp_tx_last_o,
    output                      dtp_tx_no_dat_o,
    output                      dtp_tx_vld_o
);
    // Local parameters
    localparam IDLE_ST          = 2'd0;
    localparam DBI_RST_STALL_ST = 2'd1;
    localparam DBI_CONF_TX      = 2'd2;
    localparam DBI_STREAM_TX    = 2'd3;

    localparam IDLE_MODE        = 2'h0;
    localparam CONF_MODE        = 2'h1;
    localparam STREAM_MODE      = 2'h2;
    // localparam DBI_SET_COL_ST   = 4'd3;
    // localparam DBI_SET_ROW_ST   = 4'd4;
    // localparam DBI_MEM_ACS_CTRL = 4'd5;
    // localparam DBI_DISP_ST      = 4'd6;
    // localparam DBI_SLEEP_OUT    = 4'd7;
    // localparam DBI_SLEEP_WAIT   = 4'd8;
    // localparam DBI_STM_ST       = 4'd9;

    localparam NOP_CMD          = 8'h00;
    localparam RST_STALL_SEC    = 120e-3;
    localparam SLP_STALL_SEC    = 6e-3;
    localparam integer SCALE_FACTOR     = 1000; // Use to convert RST_STALL_SEC to a integer
    localparam integer RST_STALL_SEC_INT= RST_STALL_SEC * SCALE_FACTOR; // Convert RST_STALL_SEC_INT to a integer
    localparam integer SLP_STALL_SEC_INT= SLP_STALL_SEC * SCALE_FACTOR; // Convert SLP_STALL_SEC to a integer
    localparam integer RST_STALL_CYC    = (RST_STALL_SEC_INT * INTERNAL_CLK) / SCALE_FACTOR;    // Return integer
    localparam integer SLP_STALL_CYC    = (SLP_STALL_SEC_INT * INTERNAL_CLK) / SCALE_FACTOR;    // Return integer
    localparam integer RST_STALL_W      = $clog2(RST_STALL_CYC);

    localparam DBI_TX_PER_TXN   = 153600;
    localparam DBI_TX_CNT_W     = $clog2(DBI_TX_PER_TXN);

    // Internal signal
    // -- wire
    reg     [1:0]               dbi_tx_st_d;
    reg     [RST_STALL_W-1:0]   rst_stall_cnt_d;
    reg                         dtp_dbi_hrst;
    reg     [DBI_IF_D_W-1:0]    dtp_tx_cmd_typ;
    reg     [DBI_IF_D_W-1:0]    dtp_tx_cmd_dat;
    reg                         dtp_tx_last;
    reg                         dtp_tx_vld;
    reg     [DBI_TX_CNT_W-1:0]  dbi_tx_cnt_d;
    reg                         dtp_tx_no_dat;
    reg                         rgb_pxl_rdy;
    reg                         tx_type_rdy;
    reg                         tx_com_rdy;
    reg                         tx_data_rdy;
    // -- reg
    reg     [1:0]               dbi_tx_st_q;
    reg     [RST_STALL_W-1:0]   rst_stall_cnt_q;
    reg     [DBI_TX_CNT_W-1:0]  dbi_tx_cnt_q;

    // Combination logic
    assign tx_type_rdy_o    = tx_type_rdy;
    assign tx_com_rdy_o     = tx_com_rdy;
    assign tx_data_rdy_o    = tx_data_rdy;
    assign dtp_dbi_hrst_o   = dtp_dbi_hrst;
    assign dtp_tx_cmd_typ_o = dtp_tx_cmd_typ;
    assign dtp_tx_cmd_dat_o = dtp_tx_cmd_dat;
    assign dtp_tx_last_o    = dtp_tx_last;
    assign dtp_tx_no_dat_o  = dtp_tx_no_dat;
    assign dtp_tx_vld_o     = dtp_tx_vld;
    assign pxl_rdy_o        = rgb_pxl_rdy;
      
    always @(*) begin
        dbi_tx_st_d         = dbi_tx_st_q;
        rst_stall_cnt_d     = (RST_STALL_CYC - 1'b1);   // Set up for Reset state
        dbi_tx_cnt_d        = dbi_tx_cnt_q;
        dtp_tx_cmd_typ      = tx_com_i;
        dtp_tx_cmd_dat      = tx_data_i;
        tx_type_rdy         = 1'b0;
        tx_com_rdy          = 1'b0;
        tx_data_rdy         = 1'b0;
        rgb_pxl_rdy         = 1'b0;
        dtp_dbi_hrst        = 1'b0;
        dtp_tx_last         = 1'b0;
        dtp_tx_no_dat       = 1'b0;
        dtp_tx_vld          = 1'b0;
        case(dbi_tx_st_q) 
            IDLE_ST: begin
                if(~|(dbi_ctrl_mode_i ^ CONF_MODE) && tx_type_vld_i) begin      // The controller is in CONFIG mode and The transaction is ready 
                    dbi_tx_st_d = DBI_CONF_TX;
                    dbi_tx_cnt_d = tx_type_dat_amt_i - 1'b1;
                end
                else if (~|(dbi_ctrl_mode_i ^ STREAM_MODE) && pxl_vld_i) begin  // The controller is in STREAM mode and The pixels is ready 
                    dbi_tx_st_d = DBI_STREAM_TX;
                    dbi_tx_cnt_d = DBI_TX_PER_TXN - 1'b1;
                end
            end
            DBI_RST_STALL_ST: begin
                rst_stall_cnt_d     = rst_stall_cnt_q - 1'b1;
                if(~|rst_stall_cnt_q) begin
                    dbi_tx_st_d     = IDLE_ST;
                end
            end
            DBI_CONF_TX: begin
                // Behav
                dtp_tx_vld = tx_type_vld_i & (tx_type_hrst_i | (tx_com_vld_i & (~(|tx_type_dat_amt_i) | tx_data_vld_i))); // "(~(|tx_type_dat_amt_i) | tx_data_vld_i)": If the TX has data field, then the FIFO_DATA must be valid  
                // // If type_hrst is valid    -> tx_type_vld_i must be valid
                // // else                     -> tx_type_vld_i & tx_com_vld_i & tx_data_vld_i must be valid (the data is only needed when data_amt != 0)
                dtp_dbi_hrst    = tx_type_hrst_i;
                dtp_tx_no_dat   = ~|tx_type_dat_amt_i; // Data amount == 0
                dtp_tx_last     = (~|dbi_tx_cnt_q) | tx_type_hrst_i | (~|tx_type_dat_amt_i); // Assert when (last data) | (HW-RST trans) | (No data trans)
                tx_type_rdy     = dtp_tx_rdy_i & dtp_tx_last & dtp_tx_vld; // READY is assert when the last data is sent
                tx_com_rdy      = tx_type_rdy & (~tx_type_hrst_i); // Just assert when the transmission is not a HW-RST tx
                tx_data_rdy     = dtp_tx_rdy_i & dtp_tx_vld & (|tx_type_dat_amt_i) & (~tx_type_hrst_i);  // Just assert when the transmission has data field (data_amt != 0) and is not a HW-RST tx
                dbi_tx_cnt_d    = dbi_tx_cnt_q - (dtp_tx_rdy_i & dtp_tx_vld_o);
                // FSM
                dbi_tx_st_d = (tx_type_rdy_o & tx_type_vld_i) ? (tx_type_hrst_i ? DBI_RST_STALL_ST : IDLE_ST) : dbi_tx_st_q; // When a transaction (except for Reset transmission) is completed, go back to IDLE state 
            end
            DBI_STREAM_TX: begin
                // Behav
                rgb_pxl_rdy     = dtp_tx_rdy_i;  
                dtp_tx_cmd_typ  = dbi_mem_com_i;
                dtp_tx_cmd_dat  = pxl_d_i;
                dtp_tx_vld      = pxl_vld_i; 
                dbi_tx_cnt_d    = dbi_tx_cnt_q - (dtp_tx_rdy_i & dtp_tx_vld_o);
                dtp_tx_last     = (~|dbi_tx_cnt_q);
                // FSM
                dbi_tx_st_d = (dtp_tx_rdy_i & dtp_tx_vld_o & dtp_tx_last) ? IDLE_ST : dbi_tx_st_q; // When a transaction is completed, go back to IDLE state
            end
        endcase 
    end

    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            dbi_tx_st_q <= IDLE_ST;
        end
        else begin
            dbi_tx_st_q <= dbi_tx_st_d;
        end
    end
    always @(posedge clk) begin
        rst_stall_cnt_q <= rst_stall_cnt_d;
    end
    always @(posedge clk) begin
        dbi_tx_cnt_q <= dbi_tx_cnt_d;
    end
endmodule
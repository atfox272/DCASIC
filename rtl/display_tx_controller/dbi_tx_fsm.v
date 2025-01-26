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
    input                       dbi_tx_start_i,
    input   [DBI_IF_D_W-1:0]    addr_soft_rst_i,
    input   [DBI_IF_D_W-1:0]    addr_disp_on_i,
    input   [DBI_IF_D_W-1:0]    addr_col_i,
    input   [DBI_IF_D_W-1:0]    addr_row_i,
    input   [DBI_IF_D_W-1:0]    addr_mem_wr_i,
    input   [DBI_IF_D_W-1:0]    cmd_s_col_h_i,
    input   [DBI_IF_D_W-1:0]    cmd_s_col_l_i,
    input   [DBI_IF_D_W-1:0]    cmd_e_col_h_i,
    input   [DBI_IF_D_W-1:0]    cmd_e_col_l_i,
    input   [DBI_IF_D_W-1:0]    cmd_s_row_h_i,
    input   [DBI_IF_D_W-1:0]    cmd_s_row_l_i,
    input   [DBI_IF_D_W-1:0]    cmd_e_row_h_i,
    input   [DBI_IF_D_W-1:0]    cmd_e_row_l_i,
    // -- To AXI4 FIFO
    input   [DBI_IF_D_W-1:0]    pxl_d_i,
    input                       pxl_vld_i,
    // -- To DBI TX PHY
    input                       dtp_tx_rdy_i,
    // Output declaration
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
    localparam IDLE_ST          = 3'd0;
    localparam DBI_RST_ST       = 3'd1;
    localparam DBI_RST_CNCL_ST  = 3'd6;
    localparam DBI_SET_COL_ST   = 3'd2;
    localparam DBI_SET_ROW_ST   = 3'd3;
    localparam DBI_DISP_ST      = 3'd4;
    localparam DBI_STM_ST       = 3'd5;

    localparam NOP_CMD          = 8'h00;
    localparam RST_STALL_SEC    = 5e-3;
    localparam RST_STALL_CYC    = $rtoi(RST_STALL_SEC*INTERNAL_CLK);
    localparam RST_STALL_W      = $clog2(RST_STALL_CYC);

    localparam DBI_TX_PER_TXN   = 153600;
    localparam DBI_TX_CNT_W     = $clog2(DBI_TX_PER_TXN);

    // Internal signal
    // -- wire
    reg     [2:0]               dbi_tx_st_d;
    reg     [RST_STALL_W-1:0]   rst_stall_cnt_d;
    reg                         dtp_dbi_hrst_d;
    reg     [DBI_IF_D_W-1:0]    dtp_tx_cmd_typ_d;
    reg     [DBI_IF_D_W-1:0]    dtp_tx_cmd_dat_d;
    reg                         dtp_tx_last_d;
    reg                         dtp_tx_vld_d;
    reg     [DBI_TX_CNT_W-1:0]  dbi_tx_cnt_d;
    reg                         dtp_tx_no_dat_d;
    wire    [DBI_TX_CNT_W-1:0]  set_col_list    [0:3];
    wire    [DBI_TX_CNT_W-1:0]  set_col_map;
    wire    [DBI_TX_CNT_W-1:0]  set_row_list    [0:3];
    wire    [DBI_TX_CNT_W-1:0]  set_row_map;
    reg                         rgb_pxl_rdy;
    // -- reg
    reg     [2:0]               dbi_tx_st_q;
    reg     [RST_STALL_W-1:0]   rst_stall_cnt_q;
    reg     [DBI_TX_CNT_W-1:0]  dbi_tx_cnt_q;

    // Combination logic
    assign dtp_dbi_hrst_o   = dtp_dbi_hrst_d;
    assign dtp_tx_cmd_typ_o = dtp_tx_cmd_typ_d;
    assign dtp_tx_cmd_dat_o = dtp_tx_cmd_dat_d;
    assign dtp_tx_last_o    = dtp_tx_last_d;
    assign dtp_tx_no_dat_o  = dtp_tx_no_dat_d;
    assign dtp_tx_vld_o     = dtp_tx_vld_d;
    assign pxl_rdy_o        = rgb_pxl_rdy;
    assign set_col_list[0]  = cmd_s_col_h_i;
    assign set_col_list[1]  = cmd_s_col_l_i;
    assign set_col_list[2]  = cmd_e_col_h_i;
    assign set_col_list[3]  = cmd_e_col_l_i;
    assign set_row_list[0]  = cmd_s_row_h_i;
    assign set_row_list[1]  = cmd_s_row_l_i;
    assign set_row_list[2]  = cmd_e_row_h_i;
    assign set_row_list[3]  = cmd_e_row_l_i;
    assign set_col_map      = set_col_list[dbi_tx_cnt_q[1:0]];
    assign set_row_map      = set_row_list[dbi_tx_cnt_q[1:0]];
    always @(*) begin
        dbi_tx_st_d         = dbi_tx_st_q;
        rst_stall_cnt_d     = rst_stall_cnt_q;
        dbi_tx_cnt_d        = dbi_tx_cnt_q;
        dtp_tx_cmd_typ_d    = NOP_CMD;
        dtp_tx_cmd_dat_d    = NOP_CMD;
        rgb_pxl_rdy         = 1'b0;
        dtp_dbi_hrst_d      = 1'b0;
        dtp_tx_last_d       = 1'b0;
        dtp_tx_no_dat_d     = 1'b0;
        dtp_tx_vld_d        = 1'b0;
        case(dbi_tx_st_q) 
            IDLE_ST: begin
                if(dbi_tx_start_i) begin
                    dbi_tx_st_d     = DBI_RST_ST;
                end
            end
            DBI_RST_ST: begin
                dtp_tx_vld_d        = 1'b1;
                dtp_dbi_hrst_d      = 1'b1;
                if(dtp_tx_rdy_i) begin
                    dbi_tx_st_d     = DBI_RST_CNCL_ST;
                    rst_stall_cnt_d = (RST_STALL_CYC - 1);
                end
            end
            DBI_RST_CNCL_ST: begin
                rst_stall_cnt_d     = rst_stall_cnt_q - 1'b1;
                if(~|rst_stall_cnt_q) begin
                    dbi_tx_st_d     = DBI_SET_COL_ST;
                    dbi_tx_cnt_d    = {DBI_TX_CNT_W{1'b0}};
                end
            end
            DBI_SET_COL_ST: begin
                dtp_tx_cmd_typ_d    = addr_col_i;
                dtp_tx_cmd_dat_d    = set_col_map;
                dtp_tx_vld_d        = 1'b1;
                dtp_tx_last_d       = &dbi_tx_cnt_q[1:0];
                if(dtp_tx_rdy_i) begin   // Handshake
                    dbi_tx_cnt_d    = dbi_tx_cnt_q + 1'b1;
                    if (dtp_tx_last_d) begin   // Handshake with the 4th transfer
                        dbi_tx_st_d = DBI_SET_ROW_ST;
                        dbi_tx_cnt_d= {DBI_TX_CNT_W{1'b0}};
                    end
                end
            end
            DBI_SET_ROW_ST: begin
                dtp_tx_cmd_typ_d    = addr_row_i;
                dtp_tx_cmd_dat_d    = set_row_map;
                dtp_tx_vld_d        = 1'b1;
                dtp_tx_last_d       = &dbi_tx_cnt_q[1:0];
                if(dtp_tx_rdy_i) begin   // Handshake
                    dbi_tx_cnt_d    = dbi_tx_cnt_q + 1'b1;
                    if (dtp_tx_last_d) begin   // Handshake with the 4th transfer
                        dbi_tx_st_d = DBI_DISP_ST;
                        dbi_tx_cnt_d= {DBI_TX_CNT_W{1'b0}};
                    end
                end
            end
            DBI_DISP_ST: begin
                dtp_tx_cmd_typ_d    = addr_disp_on_i;
                dtp_tx_no_dat_d     = 1'b1;
                dtp_tx_vld_d        = 1'b1;
                dtp_tx_last_d       = 1'b1;
                if (dtp_tx_rdy_i) begin
                    dbi_tx_st_d     = DBI_STM_ST;
                end
            end
            DBI_STM_ST: begin
                dtp_tx_cmd_typ_d    = addr_mem_wr_i;
                dtp_tx_cmd_dat_d    = pxl_d_i;
                dtp_tx_vld_d        = pxl_vld_i;
                rgb_pxl_rdy         = dtp_tx_rdy_i;
                dtp_tx_last_d       = ~|(dbi_tx_cnt_q^(DBI_TX_PER_TXN-1));
                if(dtp_tx_rdy_i) begin
                    dbi_tx_cnt_d    = dbi_tx_cnt_q + (dtp_tx_rdy_i & dtp_tx_vld_o);
                    if(dtp_tx_last_d) begin
                        dbi_tx_cnt_d= {DBI_TX_CNT_W{1'b0}};
                        if(~dbi_tx_start_i) begin
                            dbi_tx_st_d = IDLE_ST;  // Stopped by user
                        end
                    end
                end
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
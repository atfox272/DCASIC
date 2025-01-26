module dbi_tx_phy 
#(
    parameter INTERNAL_CLK      = 125000000,
    // DBI Interface
    parameter DBI_IF_D_W        = 8
) (
    // Input declaration
    input                       clk,
    input                       rst_n,
    // -- To DBI TX FSM
    input                       dtf_dbi_hrst_i,
    input   [DBI_IF_D_W-1:0]    dtf_tx_cmd_typ_i,
    input   [DBI_IF_D_W-1:0]    dtf_tx_cmd_dat_i,
    input                       dtf_tx_no_dat_i,
    input                       dtf_tx_last_i,
    input                       dtf_tx_vld_i,
    // Output declaration
    // -- To DBI TX FSM
    output                      dtf_tx_rdy_o,
    // -- To DBI Interface
    inout   [DBI_IF_D_W-1:0]    dbi_d_o,
    output                      dbi_csx_o,
    output                      dbi_dcx_o,
    output                      dbi_resx_o,
    output                      dbi_rdx_o,
    output                      dbi_wrx_o
);
    // Local parameters
    localparam IDLE_ST          = 3'd0;
    localparam HRST_ST          = 3'd1;
    localparam CMD_ST           = 3'd2;
    localparam D_ST             = 3'd3;
    localparam TXN_STALL_ST     = 3'd4;

    localparam T_WRL_SEC        = 33e-9;
    localparam T_WRH_SEC        = 33e-9;
    localparam T_HRST_SEC       = 12e-6;
    localparam T_TXN_PAU_SEC    = T_WRL_SEC + T_WRL_SEC;    // Min value is 0ns, but i recommand that it should be greater than the timing of the Write Cycle
    localparam T_WRL_CYC        = $rtoi(T_WRL_SEC * INTERNAL_CLK);
    localparam T_WRH_CYC        = $rtoi(T_WRH_SEC * INTERNAL_CLK);
    localparam T_HRST_CYC       = $rtoi(T_HRST_SEC * INTERNAL_CLK);
    localparam T_TXN_PAU_CYC    = $rtoi(T_TXN_PAU_SEC * INTERNAL_CLK);
    localparam T_CYC_MAX        = T_HRST_CYC;
    localparam T_CYC_W          = $clog2(T_CYC_MAX);
    // Internal signal
    // -- wire
    reg     [2:0]               dbi_phy_st_d;
    reg     [T_CYC_W-1:0]       tmr_cnt_d;
    reg                         dtf_tx_rdy;
    reg     [DBI_IF_D_W-1:0]    dbi_wr_d_d;
    reg                         dbi_dcx_d;
    reg                         dbi_csx_d;
    reg                         dbi_resx_d;
    reg                         dbi_rdx_d;
    reg                         dbi_wrx_d;
    reg                         dbi_d_ctrl_d;
    wire                        dtf_hsk;
    reg     [1:0]               tx_cnt_d;
    // -- reg
    reg     [2:0]               dbi_phy_st_q;
    reg     [T_CYC_W-1:0]       tmr_cnt_q;
    reg     [DBI_IF_D_W-1:0]    dbi_wr_d_q;
    reg                         dbi_dcx_q;
    reg                         dbi_csx_q;
    reg                         dbi_resx_q;
    reg                         dbi_rdx_q;
    reg                         dbi_wrx_q;
    reg                         dbi_d_ctrl_q;
    reg     [1:0]               tx_cnt_q;
    reg     [DBI_IF_D_W-1:0]    dtf_cmd_dat_buf;
    reg     [DBI_IF_D_W-1:0]    dtf_no_dat_buf;
    reg     [DBI_IF_D_W-1:0]    dtf_last_buf;

    // TODO: 
    // -- Summary all timing of DBI protocol    (Done)
    // -- FSM Coding                            (On-going)
    // Combination logic
    assign dbi_d_o      = dbi_d_ctrl_q ? dbi_wr_d_q : {DBI_IF_D_W{1'bz}};
    assign dbi_dcx_o    = dbi_dcx_q;
    assign dbi_csx_o    = dbi_csx_q;
    assign dbi_resx_o   = dbi_resx_q;
    assign dbi_rdx_o    = dbi_rdx_q;
    assign dbi_wrx_o    = dbi_wrx_q;
    assign dtf_tx_rdy_o = dtf_tx_rdy;
    assign dtf_hsk      = dtf_tx_vld_i & dtf_tx_rdy_o;
    always @(*) begin
        dbi_phy_st_d        = dbi_phy_st_q;
        tmr_cnt_d           = tmr_cnt_q;
        dtf_tx_rdy          = 1'b0;
        dbi_wr_d_d          = dbi_wr_d_q;
        dbi_dcx_d           = dbi_dcx_q;
        dbi_csx_d           = dbi_csx_q;
        dbi_resx_d          = dbi_resx_q;
        dbi_rdx_d           = dbi_rdx_q;
        dbi_wrx_d           = dbi_wrx_q;
        dbi_d_ctrl_d        = dbi_d_ctrl_q;
        tx_cnt_d            = tx_cnt_q;
        case(dbi_phy_st_q)
            IDLE_ST: begin
                dtf_tx_rdy  = 1'b1;
                if(dtf_tx_vld_i) begin
                    if(dtf_dbi_hrst_i) begin    // Hardware reset state
                        dbi_phy_st_d = HRST_ST;
                        dbi_resx_d   = 1'b0;
                        tmr_cnt_d    = (T_HRST_CYC-1);
                    end
                    else begin                  // Command staet
                        dbi_phy_st_d = CMD_ST;
                        dbi_wr_d_d   = dtf_tx_cmd_typ_i;
                        dbi_d_ctrl_d = 1'b1;
                        dbi_csx_d    = 1'b0;
                        dbi_dcx_d    = 1'b0;
                        dbi_wrx_d    = 1'b0;
                        tmr_cnt_d    = (T_WRL_CYC-1);
                    end
                end
            end
            HRST_ST: begin
                tmr_cnt_d = tmr_cnt_q - 1'b1;
                if(~|tmr_cnt_q) begin
                    dbi_phy_st_d = TXN_STALL_ST;
                    dbi_resx_d   = 1'b1;
                    tmr_cnt_d    = (T_TXN_PAU_CYC-1);
                end
            end
            CMD_ST: begin
                tmr_cnt_d = tmr_cnt_q - 1'b1;
                if (~|tmr_cnt_q) begin
                    if (dbi_wrx_q) begin
                        if(dtf_no_dat_buf) begin    // Transmission with 1 command - 0 parameter
                            dbi_phy_st_d = TXN_STALL_ST;
                            dbi_d_ctrl_d = 1'b0;
                            dbi_csx_d    = 1'b1;
                            tmr_cnt_d    = (T_TXN_PAU_CYC-1);
                        end
                        else begin                  // Transmission with 1 command - n parameters
                            dbi_phy_st_d = D_ST;
                            dbi_wr_d_d   = dtf_cmd_dat_buf;
                            dbi_dcx_d    = 1'b1;
                            dbi_wrx_d    = 1'b0;
                            tmr_cnt_d    = (T_WRL_CYC-1);
                            tx_cnt_d     = 2'd0;
                        end
                    end
                    else begin
                        dbi_wrx_d = 1'b1;
                        tmr_cnt_d = (T_WRH_CYC-1);
                    end
                end
            end
            D_ST: begin
                tmr_cnt_d = tmr_cnt_q - 1'b1;
                if (~|tmr_cnt_q) begin
                    if (dbi_wrx_q) begin
                        if(dtf_last_buf) begin          // The data that was sent recently is the LAST data 
                            dbi_phy_st_d = TXN_STALL_ST;
                            dbi_d_ctrl_d = 1'b0;
                            dbi_csx_d    = 1'b1;
                            tmr_cnt_d    = (T_TXN_PAU_CYC-1);
                        end
                        else begin
                            dtf_tx_rdy = 1'b1;
                            if(dtf_tx_vld_i) begin      // Data from the camera sensor is valid
                                dbi_wr_d_d   = dtf_tx_cmd_dat_i;
                                dbi_wrx_d    = 1'b0;
                                tmr_cnt_d    = (T_WRL_CYC-1);
                            end
                            else begin                  // Waiting for data from the camera sensor
                                tmr_cnt_d = tmr_cnt_q;
                            end
                        end
                    end
                    else begin
                        dbi_wrx_d = 1'b1;
                        tmr_cnt_d = (T_WRH_CYC-1);
                    end
                end
            end
            TXN_STALL_ST: begin
                tmr_cnt_d = tmr_cnt_q - 1'b1;
                if (~|tmr_cnt_q) begin
                    dbi_phy_st_d = IDLE_ST;
                end
            end
            
        endcase
    end

    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dbi_phy_st_q <= IDLE_ST;
        end
        else begin
            dbi_phy_st_q <= dbi_phy_st_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_cnt_q <= {T_CYC_W{1'b0}};
        end
        else begin
            tmr_cnt_q <= tmr_cnt_d;
        end
    end

    always @(posedge clk) begin
        dbi_wr_d_q <= dbi_wr_d_d;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dbi_csx_q <= 1'b1;
        end
        else begin
            dbi_csx_q <= dbi_csx_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dbi_dcx_q <= 1'b1;
        end
        else begin
            dbi_dcx_q <= dbi_dcx_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dbi_resx_q <= 1'b1;
        end
        else begin
            dbi_resx_q <= dbi_resx_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dbi_rdx_q <= 1'b1;
        end
        else begin
            dbi_rdx_q <= dbi_rdx_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dbi_wrx_q <= 1'b1;
        end
        else begin
            dbi_wrx_q <= dbi_wrx_d;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dbi_d_ctrl_q <= 1'b0;
        end
        else begin
            dbi_d_ctrl_q <= dbi_d_ctrl_d;
        end
    end
    always @(posedge clk) begin
        if (~rst_n) begin
            tx_cnt_q <= 2'd00;
        end
        else begin
            tx_cnt_q <= tx_cnt_d;
        end
    end

    always @(posedge clk) begin
        if(dtf_hsk) begin
            dtf_cmd_dat_buf <= dtf_tx_cmd_dat_i;
            dtf_no_dat_buf  <= dtf_tx_no_dat_i;
            dtf_last_buf    <= dtf_tx_last_i;
        end
    end
endmodule
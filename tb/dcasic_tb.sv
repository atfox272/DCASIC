`timescale 1ns/1ps

`define DUT_CLK_PERIOD  2
`define DVP_CLK_PERIOD  12
`define RST_DLY_START   3
`define RST_DUR         9

`define END_TIME        500000

// DVP Physical characteristic
// -- t_PDV = 5 ns = (5/INTERNAL_CLK_PERIOD)*DUT_CLK_PERIOD = (5/8)*2
`define DVP_PCLK_DLY    1.25

// SCCB Physical characteristic
`define SCCB_DVC_LATENCY 2 // Time unit

module dcasic_tb;
    parameter DVP_DATA_W        = 8;
    parameter DBI_IF_D_W        = 8;
    parameter MC_DATA_W         = 8;
    parameter DATA_W            = 32;
    parameter ADDR_W            = 32;
    parameter MST_ID_W          = 5;
    parameter TRANS_DATA_LEN_W  = 8;
    parameter TRANS_DATA_SIZE_W = 3;
    parameter TRANS_RESP_W      = 2;

    logic                       sys_clk;
    logic                       sys_trap_o;
    logic                       rst_n;
    // Camera RX Interface
    logic   [DVP_DATA_W-1:0]    dvp_d_i;
    logic                       dvp_href_i;
    logic                       dvp_vsync_i;
    logic                       dvp_hsync_i;
    logic                       dvp_pclk_i;
    logic                       dvp_xclk_o;
    // Display TX Interface
    logic                       dbi_dcx_o;
    logic                       dbi_csx_o;
    logic                       dbi_resx_o;
    logic                       dbi_rdx_o;
    logic                       dbi_wrx_o;
    wire    [DBI_IF_D_W-1:0]    dbi_d_o;
    // Camera Controller Interface
    logic                       sio_c;
    wire                        sio_d;
   

    dcasic #(
        .BOOTLOADER_FILE("L:/Projects/dcasic/bootloader/program_0.txt")
    ) dut (
        .*
    );


    initial begin
        sys_clk         <= 0;
        rst_n           <= 1;

        // DVP interface
        dvp_d_i         <= 0;    
        dvp_href_i      <= 0;
        dvp_vsync_i     <= 0;
        dvp_hsync_i     <= 0;
        dvp_pclk_i      <= 0;

        #(`RST_DLY_START)   rst_n <= 0;
        #(`RST_DUR)         rst_n <= 1;
    end

    initial begin
        forever #(`DUT_CLK_PERIOD/2) sys_clk <= ~sys_clk;
    end
    
    initial begin
        #(`END_TIME) $finish;
    end

    // PCLK generator 
    always @(dvp_xclk_o) begin
        #1; dvp_pclk_i <= dvp_xclk_o;
    end

    reg [63:0]  temp = '0;
    always @(posedge dvp_href_i) begin
        temp <= temp + 1'b1;
    end

    initial begin
        repeat(40) begin
            aclk_cl;
        end
        dvp_driver();
    end
    initial begin
        #(`END_TIME) $finish;
    end

    /*      DeepCode        */
    task automatic aclk_cl;
        @(posedge sys_clk);
        #0.05; 
    endtask


    /* ------------------------------ DVP RX Controller ------------------------------ */
    
    int pclk_cnt    = 0;
    int dvp_st      = 0;
    int tx_cnt      = 0;
    
    task automatic pclk_cl;
        @(negedge dvp_xclk_o);
        #(`DVP_PCLK_DLY); 
    endtask

    task automatic dvp_driver();
        // Important note: 
        //      - Data and Control signal in DVP are changed in FALLING edge of PCLK
        //          + T_clk_delay   = 5ns
        //          + T_setup       = 15ns
        //          + T_hold        = 8ns
        //      -> Data will be stable befor RISING edge 
        //      -> (Delay time to sample data at RISING edge) < 8ns
        localparam DVP_IDLE_ST          = 0;
        localparam DVP_SOF_ST           = 1;
        localparam DVP_PRE_TXN_ST       = 2;
        localparam DVP_PRE_HSYNC_FALL_ST= 3;
        localparam DVP_HSYNC_FALL_ST    = 4;
        localparam DVP_PRE_TX_ST        = 5;
        localparam DVP_TX_ST            = 6;
        localparam DVP_POST_TXN         = 7;
        localparam DVP_EOF_ST           = 8;
        int stall_cnt                   = 0;
        while(1'b1) begin
            stall_cnt = $urandom_range(10, 20);
            repeat(stall_cnt) begin
                pclk_cl;  
            end
            while (1'b1) begin
                case(dvp_st)
                    DVP_IDLE_ST: begin
                        dvp_st      = DVP_SOF_ST;
                        pclk_cnt    = 3*784*2;
                        dvp_vsync_i <= 1'b1;
                    end
                    DVP_SOF_ST: begin
                    if(pclk_cnt == 0) begin
                        dvp_st      = DVP_PRE_TXN_ST;
                        pclk_cnt    = 17*784*2 - 80*2 - 40*2 - 19*2;
                        dvp_vsync_i <= 1'b0;
                    end
                    end
                    DVP_PRE_TXN_ST: begin
                    if(pclk_cnt == 0) begin
                        dvp_st      = DVP_PRE_HSYNC_FALL_ST;
                        pclk_cnt    = 19*2;
                        dvp_hsync_i <= 1'b1;
                    end
                    end
                    DVP_PRE_HSYNC_FALL_ST: begin
                    if(pclk_cnt == 0) begin
                        dvp_st      = DVP_HSYNC_FALL_ST;
                        pclk_cnt    = 80*2;
                        dvp_hsync_i <= 1'b0;
                    end
                    end
                    DVP_HSYNC_FALL_ST: begin
                        if(pclk_cnt == 0) begin
                            dvp_st      = DVP_PRE_TX_ST;
                            pclk_cnt    = 40*2;
                            dvp_hsync_i <= 1'b1;
                        end
                    end
                    DVP_PRE_TX_ST: begin
                        if(pclk_cnt == 0) begin
                            if(tx_cnt == (640*480*2)) begin
                                dvp_st      = DVP_POST_TXN;
                                pclk_cnt    = 10*784*2 - 80*2 - 40*2 - 19*2;
                                tx_cnt      = 0;
                            end
                            else begin
                                dvp_st      = DVP_TX_ST;
                                dvp_href_i  <= 1'b1;
                                dvp_d_i     <= tx_cnt%32;
                            end
                        end
                    end
                    DVP_TX_ST: begin
                        tx_cnt = tx_cnt + 1;
                        dvp_d_i     <= tx_cnt%32;
                        if(tx_cnt%(640*2) == 0) begin
                            dvp_st      = DVP_PRE_HSYNC_FALL_ST;
                            pclk_cnt    = 19*2;
                            dvp_hsync_i <= 1'b1;
                            dvp_href_i  <= 1'b0;
                        end
                    end
                    DVP_POST_TXN: begin
                        if(pclk_cnt == 0) begin
                            dvp_st      = DVP_EOF_ST;
                            pclk_cnt    = 3*784*2;
                            dvp_vsync_i <= 1'b1;
                        end
                    end
                    DVP_EOF_ST: begin
                        if(pclk_cnt == 0) begin
                            dvp_st      = DVP_IDLE_ST;
                            pclk_cnt    = 0;
                            dvp_vsync_i <= 1'b0;
                            break;
                        end
                    end
                endcase
                pclk_cl;
                pclk_cnt = pclk_cnt - 1;
            end
        end
    endtask
    /* ------------------------------ DVP RX Controller ------------------------------ */

    
    /* ------------------------------ DBI TX Controller ------------------------------ */ 
    /* ------------------------------ DBI TX Controller ------------------------------ */ 

    /* ------------------------------ SCCB Monitor ------------------------------ */
    localparam SCCB_IDLE_ST     = 4'd00;
    localparam SCCB_TX_DAT_ST   = 4'd02;
    localparam SCCB_TX_ACK_ST   = 4'd03;
    localparam SCCB_RX_DAT_ST   = 4'd04;
    localparam SCCB_RX_ACK_ST   = 4'd05;
    logic [3:0] sccb_slv_st = SCCB_IDLE_ST;
    logic [7:0] tx_data     [0:2];  // Data buffer of phase 1-2-3
    logic       tx_data_vld = 0;
    logic [1:0] phase_cnt   = 0;    // 0 -> 2
    logic [2:0] sioc_cl_cnt = 7;
    logic       start_tx_flg= 1;
    logic       start_tx_slv= 0;
    
    logic       sio_oe_m = 0;   // Master SIO_D output enable
    logic       sio_d_slv;
    assign sio_d = sio_oe_m ? sio_d_slv : 1'bz;

    always @(negedge sio_c) begin
        if(~rst_n) begin
          
        end
        else begin
            tx_data_vld <= 0;
            case(sccb_slv_st)
                SCCB_IDLE_ST: begin
                    if(start_tx_slv) begin
                        start_tx_slv = 0;
                    end
                    else begin
                        sccb_slv_st <= SCCB_TX_DAT_ST;
                        sioc_cl_cnt <= sioc_cl_cnt - 1;
                        tx_data[phase_cnt][sioc_cl_cnt] <= sio_d;
                    end
                end
                SCCB_TX_DAT_ST: begin
                    if(sioc_cl_cnt == 7) begin // Received all bits (8bit)
                        if((phase_cnt == 0) & (tx_data[phase_cnt][0])) begin  // Next phase is a READ phase
                            #(`SCCB_DVC_LATENCY);
                            sccb_slv_st    <= SCCB_RX_DAT_ST;
                            sio_oe_m  <= 1'b1;  // Control the bus
                            sio_d_slv <= tx_data[1][sioc_cl_cnt];   // Return the previous transmission's sub-address 
                            sioc_cl_cnt <= sioc_cl_cnt - 1;
                        end
                        else begin
                            sccb_slv_st <= SCCB_IDLE_ST;
                            tx_data_vld <= 1; 
                        end
                        phase_cnt   <= phase_cnt + 1'b1;
                    end
                    else begin
                        sioc_cl_cnt <= sioc_cl_cnt - 1;
                        tx_data[phase_cnt][sioc_cl_cnt] <= sio_d;
                    end
                end
                SCCB_TX_ACK_ST: begin
                    sccb_slv_st <= SCCB_IDLE_ST;
                end
                SCCB_RX_DAT_ST: begin
                    if(sioc_cl_cnt == 7) begin // overflow -> received all bits
                        sccb_slv_st      <= SCCB_IDLE_ST;
                        sio_oe_m    <= 1'b0; // Float the bus
                        phase_cnt   <= phase_cnt + 1'b1;
                    end
                    else begin
                        sio_d_slv   <= tx_data[phase_cnt][sioc_cl_cnt];   // Return the previous transmission's sub-address 
                        sioc_cl_cnt <= sioc_cl_cnt - 1;
                    end
                end
                SCCB_RX_ACK_ST: begin
                end
            endcase
        end
    end
    initial begin : STOP_DATA_TRANS_DET
        // SIO_D is changing state while SIO_C is HIGH 
        while(1'b1) begin
            @(posedge sio_d);
            #0.1;
            if(sio_c) begin 
                if(start_tx_flg) begin  // This case is the "Start Data Transmission"
                    start_tx_flg = 0;
                    start_tx_slv = 1;   // Flag to Slave FSM 
                    sccb_slv_st      <= SCCB_IDLE_ST;
                    sioc_cl_cnt <= 3'd7;
                    phase_cnt   <= 0;
                    tx_data[2]  <= 8'h00;   // Reset DATA buffer
                end
                else begin
                    $display("------------ Slave new info ------------");
                    if(~tx_data[0][0]) begin// Write transmission
                        $display("Completed 1 write transmission");
                        $display("Number of phases:     %2d", phase_cnt);
                        $display("SLAVE DEVICE ADDRESS: %2h", tx_data[0]);
                        $display("SUB-ADDRESS:          %2h", tx_data[1]);
                        $display("WRITE DATA:           %2h", tx_data[2]);
                    end
                    else begin              // Read transmission
                        $display("Completed 1 read transmission");
                        $display("Number of phases:     %2d", phase_cnt);
                        $display("SLAVE DEVICE ADDRESS: %2h", tx_data[0]);
                        $display("READ DATA:            %2h", tx_data[1]);
                    end
                    $display("----------------------------------------");
                    // Reset the state and buffer in slv
                    start_tx_flg = 1;
                    sccb_slv_st      <= SCCB_IDLE_ST;
                    sioc_cl_cnt <= 3'd7;
                    phase_cnt   <= 0;
                    tx_data[2]  <= 8'h00;   // Reset DATA buffer
                end
            end
        end
    end
    /* ------------------------------ SCCB Monitor ------------------------------ */
endmodule
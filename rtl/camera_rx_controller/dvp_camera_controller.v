module dvp_camera_controller
#(
    parameter INTL_CLK_PERIOD   = 125000000,
    parameter DVP_CAM_CFG_W     = 32 // DVP Camera configuration register
)
(
    // Input declaration
    // -- Global
    input                       clk,
    input                       rst_n,
    // -- DVP Configuration register
    input   [DVP_CAM_CFG_W-1:0] dcr_cam_cfg_i,
    // -- Output declaration
    // -- DVP Camera interface
    output                      dvp_xclk_o,
    output                      dvp_pwdn_o
);
    // Local parameters
    localparam CAM_MAX_FREQ = 24000000;
    localparam PRES_CTN_MAX = INTL_CLK_PERIOD / CAM_MAX_FREQ;   // 125/24 = 5
    localparam PRESC_CTN_W  = $clog2(PRES_CTN_MAX);
    // Internal signal
    // -- wire declaration
    wire                        cam_start;      // camera start bit
    wire                        cam_pwdn;       // camera power down bit
    wire    [1:0]               cam_presc;      // Camera prescaler
    wire    [PRESC_CTN_W-1:0]   presc_ctn_d;
    wire                        presc_ctn_ex;   // Prescaler counter exceeded
    wire                        xclk_toggle;
    // -- reg declaration
    reg     [PRESC_CTN_W-1:0]   presc_ctn_q;
    reg                         xclk_q;
    
    // Combination logic
    // -- Output
    assign dvp_xclk_o   = xclk_q;
    assign dvp_pwdn_o   = cam_pwdn;
    assign cam_start    = dcr_cam_cfg_i[5'h00];
    assign cam_pwdn     = dcr_cam_cfg_i[5'h01];
    assign cam_presc    = dcr_cam_cfg_i[1:0];
    assign presc_ctn_ex = (presc_ctn_q == PRES_CTN_MAX-1);
    assign xclk_toggle  = (presc_ctn_q == PRES_CTN_MAX/2 - 1);
    assign presc_ctn_d  = (cam_start & !presc_ctn_ex) ? presc_ctn_q + 1'b1 : {PRESC_CTN_W{1'b0}};
    
    // Flip-flop
    // -- Prescaler counter
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            presc_ctn_q <= {PRESC_CTN_W{1'b0}};
        end
        else begin
            presc_ctn_q <= presc_ctn_d;
        end
    end
    // -- XCLK generator
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            xclk_q <= 1'b0;
        end
        else if(xclk_toggle) begin
            xclk_q <= ~xclk_q;
        end
    end
endmodule

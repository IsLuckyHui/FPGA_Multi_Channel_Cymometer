module top_cymometer#(
    //parameter define
    parameter DIV_N = 26'd10_000_000 , // 分频系数
    parameter CHAR_POS_X = 11'd1 , // 字符区域起始X坐标
    parameter CHAR_POS_Y = 11'd1 , // 字符区域起始Y坐标
    parameter CHAR_WIDTH = 11'd88 , // 字符区域宽度
    parameter CHAR_HEIGHT = 11'd16 , // // 字符区域高度
    parameter WHITE = 24'hFFFFFF , // 背景颜色：白色
    parameter BLACK = 24'h0 , // 字符颜色：黑色
    parameter CNT_GATE_MAX = 28'd75_000_000 , // 闸门总周期 1.5s
    parameter CNT_GATE_LOW = 28'd12_500_000 , // 闸门低电平时间 0.25s
    parameter CNT_TIME_MAX = 28'd80_000_000 , // 一次测量总时长 1.6s
    parameter CLK_FS_FREQ = 28'd100_000_000 , //参考时钟fs频率 100MHz
    parameter DATAWIDTH = 8'd57,              // 除法器位宽
    parameter CH_NUM = 5'd18            // 通道总数（每页显示9路）

)
(
    input        sys_clk    , // 系统时钟
    input        sys_rst_n  , // 复位信号，低电平有效
  //  input        clk_fx   , //  待测时钟（0通道外部输入，旧端口）
    output       clk_out1   , // 输出测试时钟 5Hz
    output       clk_out2   , // PLL输出 133.3333MHz
    output       lcd_hs     , // LCD行同步信号
    output       lcd_vs     , // LCD场同步信号
    output       lcd_de     , // LCD数据使能
    inout [23:0] lcd_rgb    , // LCD RGB 24位颜色数据
    output       lcd_bl     , // LCD背光控制
    output       lcd_clk    , // LCD像素时钟
    output       lcd_rst    , // LCD复位
    //RTC实时时钟
    output               iic_scl,     //I2C时钟线
    inout                iic_sda,     //I2C数据线
    
      //TOUCH interface                  
    inout            touch_sda  ,  //触摸I2C数据线
    output           touch_scl  ,  //触摸I2C时钟线
    inout            touch_int  ,  //触摸中断信号
    output           touch_rst_n,  //触摸芯片复位，低有效
   
    input [CH_NUM-1:0] clk_fx_ch_ext //外部可接入18个频率测试
);
    
//wire define
wire [CH_NUM*30-1:0] data_fx_all ; // 所有通道测频结果，每路占30bit
wire        clk_fs   ;   //  等精度参考时钟 100MHz
wire [31:0] touch_data ; // 触摸坐标数据
wire [15:0] lcd_id     ; // 屏幕ID，触摸驱动使用
wire            page   ; // 翻页标志：0=第一页，1=第二页


// PLL生成参考时钟
clk_wiz_0 u_pll_100m(
.clk_out1 (clk_fs ), // 参考时钟 100M
.clk_out2 (clk_out2 ), // 输出133.3333M时钟
.reset (~sys_rst_n ), // PLL复位
.clk_in1 (sys_clk )
);

// 测试时钟模块，产生5Hz测试时钟输出
clk_test
#(
    .DIV (DIV_N )
)
u_clk_test(
    .sys_clk (sys_clk ),
    .sys_rst_n (sys_rst_n ),
    .clk_out (clk_out1 )
);

// ============================================================
// 多路等精度频率计：每个通道独立频率计 + 除法控制模块
// ============================================================
// 每一路待测时钟信号
wire [CH_NUM-1:0] clk_fx_ch ;
assign clk_fx_ch = clk_fx_ch_ext;
// 根据通道号返回不同分频系数，用于产生内部测试时钟
// 输出频率 = 50MHz / DIV
function [25:0] get_div;
    input [3:0] idx;
    begin
        case(idx)
            4'd1 : get_div = 26'd10_000_000; // 5Hz
            4'd2 : get_div = 26'd5_000_000 ; // 10Hz
            4'd3 : get_div = 26'd1_000_000 ; // 50Hz
            4'd4 : get_div = 26'd500_000   ; // 100Hz
            4'd5 : get_div = 26'd100_000   ; // 500Hz
            4'd6 : get_div = 26'd50_000    ; // 1KHz
            4'd7 : get_div = 26'd10_000    ; // 5KHz
            default: get_div = 26'd5_000   ; // 10KHz
        endcase
    end
endfunction

genvar i;
generate
    for(i = 0; i < CH_NUM; i = i + 1) begin : gen_ch

        // 通道1~8生成内部测试时钟，通道0使用外部输入时钟
      /*  if(i > 0) begin : gen_test_clk
            clk_test #(
                .DIV ( get_div(i[3:0]) )
            ) u_clk_test_ch (
                .sys_clk   ( sys_clk    ),
                .sys_rst_n ( sys_rst_n  ),
                .clk_out   ( clk_fx_ch[i] )
            );
        end*/

       // 单路除法交互信号
        wire [56:0] dividend ;  // 被除数
        wire [56:0] divisor  ;  // 除数
        wire        en       ;  // 除法使能
        wire        ready    ;  // 除法器就绪
        wire [56:0] quotient ;  // 商
        wire [56:0] remainder;  // 余数
        wire        vld_out  ;  // 除法结果有效标志

       // 例化等精度频率计模块
        cymometer #(
            .CNT_GATE_MAX (CNT_GATE_MAX),
            .CNT_GATE_LOW (CNT_GATE_LOW),
            .CNT_TIME_MAX (CNT_TIME_MAX),
            .CLK_FS_FREQ  (CLK_FS_FREQ )
        ) u_cymometer (
            .sys_clk   ( sys_clk        ),
            .clk_fs    ( clk_fs         ),
            .sys_rst_n ( sys_rst_n      ),
            .clk_fx    ( clk_fx_ch[i]   ), // 第i路待测时钟
            // 当前通道测频结果从第`i*30`位开始，向上取30位。写法等同与data_fx_all[ i*30 + 29 : i*30 ] 
            .data_fx   ( data_fx_all[i*30 +: 30] ), 
            .dividend  ( dividend       ),
            .divisor   ( divisor        ),
            .en        ( en             ),
            .ready     ( ready          ),
            .quotient  ( quotient       ),
            .remainder ( remainder      ),
            .vld_out   ( vld_out        )
        );

        // 每通道独立除法控制状态机
        div_fsm #(
            .DATAWIDTH (DATAWIDTH)
        ) u_div_fsm (
            .clk       ( sys_clk   ),
            .rst_n     ( sys_rst_n ),
            .en        ( en        ),
            .dividend  ( dividend  ),
            .divisor   ( divisor   ),
            .ready     ( ready     ),
            .quotient  ( quotient  ),
            .remainder ( remainder ),
            .vld_out   ( vld_out   )
        );

    end
endgenerate

// LCD字符显示模块
lcd_rgb_char
#(
   .CHAR_POS_X (CHAR_POS_X ),
    .CHAR_POS_Y (CHAR_POS_Y ),
    .CHAR_WIDTH (CHAR_WIDTH ),
    .CHAR_HEIGHT (CHAR_HEIGHT),
    .WHITE (WHITE ),
    .BLACK (BLACK ),
    .CH_NUM (CH_NUM )
)
u_lcd_rgb_char(
    .sys_clk (sys_clk ),
    .sys_rst_n (sys_rst_n ),
    .data_all (data_fx_all ), // 全部通道频率数据
    .touch_data (touch_data), // 触摸坐标输入
    .lcd_hs (lcd_hs ),
    .lcd_vs (lcd_vs ),
    .lcd_de (lcd_de ),
    .lcd_rgb (lcd_rgb ),
    .lcd_bl (lcd_bl ),
    .lcd_clk (lcd_clk ),
    .lcd_rst (lcd_rst ),
    .lcd_id (lcd_id ),
    .iic_scl (iic_scl),
    .iic_sda (iic_sda),
    .page (page)
);

// 触摸顶层驱动模块
touch_top  u_touch_top(
    .clk            (sys_clk    ),
    .rst_n          (sys_rst_n  ),

    .touch_rst_n    (touch_rst_n),
    .touch_int      (touch_int  ),
    .touch_scl      (touch_scl  ),
    .touch_sda      (touch_sda  ),
    
    .lcd_id         (lcd_id     ),
    .data           (touch_data ),  // 输出触摸坐标
    .page           (page       )
);

endmodule

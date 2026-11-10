module  lcd_rgb_char#(
    parameter CH_NUM = 4'd9                        , // 通道数量
    //parameter define                             
    parameter  CHAR_POS_X  = 11'd1                 , // 字符区域起始X坐标
    parameter  CHAR_POS_Y  = 11'd1                 , // 字符区域起始Y坐标
    parameter  CHAR_WIDTH  = 11'd88                , // 字符区域宽度
    parameter  CHAR_HEIGHT = 11'd16                , // 字符区域高度
    parameter  WHITE       = 24'hFFFFFF            , // 背景色：白色
    parameter  BLACK       = 24'h0                 , // 字符颜色：黑色
    parameter    SLAVE_ADDR = 7'b101_0001          , // I2C从机地址（PCF8563）
    parameter    BIT_CTRL   = 1'b0                 , // 字地址位宽控制（16bit / 8bit）
    parameter    CLK_FREQ   = 26'd50_000_000       , // I2C驱动模块输入时钟频率
    parameter    I2C_FREQ   = 18'd250_000          , // I2C SCL总线时钟频率
    parameter TIME_INIT = 48'h26_09_22_07_30_00     // RTC初始时间
)(
    input              sys_clk          ,
    input              sys_rst_n        ,      // 系统复位，低电平有效
    input      [CH_NUM*30-1:0] data_all ,      // 所有通道频率原始二进制数据，每个通道占30bit
    input      [31:0]  touch_data       ,      // 触摸屏坐标原始数据
    output             lcd_hs           ,      // LCD行同步信号
    output             lcd_vs           ,      // LCD场同步信号
    output             lcd_de           ,      // LCD数据使能
    inout      [23:0]  lcd_rgb          ,      // LCD RGB888双向色彩总线（读ID时复用）
    output             lcd_bl           ,      // LCD背光控制
    output             lcd_clk          ,      // LCD像素时钟
    output             lcd_rst          ,      // LCD复位信号
    output     [15:0]  lcd_id           ,               // LCD屏幕ID，供给触摸模块使用
    
  //RTC实时时钟（PCF8563）
    output               iic_scl,              // I2C时钟线 SCL
    inout                iic_sda,              // I2C数据线 SDA
    input                page                  // 页面切换标志：0=第一页，1=第二页
);

//parameter BIT_CTRL = 1'b1;
//wire define
wire  [10:0]  pixel_xpos            ;     // 当前扫描像素X坐标
wire  [10:0]  pixel_ypos            ;     // 当前扫描像素Y坐标
wire  [23:0]  pixel_data            ;     // 当前像素输出颜色数据
wire  [23:0]  lcd_rgb_o             ;     // 输出到LCD的RGB颜色（驱动输出）
wire          lcd_pclk              ;     // LCD像素时钟
wire  [CH_NUM*36-1:0] bcd_data_all  ;     // 全部通道BCD打包数据，每个通道9位BCD，共36bit
//touch
wire  [10:0]  pixel_xpos_w ;
wire  [10:0]  pixel_ypos_w ;
wire  [23:0]  pixel_data_w ;
wire  [35:0]  bcd_data_x   ;    // X坐标转成的BCD数据（36bit，9位BCD）
wire  [35:0]  bcd_data_y   ;    // Y坐标转成的BCD数据（36bit，9位BCD）


//I2C
wire          dri_clk   ;   // I2C操作本地驱动时钟
wire          i2c_exec  ;   // I2C读写触发信号
wire  [15:0]  i2c_addr  ;   // I2C访问地址
wire  [ 7:0]  i2c_data_w;   // I2C待写入数据
wire          i2c_done  ;   // I2C一次传输完成标志
wire          i2c_ack   ;   // I2C应答标志：0=收到ACK，1=无ACK
wire          i2c_rh_wl ;   // I2C读写控制：读/写选择
wire  [ 7:0]  i2c_data_r;   // I2C读出的数据

wire    [7:0]  sec      ;   // RTC 秒（BCD格式）
wire    [7:0]  min      ;   // RTC 分（BCD格式）
wire    [7:0]  hour     ;   // RTC 时（BCD格式）
wire    [7:0]  day      ;   // RTC 日（BCD格式）
wire    [7:0]  mon      ;   // RTC 月（BCD格式）
wire    [7:0]  year     ;   // RTC 年（BCD格式）r

//RGB888数据输出逻辑：DE有效时输出颜色，高阻用于读LCD ID
assign lcd_rgb = lcd_de ? lcd_rgb_o : {24{1'bz}};

// 读取RGB屏幕ID模块
rd_id u_rd_id(
    .clk            (sys_clk    ),
    .rst_n          (sys_rst_n  ),
    .lcd_rgb        (lcd_rgb    ), 
    
    .lcd_id         (lcd_id     )
);

// 时钟分频模块：根据读到的LCD ID输出对应屏幕驱动像素时钟
clk_div  u_clk_div(
    .clk            (sys_clk    ),
    .rst_n          (sys_rst_n  ),
    
    .lcd_id         (lcd_id     ),
    .lcd_pclk       (lcd_pclk   )
);

// 频率计二进制转BCD，每个通道实例一个转换模块
genvar bcd_i;
generate
    for(bcd_i = 0; bcd_i < CH_NUM; bcd_i = bcd_i + 1) begin : gen_bcd
        binary2bcd u_binary2bcd(
            .sys_clk        (sys_clk),
            .sys_rst_n      (sys_rst_n),
            .data           (data_all[bcd_i*30 +: 30]),
            .bcd_data       (bcd_data_all[bcd_i*36 +: 36])
        );
    end
endgenerate

// touch_data由触摸驱动在dri_clk（约1MHz）域更新，属于跨时钟域异步信号
// 如果直接送到sys_clk域的binary2bcd会出现亚稳态、采样撕裂
// （高低字节取自两次不同采样值），按住触摸时出现坐标跳变
// 使用两级打拍寄存器同步到sys_clk域
reg  [31:0]  touch_data_r1;
reg  [31:0]  touch_data_r2;
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        touch_data_r1 <= 32'd0;
        touch_data_r2 <= 32'd0;
    end
    else begin
        touch_data_r1 <= touch_data;
        touch_data_r2 <= touch_data_r1;
    end
end

// Y轴触摸坐标二进制转BCD
binary2bcd u_binary2bcd_y(
    .sys_clk         (sys_clk),
    .sys_rst_n       (sys_rst_n),
    .data            (touch_data_r2[15:0]),

    .bcd_data        (bcd_data_y)    
); 

// X轴触摸坐标二进制转BCD
binary2bcd u_binary2bcd_x(
    .sys_clk         (sys_clk),
    .sys_rst_n       (sys_rst_n),
    .data            (touch_data_r2[31:16]),

    .bcd_data        (bcd_data_x)    
);



// LCD画面渲染显示模块
lcd_display 
#(
    .CHAR_POS_X     (CHAR_POS_X  ),
    .CHAR_POS_Y     (CHAR_POS_Y  ),
    .CHAR_WIDTH     (CHAR_WIDTH  ),
    .CHAR_HEIGHT    (CHAR_HEIGHT ),
    .WHITE          (WHITE       ),
    .BLACK          (BLACK       ),
    .CH_NUM         (CH_NUM      )
)
u_lcd_display(
    .lcd_pclk       (lcd_pclk   ),
    .sys_rst_n      (sys_rst_n  ),
    .data_all       (bcd_data_all),   // all channel BCD data
    .touch_data     ({bcd_data_x[15:0], bcd_data_y[15:0]} ),  //high 16bit = X 4-digit BCD, low 16bit = Y 4-digit BCD
    .sec            (sec  ),
    .min            (min  ),
    .hour           (hour ),
    .day            (day  ),
    .mon            (mon  ),
    .year           (year ),
    .pixel_xpos     (pixel_xpos ),
    .pixel_ypos     (pixel_ypos ),
    .pixel_data     (pixel_data ),
    .page           (page      )
);



// LCD时序驱动模块，产生行场同步、DE、输出RGB时序
lcd_driver u_lcd_driver(
    .lcd_pclk       (lcd_pclk   ),
    .rst_n          (sys_rst_n  ),
    .lcd_id         (lcd_id     ),
    .pixel_data     (pixel_data ),

    .pixel_xpos     (pixel_xpos ),
    .pixel_ypos     (pixel_ypos ),
    .lcd_de         (lcd_de     ),
    .lcd_hs         (lcd_hs     ),
    .lcd_vs         (lcd_vs     ),
    .lcd_bl         (lcd_bl     ),
    .lcd_clk        (lcd_clk    ),
    .lcd_rst        (lcd_rst    ),
    .lcd_rgb        (lcd_rgb_o  )
);

// PCF8563 RTC实时时钟控制模块
pcf8563_ctrl #(
    .TIME_INIT (TIME_INIT)
)u_pcf8563_ctrl(
    .clk         (dri_clk   ),
    .ila_clk     (sys_clk   ),
    .rst_n       (sys_rst_n ),
    //IIC
    .i2c_rh_wl   (i2c_rh_wl ),
    .i2c_exec    (i2c_exec  ),
    .i2c_addr    (i2c_addr  ),
    .i2c_data_w  (i2c_data_w),
    .i2c_data_r  (i2c_data_r),
    .i2c_done    (i2c_done  ),
    //时分秒日月年输出（BCD）
    .sec         (sec       ),
    .min         (min       ),
    .hour        (hour      ),
    .day         (day       ),
    .mon         (mon       ),
    .year        (year      )
    );

// I2C底层驱动（给PCF8563使用）
i2c_dri_date#(
    .SLAVE_ADDR  (SLAVE_ADDR),  // PCF8563从机地址
    .CLK_FREQ      (CLK_FREQ  ),  // 模块输入时钟频率
    .I2C_FREQ      (I2C_FREQ  )   // IIC_SCL时钟频率
  
)  u_i2c_dri_date(      
    .clk           (sys_clk   ),           
    .rst_n         (sys_rst_n ),            
    //i2c interface                                      
    .i2c_exec      (i2c_exec  ),          
    .i2c_rh_wl     (i2c_rh_wl ),             
    .bit_ctrl      (BIT_CTRL  ),                 
    .i2c_addr      (i2c_addr  ),          
    .i2c_data_w    (i2c_data_w),                          
                                          
    .i2c_data_r    (i2c_data_r),                     
    .i2c_done      (i2c_done  ),                 
    .i2c_ack       (i2c_ack   ),                                 
    .scl           (iic_scl   ),          
    .sda           (iic_sda   ),                 
    //user interface
    .dri_clk       (dri_clk   )  
);



endmodule

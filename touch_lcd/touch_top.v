module touch_top(
    input       clk,//系统时钟
    input       rst_n,//系统复位
     
    output      touch_rst_n,//触摸屏复位
    inout       touch_int, //触摸屏中断
    output      touch_scl, //I2C的时钟
    inout       touch_sda, //I2C数据
    
    input   [15:0] lcd_id, //LCD屏幕ID
    output  [31:0] data,    //触摸点坐标
    output       page      //翻页标志（0：第一页 1：第二页）
);

//parameter define
parameter CLK_FREQ = 50_000_000 ; //i2c_dri 模块的驱动时钟频率(CLK_FREQ)
parameter I2C_FREQ = 250_000 ; //I2C 的 SCL 时钟频率 不超过400KHz
parameter REG_NUM_WID = 8 ; //一次读写寄存器的个数的位宽

//wire define
wire [6:0]             slave_addr ; //器件地址
wire                   i2c_exec ; //I2C 触发执行信号
wire                   i2c_rh_wl ; //I2C 读写控制信号
wire [15:0]            i2c_addr ; //I2C 器件内地址
wire [7:0]             i2c_data_w ; //I2C 要写的数据
wire                   bit_ctrl ; //字地址位控制(0:8b,1:16b)
wire [REG_NUM_WID-1:0] reg_num ; //一次读写寄存器的个数
wire [7:0]             i2c_data_r ; //I2C 读出的数据
wire                   i2c_done ; //I2C 操作完成
wire                   once_byte_done ; //一字节数据读/写操作完成
wire                   i2c_ack ; //应答标志
wire                   dri_clk ; //I2C 驱动时钟


//I2C驱动模块
i2c_dri_touch  #(
    .CLK_FREQ      (CLK_FREQ     ),
    .I2C_FREQ      (I2C_FREQ     ),
    .WIDTH         (REG_NUM_WID  )
    )
    u_i2c_dri_touch(   
    .clk           (clk          ),
    .rst_n         (rst_n        ),
                                 
    .slave_addr    (slave_addr    ),
    .i2c_exec      (i2c_exec      ),
    .i2c_rh_wl     (i2c_rh_wl     ),
    .i2c_addr      (i2c_addr      ),
    .i2c_data_w    (i2c_data_w    ),
    .bit_ctrl      (bit_ctrl      ),
    .reg_num       (reg_num       ),
    .i2c_data_r    (i2c_data_r    ),
    .i2c_done      (i2c_done      ),
    .once_byte_done(once_byte_done),
    .scl           (touch_scl     ),
    .sda           (touch_sda     ),
    .i2c_ack       (i2c_ack       ),

    .dri_clk       (dri_clk       ) 
    );

//触摸驱动模块
touch_dri  #(
    .WIDTH         (REG_NUM_WID   )
     )
    u_touch_dri(
    .clk           (dri_clk       ),
    .sys_clk       (clk           ),
    .rst_n         (rst_n         ),
                                  
    .slave_addr    (slave_addr    ),
    .i2c_exec      (i2c_exec      ),
    .i2c_rh_wl     (i2c_rh_wl     ),
    .i2c_addr      (i2c_addr      ),
    .i2c_data_w    (i2c_data_w    ),
    .bit_ctrl      (bit_ctrl      ),
    .reg_num       (reg_num       ),
                                  
    .i2c_data_r    (i2c_data_r    ),
    .i2c_ack       (i2c_ack       ),
    .i2c_done      (i2c_done      ),
    .once_byte_done(once_byte_done),
     
    .lcd_id        (lcd_id        ),
    .data          (data          ),
    .page          (page          ),
    .touch_rst_n   (touch_rst_n   ),
    .touch_int     (touch_int     )
    );


endmodule 
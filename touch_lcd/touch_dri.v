module touch_dri#(
    parameter WIDTH = 4'd8, //// 单次读写的寄存器数量位宽
    parameter DELAY_TIME_10MS = 10_000,
    parameter DELAY_TIME_50MS = 60_000 //60_000 - 10_000,
)
(
    input                   clk           ,
    input                   sys_clk       ,
    input                   rst_n         ,                                          
    output  reg [6:0]       slave_addr    , // I2C从机地址
    output  reg             i2c_exec      , // I2C读写触发信号
    output  reg             i2c_rh_wl     , // I2C读写控制：1读，0写
    output  reg [15:0]      i2c_addr      , // I2C操作寄存器地址
    output  reg [7:0]       i2c_data_w    , // I2C待写入数据
    output  reg             bit_ctrl      , // 地址位宽控制：0=8位地址，1=16位地址
    output  reg [WIDTH-1:0] reg_num       , // 本次连续读写的寄存器个数                                        
    input [7:0]             i2c_data_r    , // I2C读出的数据
    input                   i2c_ack       , // I2C应答信号，0=收到应答，1=无应答
    input                   i2c_done      , // I2C单次传输完成标志
    input                   once_byte_done, // 单字节读写完成标志    
    //LCD相关端口          
    input [15:0]            lcd_id        , // LCD屏幕ID，用来区分触摸芯片型号
    output reg [31:0]       data          , // 触摸点坐标数据，拼接 {X坐标,Y坐标}
    output reg              page          , // 页面切换标志：0=第一页，1=第二页；点击翻页区域翻转
    output reg              touch_rst_n   , // 触摸芯片复位，低电平有效
    inout                   touch_int      // 触摸中断信号INT
);

//parameter define
//翻页按钮有效区域，必须和lcd_display里UP_DOWN_POS_X/Y、UP_DOWN_WIDTH/HEIGHT保持一致
localparam  PAGE_AREA_X_MIN = 16'd650;   // 翻页区域X起始坐标
localparam  PAGE_AREA_X_MAX = 16'd745;   // 翻页区域X结束坐标
localparam  PAGE_AREA_Y_MIN = 16'd420;   // 翻页区域Y起始坐标
localparam  PAGE_AREA_Y_MAX = 16'd451;   // 翻页区域Y结束坐标
// FT系列触摸芯片参数
localparam FT_SLAVE_ADDR = 7'h38;    // FT系列从机地址
localparam FT_BIT_CTRL = 1'b0;       // FT系列地址位宽配置
localparam FT_ID_LIB_VERSION= 8'hA1; // 固件版本寄存器地址
localparam FT_DEVIDE_MODE = 8'h00;   // 模式控制寄存器
localparam FT_ID_MODE = 8'hA4;       // FT中断模式控制寄存器
localparam FT_ID_THGROUP = 8'h80;    // 触摸有效阈值寄存器
localparam FT_ID_PERIOD_ACT = 8'h88; // 激活周期配置寄存器
localparam FT_STATE_REG = 8'h02;     // 触摸状态寄存器
localparam FT_TP1_REG = 8'h03;       // 第一个触摸点数据起始地址
// GT系列触摸芯片参数
localparam GT_SLAVE_ADDR = 7'h14;    // GT系列从机地址
localparam GT_BIT_CTRL = 1'b1;       // GT系列地址位宽配置
localparam GT_STATE_REG = 16'h814E;  // GT触摸状态寄存器
localparam GT_TP1_REG = 16'h8150;    // GT第一个触摸点数据起始地址
// 状态定义
localparam st_idle          = 7'b000_0001;// 空闲状态
localparam st_init          = 7'b000_0010;// 上电初始化
localparam st_get_id        = 7'b000_0100;// 读取触摸芯片ID
localparam st_cfg_reg       = 7'b000_1000;// 配置触摸芯片寄存器
localparam st_check_touch   = 7'b001_0000;// 查询触摸状态
localparam st_get_coord     = 7'b010_0000;// 读取触摸点坐标
localparam st_coord_handle  = 7'b100_0000;// 坐标处理（不同芯片坐标格式转换）

//reg define
reg                 touch_int_dir; // INT双向口方向控制信号
reg                 touch_int_out; // INT端口输出值
reg    [6:0]        cur_state      ;  // 当前状态
reg    [6:0]        next_state     ;  // 下一状态
                                   
reg                 cnt_time_en    ;  // 定时器计数使能
reg    [19:0]       cnt_time       ;  // 延时计数器
reg    [15:0]       chip_version   ;  // 触摸芯片版本号
reg                 ft_flag        ;  // FT芯片标记：1=FT系列，0=GT系列
reg    [15:0]       touch_s_reg    ;  // 触摸状态寄存器缓存
reg    [15:0]       coord_reg      ;  // 坐标临时寄存器
reg    [15:0]       tp_x_coord_t   ;  // X方向触摸坐标临时缓存
reg    [15:0]       tp_y_coord_t   ;  // Y方向触摸坐标临时缓存
reg    [3:0]        flow_cnt       ;  // 流程步骤计数器
reg                 st_done        ;  // 本状态操作完成标志
reg    [15:0]       tp_x_coord     ;  // 最终有效X触摸坐标
reg    [15:0]       tp_y_coord     ;  // 最终有效Y触摸坐标
reg                 touch_valid    ;  // 触摸有效标志：0无触摸，1检测到触摸
reg                 touch_press_flag; // 本次按下是否已经处理过翻页，保证一次点击只翻一页
//wire define
wire          touch_int_in ;      // INT端口输入值
// 读到的原始坐标（FT芯片X/Y是颠倒的，和tp_x_coord做同样的转换）
wire [15:0] cur_x = ft_flag ? {4'd0,tp_y_coord_t[3:0],tp_y_coord_t[15:8]} : tp_x_coord_t;
wire [15:0] cur_y = ft_flag ? {4'd0,tp_x_coord_t[3:0],tp_x_coord_t[15:8]} : tp_y_coord_t;
// 判断当前触摸点是否落在翻页区域内
wire        cur_in_page = (cur_x >= PAGE_AREA_X_MIN) && (cur_x <= PAGE_AREA_X_MAX)
                        && (cur_y >= PAGE_AREA_Y_MIN) && (cur_y <= PAGE_AREA_Y_MAX);
// 双向口控制：dir=1输出，dir=0高阻输入
assign  touch_int  = touch_int_dir ? touch_int_out : 1'bz;
assign  touch_int_in = touch_int;
// 延时计数器逻辑
always@(posedge clk or negedge rst_n)begin  
    if(!rst_n)
        cnt_time <= 20'd0;
    else  if(cnt_time_en)
        cnt_time <= cnt_time + 20'd1;
    else
        cnt_time <= 20'd0;

end 

//触摸坐标数据锁存
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        data <= 32'd0;
    end 
    else if(touch_valid)
        data <= {tp_x_coord,tp_y_coord};
    else
        data <= data;
end 


//三段式状态机：状态寄存器时序逻辑
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;

end 
//状态跳转逻辑
always @(*) begin
    case(cur_state)
        st_idle : begin
            if(st_done)
                next_state = st_init;
            else 
                next_state = st_idle;
        end
        st_init : begin
            if(st_done)
                next_state = st_get_id; 
            else
                next_state = st_init;
        end
        st_get_id : begin
            if(st_done) begin
                if(ft_flag)  //仅FT系列需要配置寄存器
                    next_state = st_cfg_reg;
                else
                    next_state = st_check_touch;
            end
            else
                next_state = st_get_id;
        end       
        st_cfg_reg : begin
            if(st_done)
                next_state = st_check_touch;
            else
                next_state = st_cfg_reg;
        end
        st_check_touch: begin
            if(st_done)
                next_state = st_get_coord;
            else
                next_state = st_check_touch;
        end
        st_get_coord : begin
            if(st_done)
                next_state = st_coord_handle;
            else
                next_state = st_get_coord;
        end
        st_coord_handle : begin
            if(st_done)
                next_state = st_check_touch;
            else
                next_state = st_coord_handle;
        end
        default: next_state = st_idle;
    endcase
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
         cnt_time_en  <= 1'b0;
        chip_version <= 16'd0;
        ft_flag      <= 1'b0;
        touch_s_reg  <= 16'd0;
        coord_reg    <= 16'd0;
        tp_x_coord_t <= 16'd0;
        tp_y_coord_t <= 16'd0;
        flow_cnt     <= 4'd0;
        st_done      <= 1'b0;
        touch_int_dir<= 1'b0;
        touch_int_out<= 1'b0;
        
        slave_addr   <= 7'd0;
        i2c_exec     <= 1'b0;
        i2c_rh_wl    <= 1'b0;
        i2c_addr     <= 16'd0;
        i2c_data_w   <= 8'd0;
        bit_ctrl     <= 1'b0;
        reg_num      <= 8'd0;
        
        touch_valid  <= 1'b0;
        tp_x_coord   <= 16'd0;
        tp_y_coord   <= 16'd0;
        touch_rst_n  <= 1'b0;    
        
        page            <= 1'b0;
        touch_press_flag <= 1'b0;
    end 
    else begin
        i2c_exec <= 1'b0;
        st_done <= 1'b0;
        if(!touch_valid)
            touch_press_flag <= 1'b0;   //手指抬起，允许下一次翻页
        case(next_state)
            st_idle :begin
                cnt_time_en  <= 1'b1;
                touch_int_dir <= 1'b1;
                touch_int_out <= 1'b1;
                if(cnt_time >= 10)begin
                    st_done <= 1'b1;
                    cnt_time_en <= 1'b0;
                
                end 
            
            end 
            st_init:begin
                cnt_time_en <= 1'b1;
                if(cnt_time < DELAY_TIME_10MS)  //延时10ms
                    touch_rst_n <= 1'b0; //开始复位
                else if(cnt_time == DELAY_TIME_10MS) 
                    touch_rst_n <= 1'b1; //结束复位
                else if(cnt_time == DELAY_TIME_50MS)begin //再次延时50ms（60_000 - 10_000）
                    touch_int_dir <= 1'b0;      //将INT引脚设置位浮空输入
                    cnt_time_en <= 1'b0;
                    st_done <= 1'b1;
                    flow_cnt <= 4'd0;
                
                end 
            
            end 
            st_get_id :begin
                case(flow_cnt)
                    'd0:begin
                        //根据屏幕ID，判断这几款屏幕是GT系列
                        if(lcd_id == 16'h4384 || lcd_id == 16'h4342 || 
                        lcd_id == 16'h1018) begin
                            flow_cnt <= 4'd5;//GT系列芯片不需要配置寄存器
                            ft_flag <= 1'b0; //ft_flag=0,说明触摸芯片为GT系列
                        end 
                        else
                            flow_cnt <= flow_cnt + 4'd1;
                    end 
                    'd1:begin //读FT系列版本号
                        i2c_exec <= 1'b1;
                        i2c_rh_wl <= 1'b1;
                        i2c_addr <= FT_ID_LIB_VERSION;
                        reg_num <= 8'd2;
                        slave_addr <= FT_SLAVE_ADDR;
                        bit_ctrl <=FT_BIT_CTRL;
                        flow_cnt <= flow_cnt +4'd1;
                    end 
                    'd2:begin
                        if(once_byte_done)begin
                            chip_version[15:8] <= i2c_data_r;
                            flow_cnt <= flow_cnt + 4'd1;
                        end 
                        else if(i2c_done && i2c_ack)begin
                            chip_version <= "GT"; //16'h4754
                            flow_cnt <= 4'd4;
                        end 
                    end 
                    'd3:begin
                        if(i2c_done)begin
                            chip_version[7:0] <= i2c_data_r;
                            flow_cnt <= flow_cnt + 4'd1;
                        
                        end 
                    
                    end 
                    'd4:begin
                        flow_cnt <= flow_cnt +4'd1;
                        //FT系列版本:0X3003/0X0001/0X0002/CST340
                        if(chip_version == 16'h3003 || chip_version == 16'h0001
                        || chip_version == 16'h0002 || chip_version == 16'h0000)
                            ft_flag <= 1'b1;         //ft_flag=1,说明触摸芯片为FT系列
                        else 
                            ft_flag <= 1'b0;         //ft_flag=0,说明触摸芯片为GT系列
                    end 
                    'd5:begin //根据对应系列配置参数
                        st_done <= 1'b1;
                        flow_cnt <= 'd0;
                        if(ft_flag) begin                 //将参数配置为FT系列
                            touch_s_reg <= FT_STATE_REG;  //触摸状态寄存器（0X02）
                            coord_reg   <= FT_TP1_REG;    //第一个触摸点数据地址
                            bit_ctrl    <= FT_BIT_CTRL;   //FT系列位控制
                            slave_addr  <= FT_SLAVE_ADDR; //FT系列器件地址
                        end
                        else begin                        //将参数配置为GT系列
                            touch_s_reg <= GT_STATE_REG;  //状态寄存器（0X814E）
                            coord_reg   <= GT_TP1_REG;    //第一个触摸点数据地址
                            bit_ctrl    <= GT_BIT_CTRL;   //GT系列位控制
                            slave_addr  <= GT_SLAVE_ADDR; //GT系列器件地址
                        end
                    end 
                    default:;
                endcase            
            end 
            st_cfg_reg:begin
                case(flow_cnt)
                    'd0:begin
                        i2c_exec   <= 1'b1;
                        i2c_rh_wl  <= 1'b0;
                        i2c_addr   <= FT_DEVIDE_MODE;//工作模式寄存器（0X00）
                        i2c_data_w <= 8'd0;          //进入正常模式
                        reg_num    <= 8'd1;
                        flow_cnt   <= flow_cnt + 4'd1;
                    
                    end 
                    'd1 : begin
                        if(i2c_done) begin
                            if(i2c_ack == 1'b0)      //I2C应答
                                flow_cnt <= flow_cnt + 4'd1;
                            else                     //I2C未应答
                                flow_cnt <= flow_cnt - 4'd1;
                        end
                    end
                    'd2:begin
                        i2c_exec <= 1'b1;
                        i2c_rh_wl <= 1'b0;
                        i2c_addr <= FT_ID_MODE;      //中断状态控制寄存器（0XA4）
                        i2c_data_w <= 8'd0;            //查询模式
                        reg_num <= 8'd1;
                        flow_cnt <= flow_cnt +4'd1;
                    end 
                    'd3:begin
                        if(i2c_done) begin
                            if(i2c_ack == 1'b0)      //I2C应答
                                flow_cnt <= flow_cnt + 4'd1;
                            else                     //I2C未应答
                                flow_cnt <= flow_cnt - 4'd1;
                        end
                    
                    end 
                    'd4:begin
                        i2c_exec <= 1'b1;
                        i2c_rh_wl <= 1'b0;
                        i2c_addr <= FT_ID_THGROUP; //有效触摸门限控制寄存器（0X80）
                        i2c_data_w <= 8'd22;        //设置触摸有效值,值越小,越灵敏
                        reg_num <= 8'd1;
                        flow_cnt <= flow_cnt + 4'd1;
                    
                    end 
                    'd5: begin 
                        if(i2c_done) begin
                            if(i2c_ack == 1'b0)      //I2C应答
                                flow_cnt <= flow_cnt + 4'd1;
                            else                     //I2C未应答
                                flow_cnt <= flow_cnt - 4'd1;
                        end
                    end 
                    'd6 :begin
                        i2c_exec <= 1'b1;
                        i2c_rh_wl <= 1'b0;
                        i2c_addr <= FT_ID_PERIOD_ACT; //激活周期控制寄存器（0X88）
                        i2c_data_w <= 8'd12;          //激活周期
                        reg_num <= 8'd1;
                        flow_cnt <= flow_cnt +4'd1;
                    
                    end 
                    'd7 : begin
                        if(i2c_done) begin
                            if(i2c_ack == 1'b0) begin//I2C应答
                                flow_cnt <= 4'd0;
                                st_done  <= 1'b1;
                            end    
                            else                     //I2C未应答
                                flow_cnt <= flow_cnt - 4'd1;
                        end
                    end
                    default : ;                    
                endcase            
            end 
            st_check_touch:begin
                case(flow_cnt)
                    'd0:begin //延时
                        cnt_time_en <= 1'b1;
                        if(cnt_time == DELAY_TIME_10MS *2 )begin
                            flow_cnt <= flow_cnt +4'd1;
                            cnt_time_en <= 1'b0;
                        end 
                    
                    end 
                    'd1:begin
                        i2c_exec  <= 1'b1;
                        i2c_rh_wl <= 1'b1;
                        i2c_addr  <= touch_s_reg;     //读取触摸点状态
                        reg_num   <= 8'd1;
                        flow_cnt  <= flow_cnt + 4'd1;  
                    end 
                    'd2:begin
                        if(i2c_done) begin
                            if(i2c_ack == 1'b0)
                                flow_cnt <= flow_cnt + 4'd1;
                            else
                                flow_cnt <= flow_cnt - 4'd1;
                        end
                    
                    end 
                    'd3:begin  //读状态寄存器（0X814E），最低4位用于表示有效触点的个数，范围是：0~5，0表示没有触摸，5表示有5点触摸
                        flow_cnt <= flow_cnt +4'd1;
                        if(ft_flag)begin
                            if(i2c_data_r[3:0] > 4'd0 && i2c_data_r[3:0] <= 4'd5)
                                touch_valid <= 1'b1;//检测到触摸 
                            else
                                touch_valid <= 1'b0;//未检测到触摸
                        end 
                        else begin
                            if(i2c_data_r[7] == 1'b1 && i2c_data_r[3:0] > 4'd0
                            && i2c_data_r[3:0] <= 4'd5)begin
                                touch_valid <= 1'b1; //检测到触摸 
                            
                            end 
                            else 
                                touch_valid <= 1'b0; //未检测到触摸
                        end 
                    
                    end 
                    'd4:begin
                        i2c_exec   <= 1'b1;
                        i2c_rh_wl  <= 1'b0;
                        i2c_addr   <= touch_s_reg;
                        i2c_data_w <= 8'd0;          //清除触摸标志
                        reg_num    <= 8'd1;
                        flow_cnt   <= flow_cnt + 4'd1;
                    
                    end 
                    'd5 : begin
                        if(i2c_done) begin
                            if(i2c_ack == 1'b0) begin
                                st_done  <= touch_valid;
                                flow_cnt <= 4'd0;
                            end
                            else
                                flow_cnt <= flow_cnt - 4'd1;
                        end
                    end
                    default : ;
                endcase
            end 
            st_get_coord:begin
                case(flow_cnt)
                    'd0:begin
                        i2c_exec <= 1'b1;
                        i2c_rh_wl<= 1'b1;
                        i2c_addr <= coord_reg;       //获取X和Y方向坐标点
                        reg_num <= 8'd4;
                        flow_cnt <= flow_cnt + 4'd1;
                    
                    end 
                    'd1:begin
                        if(once_byte_done)begin
                            if(!i2c_ack )begin
                                tp_x_coord_t[7:0] <= i2c_data_r;
                                flow_cnt <= flow_cnt +4'd1;
                            
                            end 
                            else
                                flow_cnt <= 4'd0;
                        end 
                        end
                    'd2:begin
                        if(once_byte_done)begin
                            flow_cnt <= flow_cnt + 4'd1;
                            tp_x_coord_t[15:8] <= i2c_data_r;
                        
                        end 

                    end         
                    'd3:begin
                        if(once_byte_done)begin
                            flow_cnt <= flow_cnt + 4'd1;
                            tp_y_coord_t[7:0] <= i2c_data_r;
                        end 
                    end 
                    'd4:begin
                        if(once_byte_done)begin
                            st_done <= 1'b1;
                            flow_cnt <= 4'd0;
                            tp_y_coord_t[15:8] <= i2c_data_r;
                        end 
                    
                    end 
                    default:;
                endcase
            end 
            st_coord_handle:begin
                st_done <= 1'b1;
                if(ft_flag) begin                    //FT系列需对数据做处理
                    tp_x_coord <= {4'd0,tp_y_coord_t[3:0],tp_y_coord_t[15:8]};
                    tp_y_coord <= {4'd0,tp_x_coord_t[3:0],tp_x_coord_t[15:8]};
                    
                end
                else begin
                    tp_x_coord <= tp_x_coord_t;
                    tp_y_coord <= tp_y_coord_t;
                end
                //翻页：用本次刚读到的坐标(cur_x/cur_y)判断是否点在按钮区域内，
                //一次按下只翻一页（touch_press_flag 在松手时清除）
                if(!touch_press_flag && cur_in_page) begin
                    page             <= ~page;
                    touch_press_flag <= 1'b1;
                end
            end 
            default:;
        endcase
    
    end 
     
end 
                                                                 
endmodule                                                 
                                                            
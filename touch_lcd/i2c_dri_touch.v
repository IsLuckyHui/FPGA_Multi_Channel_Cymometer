//触摸屏
module  i2c_dri_touch#(
    parameter   CLK_FREQ = 26'd50_000_000   ,//输入时钟50MHz
    parameter   I2C_FREQ = 18'd250_000      ,//目标 SCL 频率 250kHz
    parameter   WIDTH = 4'd8                 //一次读写寄存器的个数的位宽  
)(
    input      clk                          , //i2c_dri模块的驱动时钟
    input      rst_n                        , //复位信号
    
    //i2c 接口
    input         [6:0]       slave_addr    , //器件地址
    input                     i2c_exec      , //I2C触发执行信号
    input                     i2c_rh_wl     , //I2C读写控制位
    input         [15:0]      i2c_addr      , //I2C的字地址
    input         [7:0]       i2c_data_w    , //I2C的要写入的数据
    input                     bit_ctrl      , //bit控制位 高代表I2C的字地址为16位  低代表I2C的字地址为八位
    input         [WIDTH-1:0] reg_num       , //一次读写完寄存器的个数
    
    output   reg  [7:0]       i2c_data_r    , //读出的I2C的数据
    output   reg              i2c_done      , //I2C操作完成
    output   reg              once_byte_done, //一字节数据读/写操作完成
    output   reg              scl           , //I2C的时钟
    output   reg              i2c_ack           , //应答信号
    inout                     sda           , //I2C的数据线
                              
    output   reg              dri_clk         //驱动I2C操作的驱动时钟  1MHZ 对应SCL是250KHz


);
//localparam define
localparam st_idle    = 8'b0000_0001;
localparam st_sladdr  = 8'b0000_0010;
localparam st_addr16  = 8'b0000_0100;
localparam st_addr8   = 8'b0000_1000;
localparam st_data_wr = 8'b0001_0000;
localparam st_addr_rd = 8'b0010_0000;
localparam st_data_rd = 8'b0100_0000;
localparam st_stop    = 8'b1000_0000;

//reg define
reg   sda_dir   ;//sda的控制方向 拉高代表sda输出 拉低代表输入
reg   sda_out   ;//sda输出
reg   st_done   ;//状态结束
reg   wr_flag   ;//写标志

reg  [6:0]           cnt;//计数器
reg  [7:0]           cur_state;
reg  [7:0]           next_state;
reg  [15:0]          addr_t;//地址寄存器
reg  [7:0]           data_r;//数据寄存器
reg  [ 7:0]            data_wr_t   ; //I2C需写的数据的临时寄存
reg  [9:0]           clk_cnt;//分频时钟计数 
reg  [WIDTH- 1'b1:0] reg_cnt;//一次读写寄存器的个数的寄存器

//wire define
wire       sda_in; //sda输入
wire [8:0] clk_divide;//模拟驱动时钟的分频系数
wire       reg_done; //读寄存器完成 （0：继续读 1：读寄存器完成）

assign  sda = sda_dir ? sda_out : 1'bz;
assign  sda_in = sda;
//assign clk_divide =( CLK_FREQ /I2C_FREQ) >> 2'd3;
assign clk_divide =( CLK_FREQ /I2C_FREQ) >> 2'd2;
assign reg_done = reg_cnt == reg_num ? 1'b1 : 1'b0;


//生成I2C的SCL的四倍频率的驱动时钟用于驱动I2C的操作
always@(posedge clk or negedge rst_n)begin  
    if(!rst_n)begin
        dri_clk <= 1'b0;
        clk_cnt <= 10'd0;
    
    end 
    else  if(clk_cnt == clk_divide - 10'd1)begin
        clk_cnt <= 10'd0;
        dri_clk <= ~dri_clk;
    
    end 
    else
         clk_cnt <= clk_cnt + 10'd1;

end 

//连续读写寄存器的的个数计数
always@(posedge dri_clk or negedge rst_n)begin
    if(!rst_n)
        reg_cnt <= 8'd0;
    else if(once_byte_done)
        reg_cnt <= reg_cnt +8'd1;
    else if(i2c_done)   
        reg_cnt <= 8'd0;
    else
        reg_cnt <= reg_cnt;

end 

//三段式状态机
always@(posedge dri_clk or negedge rst_n )begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;
end 

//组合逻辑判断状态转移条件
always @( * ) begin
    case(cur_state)
        st_idle: begin                            //空闲状态
           if(i2c_exec) begin
               next_state = st_sladdr;
           end
           else
               next_state = st_idle;
        end
        st_sladdr: begin
            if(st_done) begin
                if(!i2c_ack) begin
                    if(bit_ctrl)                  //判断是16位还是8位字地址
                        next_state = st_addr16;
                    else
                        next_state = st_addr8 ;
                end
                else 
                    next_state = st_stop;    
            end
            else
                next_state = st_sladdr;
        end
        st_addr16: begin                          //写16位字地址
            if(st_done) begin
                if(!i2c_ack) 
                    next_state = st_addr8;
                else 
                    next_state = st_stop;   
            end
            else
                next_state = st_addr16;
        end
        st_addr8: begin                           //8位字地址
            if(st_done) begin
                if(!i2c_ack) begin
                    if(wr_flag==1'b0)             //读写判断
                        next_state = st_data_wr;
                    else
                        next_state = st_addr_rd;
                end
                else 
                    next_state = st_stop;   
            end
            else
                next_state = st_addr8;
        end
        st_data_wr: begin                          //写数据(8 bit)
            if(st_done) begin
                if(reg_done)
                    next_state = st_stop;
                else
                    next_state = st_data_wr;
            end
            else
                next_state = st_data_wr;
        end
        st_addr_rd: begin                          //写地址以进行读数据
            if(st_done) begin
                if(!i2c_ack)
                    next_state = st_data_rd;
                else
                    next_state = st_stop;
            end
            else
                next_state = st_addr_rd;
        end
        st_data_rd: begin                          //读取数据(8 bit)
            if(st_done) begin
                if(reg_done)
                    next_state = st_stop;
                else
                    next_state = st_data_rd;
            end
            else
                next_state = st_data_rd;
        end
        st_stop: begin                             //结束I2C操作
            if(st_done)
                next_state = st_idle;
            else
                next_state = st_stop ;
        end
        default: next_state= st_idle;
    endcase
end

always@(posedge dri_clk or negedge rst_n)begin
    if(!rst_n)begin
        scl             <= 1'b1;
        sda_out         <= 1'b1;
        sda_dir         <= 1'b1;
        i2c_done        <= 1'b0;
        i2c_ack             <= 1'b0;
        cnt             <= 7'd0;
        st_done         <= 1'b0;
        once_byte_done  <= 1'b0;
        data_r          <= 8'd0;
        i2c_data_r      <= 8'd0;
        wr_flag         <= 1'b0;
        addr_t          <= 16'd0;
        data_wr_t       <= 8'd0;
        end 
    else begin
        st_done <= 1'b0;
        once_byte_done <= 1'b0;
        cnt <= cnt +7'd1;
        case(cur_state)
            st_idle:begin //空闲状态
                scl <= 1'b1;
                sda_out <= 1'b1;
                sda_dir <= 1'b1;
                i2c_done <= 1'b0;
                cnt <= 7'b0;
                
                if(i2c_exec)begin //当操作信号发送过来
                    wr_flag <= i2c_rh_wl ;
                    addr_t <=i2c_addr;
                    data_wr_t <= i2c_data_w;                
                end 

            end 
            st_sladdr:begin //写地址
                case(cnt)
                    7'd1 :begin
                        sda_dir <= 1'b1; //发送起始信号
                        sda_out <= 1'b0;
                    end 
                    7'd3:scl <= 1'b0;
                    7'd4:sda_out <= slave_addr[6];
                    7'd5:scl <= 1'b1;
                    
                    7'd7:scl <= 1'b0;
                    7'd8:sda_out <= slave_addr[5];
                    7'd9:scl <= 1'b1;
                    
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= slave_addr[4];
                    7'd13: scl <= 1'b1;
                    
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= slave_addr[3];
                    7'd17: scl <= 1'b1;
                    
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= slave_addr[2];
                    7'd21: scl <= 1'b1;
                    
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= slave_addr[1];
                    7'd25: scl <= 1'b1;
                    
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= slave_addr[0];
                    7'd29: scl <= 1'b1;
                    
                    7'd31: scl <= 1'b0;
                    7'd32: sda_out <= 1'b0;              //0:写
                    7'd33: scl <= 1'b1;
                    
                    7'd35: scl <= 1'b0;
                    7'd36: begin
                        sda_dir <= 1'b0;                 //从机应答
                        sda_out <= 1'b1;
                    end
                    7'd37: begin 
                        scl <= 1'b1; 
                        i2c_ack <= sda_in;
                    end
                    7'd42: st_done <= 1'b1;
                    7'd43:begin
                        scl <= 1'b0;
                        cnt <= 7'd0;
                    end 
                    default :;
                endcase
            end 
            st_addr16 :begin
                case(cnt)
                    7'd0 : begin
                        sda_dir <= 1'b1 ;
                        sda_out <= addr_t[15];           //传送字地址
                    end
                    7'd1 : scl <= 1'b1;
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= addr_t[14];
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= addr_t[13];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= addr_t[12];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= addr_t[11];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= addr_t[10];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= addr_t[9];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= addr_t[8];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: begin
                        sda_dir <= 1'b0;                 //从机应答
                        sda_out <= 1'b1;
                    end
                    7'd33:  begin 
                        scl <= 1'b1; 
                        i2c_ack <= sda_in;
                    end
                    7'd38: st_done <= 1'b1;
                    7'd39: begin //7'd35
                        scl <= 1'b0;
                        cnt <= 7'd0;
                    end
                    default :  ;
                endcase
            end 
            st_addr8: begin
                case(cnt)
                    7'd0: begin
                       sda_dir <= 1'b1 ;
                       sda_out <= addr_t[7];            //字地址
                    end
                    7'd1 : scl <= 1'b1;
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= addr_t[6];
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= addr_t[5];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= addr_t[4];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= addr_t[3];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= addr_t[2];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= addr_t[1];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= addr_t[0];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: begin
                        sda_dir <= 1'b0;                //从机应答
                        sda_out <= 1'b1;
                    end
                    7'd33:  begin 
                        scl <= 1'b1; 
                        i2c_ack <= sda_in;
                    end
                    7'd38: st_done <= 1'b1;
                    7'd39: begin //7'd35
                        scl <= 1'b0;
                        cnt <= 7'd0;
                    end
                    default :  ;
                endcase
            end
            st_data_wr: begin                            //写数据(8 bit)
                case(cnt)
                    7'd0: begin
                        sda_out <= i2c_data_w[7];        //I2C写8位数据
                        data_wr_t <= i2c_data_w;
                        sda_dir <= 1'b1;
                    end
                    7'd1 : scl <= 1'b1;
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= data_wr_t[6];
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= data_wr_t[5];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= data_wr_t[4];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= data_wr_t[3];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= data_wr_t[2];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= data_wr_t[1];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= data_wr_t[0];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: begin
                        sda_dir        <= 1'b0;          //从机应答
                        sda_out        <= 1'b1;
                        once_byte_done <= 1'b1;
                    end
                    7'd33:  begin 
                        scl <= 1'b1; 
                        i2c_ack <= sda_in;
                    end
                    7'd38: st_done <= 1'b1;
                    7'd39: begin //7'd35
                        scl  <= 1'b0;
                        cnt  <= 7'd0;
                    end
                    default  :  ;
                endcase
            end
            st_addr_rd: begin                           //写地址以进行读数据
                case(cnt)
                    7'd0 : begin
                        sda_dir <= 1'b1;
                        sda_out <= 1'b1;
                    end
                    7'd1 : scl <= 1'b1;
                    7'd2 : sda_out <= 1'b0;             //重新开始
                    7'd3 : scl <= 1'b0;
                    7'd4 : sda_out <= slave_addr[6];    //传送器件地址
                    7'd5 : scl <= 1'b1;
                    7'd7 : scl <= 1'b0;
                    7'd8 : sda_out <= slave_addr[5];
                    7'd9 : scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd12: sda_out <= slave_addr[4];
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd16: sda_out <= slave_addr[3];
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd20: sda_out <= slave_addr[2];
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd24: sda_out <= slave_addr[1];
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd28: sda_out <= slave_addr[0];
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd32: sda_out <= 1'b1;             //1:读
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd36: begin
                        sda_dir <= 1'b0;                //从机应答
                        sda_out <= 1'b1;
                    end
                    7'd37:  begin 
                        scl <= 1'b1; 
                        i2c_ack <= sda_in;
                    end
                    7'd42: st_done <= 1'b1;
                    7'd43: begin //7'd39
                        scl <= 1'b0;
                        cnt <= 7'd0;
                    end
                    default : ;
                endcase
            end
            st_data_rd: begin                          //读取数据(8 bit)
                case(cnt)
                    7'd0: sda_dir <= 1'b0;
                    7'd1: begin
                        data_r[7] <= sda_in;
                        scl       <= 1'b1;
                    end
                    7'd3: scl  <= 1'b0;
                    7'd5: begin
                        data_r[6] <= sda_in ;
                        scl       <= 1'b1   ;
                    end
                    7'd7: scl  <= 1'b0;
                    7'd9: begin
                        data_r[5] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd11: scl  <= 1'b0;
                    7'd13: begin
                        data_r[4] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd15: scl  <= 1'b0;
                    7'd17: begin
                        data_r[3] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd19: scl  <= 1'b0;
                    7'd21: begin
                        data_r[2] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd23: scl  <= 1'b0;
                    7'd25: begin
                        data_r[1] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd27: scl  <= 1'b0;
                    7'd29: begin
                        data_r[0] <= sda_in;
                        scl       <= 1'b1  ;
                    end
                    7'd31: scl  <= 1'b0;
                    7'd32: begin                       
                        if(reg_cnt == reg_num - 1'b1) begin
                            sda_dir <= 1'b1;          //非应答
                            sda_out <= 1'b1;
                        end
                        else begin
                            sda_dir <= 1'b1;          //应答
                            sda_out <= 1'b0;
                        end
                    end
                    7'd33: begin
                        scl             <= 1'b1;
                        once_byte_done  <= 1'b1;
                        i2c_data_r      <= data_r;
                    end
                    7'd38: st_done <= 1'b1;
                    7'd39: begin  //7'd35
                        scl <= 1'b0;
                        cnt <= 7'd0;    
                    end
                    default  :  ;
                endcase
            end
            st_stop: begin                            //结束I2C操作
                case(cnt)
                    7'd0: begin
                        sda_dir <= 1'b1;              //结束I2C
                        sda_out <= 1'b0;
                    end
                    7'd1: scl     <= 1'b1;
                    7'd3: sda_out <= 1'b1;
                    7'd5: st_done <= 1'b1;
                    7'd6: begin
                        cnt      <= 7'd0;
                        i2c_done <= 1'b1;             //向上层模块传递I2C结束信号
                    end
                    default  : ;
                endcase
            end
        endcase
    
    end 
end 


endmodule 
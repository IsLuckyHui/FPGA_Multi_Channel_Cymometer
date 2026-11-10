module binary2bcd(
    input             sys_clk   ,
    input             sys_rst_n ,
    input      [29:0] data      ,
    output reg [35:0] bcd_data    //9位BCD值
);
//parameter define 
parameter  CNT_SHIFT_NUM = 7'd30; //由data 的位宽决定这里是30
//reg define
reg [6:0]  cnt_shift ;            //移位判断计数器该值由data的位宽决定这里是7
reg [65:0] data_shift;            //移位判断数据寄存器，由data和bcddata的位宽之和决定  
reg        shift_flag;            //移位判断标志信号

//cnt_shift计数
always@(posedge sys_clk or negedge sys_rst_n)begin  
    if(!sys_rst_n)
        cnt_shift <= 7'd0;
    else  if((cnt_shift == CNT_SHIFT_NUM + 7'd1) && (shift_flag))    
        cnt_shift <= 7'd0;
    else  if(shift_flag)  
        cnt_shift <= cnt_shift + 7'd1;
    else
        cnt_shift <= cnt_shift;
end 

//shift_flag 移位判断标志信号，用于控制移位判断的先后顺序
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        shift_flag <= 1'b0;
    else
        shift_flag <= ~shift_flag;

end  


//data_shift 计数器为0时赋初值，计数器为1~CNT_SHIFT_NUM时进行移位操作
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        data_shift <= 66'd0;
    else if(cnt_shift <= 7'd0)
        data_shift <= {36'd0,data};
        //左移的次数等于输入的数据的位宽 
    else if((cnt_shift <= CNT_SHIFT_NUM)&&(!shift_flag))begin
        data_shift[33:30] <= (data_shift[33:30] > 4) ? (data_shift[33:30] + 2'd3):(data_shift[33:30]);
        data_shift[37:34] <= (data_shift[37:34] > 4) ? (data_shift[37:34] + 2'd3):(data_shift[37:34]);
        data_shift[41:38] <= (data_shift[41:38] > 4) ? (data_shift[41:38] + 2'd3):(data_shift[41:38]);
        data_shift[45:42] <= (data_shift[45:42] > 4) ? (data_shift[45:42] + 2'd3):(data_shift[45:42]);
        data_shift[49:46] <= (data_shift[49:46] > 4) ? (data_shift[49:46] + 2'd3):(data_shift[49:46]);
        data_shift[53:50] <= (data_shift[53:50] > 4) ? (data_shift[53:50] + 2'd3):(data_shift[53:50]);
        data_shift[57:54] <= (data_shift[57:54] > 4) ? (data_shift[57:54] + 2'd3):(data_shift[57:54]);
        data_shift[61:58] <= (data_shift[61:58] > 4) ? (data_shift[61:58] + 2'd3):(data_shift[61:58]);
        data_shift[65:62] <= (data_shift[65:62] > 4) ? (data_shift[65:62] + 2'd3):(data_shift[65:62]);
        end
    else if((cnt_shift <= CNT_SHIFT_NUM)&&(shift_flag))
        data_shift <= data_shift << 1;
    else
        data_shift <= data_shift;
end 
//当cnt_shift 计数到最大值的时候  输出bcd码
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        bcd_data <= 36'd0;
    else if(cnt_shift == CNT_SHIFT_NUM +36'd1)
        bcd_data <= data_shift[65:30];
    else
        bcd_data <= bcd_data ;

end 


endmodule
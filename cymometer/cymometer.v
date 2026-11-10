module cymometer(
    input              sys_clk  , 
    input              sys_rst_n,
    input              clk_fs   ,//基准时钟
    input              clk_fx   ,//被测时钟
    
    output  reg [29:0] data_fx  ,//被测时钟的频率值
    
    input              ready    ,//值可被接受 拉高代表除法器忙 无法接收新的数据
    input       [56:0] quotient ,//商
    input       [56:0] remainder,//余数
    input              vld_out  ,//值有效 商和余数有效使能
    
    
    output  reg [56:0] dividend ,//被除数
    output  reg [56:0] divisor  ,//除数
    output  reg        en        //进行除法运算标志   
);
//parameter define
parameter   CNT_GATE_MAX = 28'd75_000_000; //测频周期时间为1.5s
parameter   CNT_TIME_MAX = 28'd100_000_000;//清零周期时间为2s
parameter   CNT_GATE_LOW = 28'd12_500_000 ;//闸门为低的时间0.25s
parameter   CLK_FS_FREQ  = 28'd100_100_100;
parameter   TIME = 150;//数据稳定时间
//reg define
reg         gate_sclk       ;//软件闸门 由系统时钟产生
reg  [27:0] cnt_gate_fs     ;//软件闸门的时间计数器
reg         gate_fx         ;//被测闸门
reg         gate_fx_d0      ;
reg         gate_fx_d1      ;
reg         gate_fx_d2      ;
reg         gate_fx_d3      ;
reg         gate_fs         ;//基准时钟闸门
reg         gate_fs_d0      ;
reg         gate_fs_d1      ;
reg  [29:0] cnt_fx          ;//被测闸门内的时钟计数
reg  [29:0] cnt_fx_reg      ;//被测闸门的时钟计数到达最大值的寄存
reg  [29:0] cnt_fs          ;//基准闸门内的时钟计数
reg  [29:0] cnt_fs_reg      ;//基准闸门内的时钟计数到达最大值的寄存
reg  [29:0] cnt_fs_reg_reg  ;//分母
reg         calc_flag       ;//计算标志 拉高时将分子和分母的值输出到除法器
reg  [56:0] numer           ;//分子
reg         fx_flag         ;
reg  [56:0] numer_reg       ;
reg  [27:0] cnt_delay       ;//清零计数器
reg         flag_delay      ;//清零标志
//wire define
wire        gate_fx_pose    ;//被测闸门上升沿
wire        gate_fx_nege    ;//被测闸门下降沿
wire        gate_fs_nege    ;//基准闸门下降沿


// 计算公式 CLK_FX_FREQ = cnt_fx*CLK_FS_FREQ/cnt_fs
assign gate_fx_pose = ((gate_fx) && (!gate_fx_d3))? 1'b1 : 1'b0;
assign gate_fx_nege = ((!gate_fx_d2) && (gate_fx_d3))? 1'b1 : 1'b0;
assign gate_fs_nege = ((!gate_fs_d0) && (gate_fs_d1))? 1'b1 : 1'b0;

//产生软件闸门时间计数器 cnt_gate_fs 1.5s
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        cnt_gate_fs <= 28'd0;
    else   if(cnt_gate_fs >= CNT_GATE_MAX -28'd1)
        cnt_gate_fs <= 28'd0;
    else
        cnt_gate_fs <= cnt_gate_fs + 28'd1;
end 
//产生软件闸门
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        gate_sclk <= 1'b0;
    else if(cnt_gate_fs == CNT_GATE_LOW -28'd1)
        gate_sclk <= 1'b1;
    else if(cnt_gate_fs == CNT_GATE_MAX - CNT_GATE_LOW -28'd1)
        gate_sclk <= 1'b0;
    else
        gate_sclk <= gate_sclk ;
end 

//将软件闸门同步到被测时钟下得到实际闸门,并进行打拍获取上升沿和下降沿
always@(posedge clk_fx or negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        gate_fx        <= 1'd0;
        gate_fx_d0     <= 1'd0;
        gate_fx_d1     <= 1'd0;
        gate_fx_d2     <= 1'd0;
        gate_fx_d3     <= 1'd0;
    end 
    else begin
        gate_fx        <= gate_sclk;
        gate_fx_d0     <= gate_fx    ;
        gate_fx_d1     <= gate_fx_d0 ;
        gate_fx_d2     <= gate_fx_d1 ;
        gate_fx_d3     <= gate_fx_d2 ;
    
    end 
end 

// 获取实际闸门的下降沿 在基准时钟下获取下降沿
always@(posedge clk_fs or negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        gate_fs       <= 1'd0;
        gate_fs_d0    <= 1'd0;
        gate_fs_d1    <= 1'd0;
    
    end 
    else begin
        gate_fs       <= gate_fx_d2 ;
        gate_fs_d0    <= gate_fs    ;
        gate_fs_d1    <= gate_fs_d0 ;  
    end 

end 

//在被测时钟下计数cnt_fx
always@(posedge clk_fx or  negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        cnt_fx <=  30'd0;
    
    end 
    else if(gate_fx_d2)
        cnt_fx <=  cnt_fx + 30'd1;
    else if(!gate_fx_d2)
        cnt_fx <=  30'd0;
    else
        cnt_fx <= cnt_fx;

end 

//在被测闸门下降沿的时候缓存cnt_fx
always@(posedge clk_fx or negedge sys_rst_n)begin
    if(!sys_rst_n)
        cnt_fx_reg <= 30'd0;
    else if(gate_fx_nege)
        cnt_fx_reg <= cnt_fx;
    else
        cnt_fx_reg <= cnt_fx_reg ;
end 


//在基准时钟下计数cnt_fs
always@(posedge clk_fs or negedge sys_rst_n)begin
    if(!sys_rst_n)
        cnt_fs <= 30'd0;
    else if(gate_fs_d0) //这里不确定
  //  else if(gate_fx)
        cnt_fs <= cnt_fs + 30'd1;
    else if(gate_fs_nege)
        cnt_fs <= 30'd0;
    else
        cnt_fs <= cnt_fs;
end 
//在下降沿将基准时钟的时钟周期数进行缓存
always@(posedge clk_fs or negedge sys_rst_n)begin
    if(!sys_rst_n)
        cnt_fs_reg <= 30'd0;
    else if(gate_fs_nege)
        cnt_fs_reg <= cnt_fs;
    else
        cnt_fs_reg <= cnt_fs_reg;

end 

// CLK_FX_FREQ = cnt_fx*CLK_FS_FREQ/cnt_fs】
// 先计算得到分子 cnt_fx*CLK_FS_FREQ
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        numer <= 57'd0;
        //如果软件闸门的计数器等于1.5 - 0.25 +稳定时间 开始计算分子
    else if(cnt_gate_fs == CNT_GATE_MAX - CNT_GATE_LOW +TIME)
        numer <= cnt_fx_reg *CLK_FS_FREQ;
    else
        numer <= numer ;

end 
// 打一拍对计算得到的值 numer_reg(分子) 进行同步并寄存
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        numer_reg <= 57'd0;
    else if(cnt_gate_fs == (CNT_GATE_MAX - (CNT_GATE_LOW / 2) - TIME))
        numer_reg <= numer;
    else
        numer_reg <= numer_reg;

end  

// 打一拍对计算得到的值 cnt_fs_reg_reg(分母) 进行同步并寄存
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        cnt_fs_reg_reg <= 30'd0;
    else if(cnt_gate_fs == (CNT_GATE_MAX - (CNT_GATE_LOW / 2) - TIME) )
        cnt_fs_reg_reg <= cnt_fs_reg;
    else
        cnt_fs_reg_reg <= cnt_fs_reg_reg;

end 

// 产生计算标志信号 calc_flag
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        calc_flag <= 1'd0;
    else if(cnt_gate_fs == (CNT_GATE_MAX - (CNT_GATE_LOW / 2) - 28'd2))
        calc_flag <= 1'd1; 
    else if(cnt_gate_fs == (CNT_GATE_MAX - (CNT_GATE_LOW / 2) - 28'd1))
        calc_flag <= 1'd0;
    else
        calc_flag <= calc_flag;

end 

//被测时钟启动是否为零
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        fx_flag <= 1'd0;
    else if(clk_fx && gate_fx)
        fx_flag <= 1'd1;
    else
        fx_flag <= fx_flag;
    
end 

//闸门时间计数
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        cnt_delay <= 28'd0;
    else if(gate_fx_pose)
        cnt_delay <= 28'd0;
        //等待两秒再判断  因为闸门拉高时间是1.5s
    else if(cnt_delay == CNT_TIME_MAX)
        cnt_delay <= CNT_TIME_MAX;
    else
        cnt_delay <= cnt_delay + 28'd1;

end 

//如果两秒后闸门还未拉高代表测试信号断开
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        flag_delay <= 1'b0;
    else if(cnt_delay >= CNT_TIME_MAX)
        flag_delay <= 1'b1;
    else if(cnt_delay < CNT_TIME_MAX)
        flag_delay <= 1'b0;
    else
        flag_delay <= flag_delay;

end 
//获取被测信号的频率值
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        data_fx <= 30'd0;
    else if(!fx_flag)//代表未拉高闸门
        data_fx <= 30'd0;
    else if(flag_delay)//代表测试信号断开
        data_fx <= 30'd0;
    else if(vld_out)
        data_fx <= quotient;
    else
        data_fx <= data_fx;

end 

//除法运算开始标志
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        en <= 1'd0;
    else if(cnt_gate_fs == (CNT_GATE_MAX - CNT_GATE_LOW /2 ))
        en <= 1'd1;
    else if(vld_out)
        en <= 1'd0;
    else
        en <= en;
end 

//给分母和分子赋值
always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)begin
        dividend <= 57'd0;
        divisor <= 57'd1; //分母不能为0    
    end 
    else if(calc_flag)begin
        dividend <= numer_reg;
        divisor <= cnt_fs_reg_reg;
    
    end 
    else begin
        dividend <= dividend;
        divisor <=  divisor ;
    end 


end 


endmodule
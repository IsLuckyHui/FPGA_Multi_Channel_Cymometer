module clk_test(
    input           sys_clk,
    input           sys_rst_n,
    
    output  reg     clk_out       



);

parameter     DIV = 100;//分频系数

reg [25:0] cnt; // 时钟分频计数
//生成500KHz时钟
always@(posedge sys_clk or negedge sys_rst_n)begin  
    if(!sys_rst_n)
        clk_out <= 1'b0;
    else  if(cnt >= DIV/2 - 26'd1)
        clk_out <= ~clk_out;
    else
        clk_out <= clk_out;

end 

always@(posedge sys_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        cnt <= 26'd0;
    else if(cnt >= DIV/2 - 26'd1)
        cnt <= 26'd0;
    else
        cnt <= cnt + 26'd1;
    
end 


endmodule
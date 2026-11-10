module pcf8563_ctrl
(
input                clk        , //时钟
input                ila_clk    ,
input                rst_n      , //复位
output   reg         i2c_exec   , //i2c操作使能
output   reg         i2c_rh_wl  , //i2c读写信号  0为写 1为读
output   reg  [15:0] i2c_addr   , //i2c器件内地址（寄存器地址）
output   reg  [7:0]  i2c_data_w , //i2c要写入的数据
input          [7:0]  i2c_data_r , //i2c要读出的数据
input                i2c_done   , //i2c完成一次传输的信号
    
    //PCF8563T的秒、分、时、日、月、年数据
output reg [7:0] sec , //秒
output reg [7:0] min , //分
output reg [7:0] hour,//时
output reg [7:0] day , //日
output reg [7:0] mon , //月
output reg [7:0] year //年
    
);

//parameter define
parameter TIME_INIT = 48'h26_09_22_07_30_00;
localparam WAIT_TIME = 13'd8_000; //等待的时间 在上电后必须等待八毫秒

//reg define
reg [3:0] flow_cnt ; // 转态流控制
reg [12:0] wait_cnt ; // 计数等待

//先向PCF8563中写入初始化日期和时间，再从中读出日期和时间
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sec        <= 8'h0;
        min        <= 8'h0;
        hour       <= 8'h0;
        day        <= 8'h0;
        mon        <= 8'h0;
        year       <= 8'h0;
        i2c_exec   <= 1'b0;
        i2c_rh_wl  <= 1'b0;
        i2c_addr   <= 16'd0;
        i2c_data_w <= 8'd0;
        flow_cnt   <= 4'd0;
        wait_cnt   <= 13'd0;
    end
    else begin
        i2c_exec <= 1'b0;
        case(flow_cnt)
            //上电初始化
            4'd0: begin
                if(wait_cnt == (WAIT_TIME - 13'd1)) begin
                    wait_cnt<= 13'd0;
                    flow_cnt<= flow_cnt + 4'b1;
                end
                else
                    wait_cnt<= wait_cnt + 13'b1;
            end
            //写读秒
            4'd1: begin
                i2c_exec  <= 1'b1;
                i2c_addr  <= 16'h02;
                flow_cnt  <= flow_cnt + 4'b1;
                i2c_data_w<= TIME_INIT[7:0];
            end
            4'd2: begin
                if(i2c_done == 1'b1) begin
                    sec     <= i2c_data_r[6:0];
                    flow_cnt<= flow_cnt + 4'b1;
                end
            end
            //写读分
            4'd3: begin
                i2c_exec  <= 1'b1;
                i2c_addr  <= 16'h03;
                flow_cnt  <= flow_cnt + 4'b1;
                i2c_data_w<= TIME_INIT[15:8];
            end
            4'd4: begin
                if(i2c_done == 1'b1) begin
                    min     <= i2c_data_r[6:0];
                    flow_cnt<= flow_cnt + 4'b1;
                end
            end
            //写读时
            4'd5: begin
                i2c_exec  <= 1'b1;
                i2c_addr  <= 16'h04;
                flow_cnt  <= flow_cnt + 4'b1;
                i2c_data_w<= TIME_INIT[23:16];
            end
            4'd6: begin
                if(i2c_done == 1'b1) begin
                    hour    <= i2c_data_r[5:0];
                    flow_cnt<= flow_cnt + 4'b1;
                end
            end
            //写读天
            4'd7: begin
                i2c_exec  <= 1'b1;
                i2c_addr  <= 16'h05;
                flow_cnt  <= flow_cnt + 4'b1;
                i2c_data_w<= TIME_INIT[31:24];
            end
            4'd8: begin
                if(i2c_done == 1'b1) begin
                    day     <= i2c_data_r[5:0];
                    flow_cnt<= flow_cnt + 4'b1;
                end
            end
            //写读月
            4'd9: begin
                i2c_exec  <= 1'b1;
                i2c_addr  <= 16'h07;
                flow_cnt  <= flow_cnt + 4'b1;
                i2c_data_w<= TIME_INIT[39:32];
            end
            4'd10: begin
                if(i2c_done == 1'b1) begin
                    mon     <= i2c_data_r[4:0];
                    flow_cnt<= flow_cnt + 4'b1;
                end
            end
            //写读年
            4'd11: begin
                i2c_exec  <= 1'b1;
                i2c_addr  <= 16'h08;
                flow_cnt  <= flow_cnt + 4'b1;
                i2c_data_w<= TIME_INIT[47:40];
            end
            4'd12: begin
                if(i2c_done == 1'b1) begin
                    year     <= i2c_data_r;
                    i2c_rh_wl<= 1'b1;
                    flow_cnt <= 4'd1;
                end
            end
            default: flow_cnt <= 4'd0;
        endcase
    end
end


/*ila_0 u_ila_0 (
	.clk(ila_clk), // input wire clk

	.probe0(i2c_exec   ), // input wire [0:0]  probe0  
	.probe1(i2c_rh_wl  ), // input wire [0:0]  probe1 
	.probe2(i2c_addr   ), // input wire [15:0]  probe2 
	.probe3(i2c_data_w ), // input wire [7:0]  probe3 
	.probe4(i2c_done), // input wire [0:0]  probe4 
	.probe5(sec ), // input wire [7:0]  probe5 
	.probe6(min ), // input wire [7:0]  probe6 
	.probe7(hour), // input wire [7:0]  probe7 
	.probe8(day ), // input wire [7:0]  probe8 
	.probe9(mon ), // input wire [7:0]  probe9 
	.probe10(year), // input wire [7:0]  probe10
	.probe11(flow_cnt), // input wire [3:0]  probe11 
	.probe12(wait_cnt) // input wire [12:0]  probe12
);*/

endmodule
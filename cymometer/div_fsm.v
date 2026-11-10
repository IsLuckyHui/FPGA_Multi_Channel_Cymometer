module div_fsm#(
    parameter DATAWIDTH = 8   //数字宽度
)
(
    input                       clk      ,
    input                       rst_n    ,
    input       [DATAWIDTH-1:0] dividend , //分子
    input       [DATAWIDTH-1:0] divisor  , //分母
    input                       en       , //开始使能
                        
    output                      ready    , //是否空闲
    output     [DATAWIDTH-1:0] quotient , //计算出来的商
    output     [DATAWIDTH-1:0] remainder, //计算出来的余数
    output                    vld_out    //输出有效信号
);

//parameter define 

//状态机状态定义 独热码
localparam IDLE = 4'b0001;  
localparam SUB  = 4'b0010;
localparam SHIFT = 4'b0100;
localparam DONE  = 4'b1000;

//reg define
reg [DATAWIDTH * 2'd2 - 1'b1 :0] dividend_e     ; //扩大两位时为了最后一步将数值从中间劈开
reg [DATAWIDTH * 2'd2 - 1'b1 :0] divisor_e      ;
reg [DATAWIDTH - 1'b1:0]         quotient_e     ;
reg [DATAWIDTH - 1'b1:0]         remainder_e    ;
reg [3:0]                        current_state  ;
reg [3:0]                        next_state     ;
reg [DATAWIDTH - 1'b1:0]         count          ;

assign quotient = quotient_e;
assign remainder = remainder_e;

assign ready = (current_state == IDLE) ? 1'b1:1'b0;
assign vld_out = (current_state == DONE) ? 1'b1:1'b0;

//三段式状态机
always@(posedge clk or negedge rst_n)begin  
    if(!rst_n)
        current_state <= IDLE;
    else    
        current_state <= next_state;

end 

always@(*)begin
    next_state = IDLE;
    case(current_state)
        IDLE : begin
            if(en)
               next_state = SUB;
            else
               next_state = IDLE;        
        end 
        SUB : next_state = SHIFT;
        SHIFT :begin
            if(count < DATAWIDTH)
                next_state = SUB;
            else
                next_state = DONE;
        end 
        DONE :
            next_state = IDLE;
        default :  next_state = IDLE;
        
        
    endcase    
end 

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        dividend_e    <= 'd0;    
        divisor_e     <= 'd0;
        quotient_e    <= 'd0;
        remainder_e   <= 'd0; 
        count         <= 'd0;   
    end 
    else begin
        case(current_state)
            IDLE :begin
                dividend_e <= {{DATAWIDTH{1'b0}},dividend};//高位补零 
                divisor_e <= {divisor,{DATAWIDTH{1'b0}}};  //低位补零
            end 
            SUB :begin
                if(dividend_e >= divisor_e)begin
                    quotient_e <= {quotient_e[DATAWIDTH-2'd2:0],1'b1};
                    dividend_e <= dividend_e-divisor_e;
                end 
                else begin
                    quotient_e <= {quotient_e[DATAWIDTH-2'd2:0],1'b0};
                    dividend_e <= dividend_e;
                end 
            end 
            SHIFT :begin
                if(count < DATAWIDTH)begin
                    count <= count + 'd1;
                    dividend_e <= (dividend_e << 'd1);
                
                end 
                else
                //商等于
                    remainder_e <= dividend_e[DATAWIDTH*2 - 1 :DATAWIDTH];
            
            end 
            DONE :
                 count <= 'd0;
        endcase
    end 
end 



endmodule 
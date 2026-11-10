module lcd_display(
    input             lcd_pclk  ,               //LCD驱动时钟
    input             sys_rst_n ,               //复位信号
    input      [35:0] data      ,
    input      [10:0] pixel_xpos,               //像素点横坐标
    input      [10:0] pixel_ypos,               //像素点纵坐标

    output reg [23:0] pixel_data                //像素点数据
);
//parameter define
//数字
parameter  CHAR_POS_X  = 11'd1      ;           //字符区域起始点横坐标
parameter  CHAR_POS_Y  = 11'd1      ;           //字符区域起始点纵坐标
parameter  CHAR_WIDTH  = 11'd88     ;           //字符区域宽度
parameter  CHAR_HEIGHT = 11'd16     ;           //字符区域高度
parameter  WHITE       = 24'hFFFFFF ;           //背景色，白色
parameter  BLACK       = 24'h0      ;           //字符颜色，黑色 
//名字
parameter  NAME_WIDTH =  11'd96     ;           //名字宽度
parameter  NAME_HEIGHT = 11'd32     ;           //名字高度
parameter  NAME_POS_X =  11'd700    ;           //名字起始点横坐标
parameter  NAME_POS_Y =  11'd440    ;           //名字起始点纵坐标
//标题
parameter  TITLE_WIDTH = 11'd224    ;
parameter  TITLE_HEIGHT = 11'd32    ;
parameter  TITLE_POS_X = 11'd288    ;//确保在中间位置 只针对800*400
parameter  TITLE_POS_Y = 11'd1      ;
//汉字
parameter  HANZI_WIDTH = 11'd96     ;
parameter  HANZI_HEIGHT = 11'd32    ;
parameter  HANZI_POS_X = 11'd1      ;
parameter  HANZI_POS_Y = 11'd50     ;


//reg define
reg     [127:0 ] char        [11:0]  ;           //字符数组
reg     [1023:0] name        [2:0]   ;           //名字数组
reg     [1023:0] title       [6:0]   ;           //标题数组
reg     [1023:0] channel     [1:0]   ;           //通道 
reg     [1023:0] hanzi       [9:0]   ;           //汉字零到九 第零位是0 第九位是九
//wire define                
wire    [3:0]      data0    ;            // 个位数
wire    [3:0]      data1    ;            // 十位数
wire    [3:0]      data2    ;            // 百位数
wire    [3:0]      data3    ;            // 千位数
wire    [3:0]      data4    ;            // 万位数
wire    [3:0]      data5    ;            // 十万位数
wire    [3:0]      data6    ;            // 百万位数
wire    [3:0]      data7    ;            // 千万位数
wire    [3:0]      data8    ;            // 亿位数

assign  data8 = data[35:32];    // 亿位数
assign  data7 = data[31:28];    // 千万位数
assign  data6 = data[27:24];    // 百万位数
assign  data5 = data[23:20];    // 十万位数
assign  data4 = data[19:16];    // 万位数
assign  data3 = data[15:12];    // 千位数
assign  data2 = data[11:8];     // 百位数
assign  data1 = data[7:4];      // 十位数
assign  data0 = data[3:0];      // 个位数
//名字数组赋值
always@(posedge lcd_pclk)begin
   name[0] <=  1024'h0000000000000000000000000000000000000020000000700FFFFFF00001800000018000000180000001800000018000000180000001800000018000000180C007FFFFE000018000000180000001800000018000000180000001800000018000000180000001800000018000000180183FFFFFFC000000000000000000000000;/*"王0*/
   name[1] <=  1024'h000000000000000000020000000180000001C0000000C0000000803007FFFFF8040000300C0000600C0000400C0000000000030001FFFF8000018000000180000001800000018010000180383FFFFFFC0001800000018000000180000001800000018000000180000001800000018000003F8000000700000002000000000000;/*"宇1*/
   name[2] <=  1024'h00000000000000000100000001C080080180FFFC2188801C118D8810199B8E20099B1C000D9018000DA0181009A1FFF801C03000018464007FFE63000660C200066182100661FFF806600200066002000460020004620200046402080C6BFFFC0878020008700200186002001020020020000200200002004000020000000000;/*"辉2*/

end 
//通道数组赋值
always@(posedge lcd_pclk)begin
   channel[0] <=  1024'h000000000000000000000040080FFFE00C0001E006008300070074000300380002101820001FFFF80018103000181030011810307F9FFFF003181030031810300318103003181030031FFFF00318103003181030031810300318103003181030031811F00C90006038600000703E000E200FFFF80000FFF00000000000000000;/*通*/
   channel[1] <=  1024'h0000000000000000000001000C0301C0060181800301C3000300C20003008418003FFFFC0000300000003000010420407F87FFE0030600C0030600C00307FFC0030600C0030600C0030600C00307FFC0030600C0030600C0030600C00307FFC0048600C01846008030200000301C0000000FFFFC00007FF00000000000000000;/*道*/

end 
//汉字数组赋值
always@(posedge lcd_pclk)begin
   hanzi[0]  <=   1024'h00000000000000000000008003FFFFC0000180000001800007FFFFF80C0180180C0180301801802019F99F80000100000000000003F91F800003800000078000000C4000003C300000731C0001C187F00E0080FC3000801003FFFE0000000F000000180000206000001E80000003C0000000F000000038000000180000000000;/*"零"*/
   hanzi[1]  <=   1024'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000303FFFFFFC0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;/*"一"*/
   hanzi[2]  <=   1024'h0000000000000000000000000000000000000000000000000000000000000000000000C007FFFFE0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000383FFFFFFC0000000000000000000000000000000000000000;/*"二"*/ 
   hanzi[3]  <=   1024'h000000000000000000000000000000000000000000000020000000700FFFFFF0000000000000000000000000000000000000000000000000000000000000018003FFFFC0000000000000000000000000000000000000000000000000000000000000000000000000000000187FFFFFFC00000000000000000000000000000000;/*"三"*/ 
   hanzi[4]  <=   1024'h000000000000000000000000080000200FFFFFF00C0C30300C0C30300C0C30300C0C30300C0C30300C0C30300C0830300C0830300C0830300C1830300C1830300C1830300C1830300C1030300C3030300C203FB00C601FF00CC000300D8000300E0000300C0000300C0000300FFFFFF00C0000300C0000300C00002000000000;/*"四"*/ 
   hanzi[5]  <=   1024'h000000000000000000000000000000600FFFFFF000030000000300000003000000020000000600000006000000060000000600000006010007FFFF8000040300000C0300000C0300000C0300000C0300000C0300000803000018030000180300001803000018030000180300001003183FFFFFFC000000000000000000000000;/*"五"*/ 
   hanzi[6]  <=   1024'h0000000000000000000400000006000000030000000180000001C0000001C0000000C00000008000000000183FFFFFFC00000000000000000010000000182000001C1000003808000038040000300600006003000060018000C001C0018000E0018000F003000070060000700C00003018000030100000002000000000000000;/*"六"*/ 
   hanzi[7]  <=   1024'h000000000000000000060000000700000006000000060000000600000006000000060000000600100006003C000601C000061E000007E000001E000001E600001E0600002006000000060000000600000006000800060008000600080006000800060008000600080003001C0003FFFC0001FFF8000000000000000000000000;/*"七"*/ 
   hanzi[8]  <=   1024'h0000000000000000000000000000200000103000001C2000001C20000018300000183000001810000018100000181000001810000010180000301800003008000030080000300C0000600400006006000040060000C0030000C0030001800180010001C0030000E0060000F0040000780800003E100000102000000000000000;/*"八"*/ 
   hanzi[9]  <=   1024'h000000000000000000080000000C0000000800000008000000080000001800000018000000180C001FFFFC0000180800001808000018080000180800001808000010080000300800003008000030080000200800006008000040080000C008080080080801000808030008080600080C0C000FFC10000FF82000000000000000;/*"九"*/
end

//标题数组赋值
always@(posedge lcd_pclk)begin
   title[0] <=  1024'h000000000000000000010000000180000003000000060040000FFFE0003800E0006803800086070003060E000C031800000270000000C00000074000001CC00001E1C0000E0380200007FFF0000E0070003800E0006401C0018603800603070000030C00000338000000600000038000001E000000F000001F00000000000000;//"多"
   title[1] <=  1024'h00000000000000000000200000003800001030000FFC602008187FF0081840600818C0C00818A0C008199180081911000FFA0B0009920E0001800F0001801B80119030E01DF8607C1980C05819837FF8198C406019804060198040601980406019B840601BC040603E00406038007FE000004060000040600000000000000000;//"路"
   title[2] <=  1024'h000000000000000000400000006000080061FFFC006003000660060006640400067E040806607FFC0660601806606018066262183FFF639800406318006063180440631806406318064263180C4763180C466318184C6218104C6218201807002030048000600C6000C018380180301C0600600C080180043006000400000000;//"频"
   title[3] <=  1024'h0000000000000000000200000003800000018000000180201FFFFFF000030000000300000C061040070C38E003983180013FE3000138C4000001800000430200008621C0030818E00E3FFC301C3D0C300801880000018000000180183FFFFFFC0001800000018000000180000001800000018000000180000001000000000000;//"率"
   title[4] <=  1024'h00000000000000000400100002001C000180180001C0180000C0180000C0180000001800000018000000180000001800010018187F9FFFFC01001800010018000100180001001800010018000100180001001800010018000108180001101800013018000160180001C018000380180001801800000018000000100000000000;//"计"
   title[5] <=  1024'h00000000000000000000300000003800040230000203300003063000030630C00107FFE0000430000008300000083000011030003F803030033FFFF80300C4000300C400030084000301840003018400030104000303041003020410030404180708061C1C9007F838600000303C0006000FFFF80000FFF00000000000000000;//"选"
   title[6] <=  1024'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000303FFFFFFC0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;//"一"
end 

//给字符数组赋值，用于存储字模数据
always @(posedge lcd_pclk) begin
    char[0 ]  <= 128'h00000018244242424242424224180000 ; // "0"
    char[1 ]  <= 128'h000000107010101010101010107C0000 ; // "1"
    char[2 ]  <= 128'h0000003C4242420404081020427E0000 ; // "2"
    char[3 ]  <= 128'h0000003C424204180402024244380000 ; // "3"
    char[4 ]  <= 128'h000000040C14242444447E04041E0000 ; // "4"
    char[5 ]  <= 128'h0000007E404040586402024244380000 ; // "5"
    char[6 ]  <= 128'h0000001C244040586442424224180000 ; // "6"
    char[7 ]  <= 128'h0000007E444408081010101010100000 ; // "7"
    char[8 ]  <= 128'h0000003C4242422418244242423C0000 ; // "8"
    char[9 ]  <= 128'h0000001824424242261A020224380000 ; // "9"
    char[10]  <= 128'h000000E7424242427E42424242E70000 ; // "H"
    char[11]  <= 128'h000000000000007E44081010227E0000 ; // "z"
end 

//给不同的区域赋值不同的像素数据
always @(posedge lcd_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n)  begin
        pixel_data <= WHITE;
    end
    //数字显示
    else if((pixel_xpos >= CHAR_POS_X - 11'd1) 
            && (pixel_xpos < CHAR_POS_X - 1'd1  + CHAR_WIDTH / 11'd11 * 11'd1)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data8][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;          //显示字符为黑色
            else
                pixel_data <= WHITE;          //显示字符区域背景为白色
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd1) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd2)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data7][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd2) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd3)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data6][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd3) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd4)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data5][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8
                - ((pixel_xpos-(CHAR_POS_X - 11'd1))%11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd4) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd5)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data4][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd5) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd6)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data3][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd6) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd7)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data2][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd7) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd8)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data1][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end        
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd8) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd9)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[data0][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1))%11'd8) -11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end 
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd9) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd10)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[10][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end
    else if((pixel_xpos >= CHAR_POS_X - 11'd1 + CHAR_WIDTH / 11'd11 * 11'd10) 
            && (pixel_xpos < CHAR_POS_X - 11'd1 + CHAR_WIDTH)
            && (pixel_ypos >= CHAR_POS_Y) 
            && (pixel_ypos < CHAR_POS_Y + CHAR_HEIGHT)
            ) begin
            if(char[11][(CHAR_HEIGHT+CHAR_POS_Y - pixel_ypos) * 11'd8 
                - ((pixel_xpos-(CHAR_POS_X - 11'd1)) % 11'd8) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
        end 
        //名字
    else if((pixel_xpos >= NAME_POS_X - 11'd1) 
            && (pixel_xpos < NAME_POS_X - 11'd1 + NAME_WIDTH / 11'd3 * 11'd1)
            && (pixel_ypos >= NAME_POS_Y) 
            && (pixel_ypos < NAME_POS_Y + NAME_HEIGHT))
             begin
            if(name[0][(NAME_HEIGHT+NAME_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(NAME_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= NAME_POS_X - 11'd1 + NAME_WIDTH / 11'd3 * 11'd1) 
            && (pixel_xpos < NAME_POS_X - 11'd1 + NAME_WIDTH / 11'd3 * 11'd2)
            && (pixel_ypos >= NAME_POS_Y) 
            && (pixel_ypos < NAME_POS_Y + NAME_HEIGHT))
             begin
            if(name[1][(NAME_HEIGHT+NAME_POS_Y - pixel_ypos) * 11'd32  
                - ((pixel_xpos-(NAME_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= NAME_POS_X - 11'd1 + NAME_WIDTH / 11'd3 * 11'd2) 
            && (pixel_xpos < NAME_POS_X - 11'd1 + NAME_WIDTH / 11'd3 * 11'd3)
            && (pixel_ypos >= NAME_POS_Y) 
            && (pixel_ypos < NAME_POS_Y + NAME_HEIGHT))
             begin
            if(name[2][(NAME_HEIGHT+NAME_POS_Y - pixel_ypos) * 11'd32  
                - ((pixel_xpos-(NAME_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    //标题
    else if((pixel_xpos >= TITLE_POS_X - 11'd1) 
            && (pixel_xpos < TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd1)
            && (pixel_ypos >= TITLE_POS_Y) 
            && (pixel_ypos < TITLE_POS_Y + TITLE_HEIGHT))
             begin
            if(title[0][(TITLE_HEIGHT+TITLE_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(TITLE_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= TITLE_POS_X - 11'd1  + TITLE_WIDTH / 11'd7 * 11'd1) 
            && (pixel_xpos < TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd2)
            && (pixel_ypos >= TITLE_POS_Y) 
            && (pixel_ypos < TITLE_POS_Y + TITLE_HEIGHT))
             begin
            if(title[1][(TITLE_HEIGHT+TITLE_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(TITLE_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= TITLE_POS_X - 11'd1+ TITLE_WIDTH / 11'd7 * 11'd2) 
            && (pixel_xpos < TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd3)
            && (pixel_ypos >= TITLE_POS_Y) 
            && (pixel_ypos < TITLE_POS_Y + TITLE_HEIGHT))
             begin
            if(title[2][(TITLE_HEIGHT+TITLE_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(TITLE_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd3) 
            && (pixel_xpos < TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd4)
            && (pixel_ypos >= TITLE_POS_Y) 
            && (pixel_ypos < TITLE_POS_Y + TITLE_HEIGHT))
             begin
            if(title[3][(TITLE_HEIGHT+TITLE_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(TITLE_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= TITLE_POS_X - 11'd1+ TITLE_WIDTH / 11'd7 * 11'd4) 
            && (pixel_xpos < TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd5)
            && (pixel_ypos >= TITLE_POS_Y) 
            && (pixel_ypos < TITLE_POS_Y + TITLE_HEIGHT))
             begin
            if(title[4][(TITLE_HEIGHT+TITLE_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(TITLE_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd5 ) 
            && (pixel_xpos < TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd6)
            && (pixel_ypos >= TITLE_POS_Y) 
            && (pixel_ypos < TITLE_POS_Y + TITLE_HEIGHT))
             begin
            if(title[5][(TITLE_HEIGHT+TITLE_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(TITLE_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else if((pixel_xpos >= TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd6) 
            && (pixel_xpos < TITLE_POS_X - 11'd1 + TITLE_WIDTH / 11'd7 * 11'd7)
            && (pixel_ypos >= TITLE_POS_Y) 
            && (pixel_ypos < TITLE_POS_Y + TITLE_HEIGHT))
             begin
            if(title[6][(TITLE_HEIGHT+TITLE_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(TITLE_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    //汉字显示 通道一
    else if((pixel_xpos >= HANZI_POS_X - 11'd1 ) 
            && (pixel_xpos < HANZI_POS_X - 11'd1 + HANZI_WIDTH / 11'd3 * 11'd1)
            && (pixel_ypos >= HANZI_POS_Y) 
            && (pixel_ypos < HANZI_POS_Y + HANZI_HEIGHT))
             begin
            if(title[0][(HANZI_HEIGHT+HANZI_POS_Y - pixel_ypos) * 11'd32 
                - ((pixel_xpos-(HANZI_POS_X - 11'd1)) % 11'd32 ) - 11'd1])
                pixel_data <= BLACK;
            else
                pixel_data <= WHITE;
            end
    else begin
        pixel_data <= WHITE;              //绘制屏幕背景为白色
    end
end

endmodule 
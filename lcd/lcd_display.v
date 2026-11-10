module lcd_display#(
    parameter CH_NUM      = 4'd9     , // 通道数量
    parameter CHAR_POS_X  = 11'd1    , // 字符显示区域起始X坐标
    parameter CHAR_POS_Y  = 11'd1    , // 字符显示区域起始Y坐标
    parameter CHAR_WIDTH  = 11'd88   , // 字符区域宽度
    parameter CHAR_HEIGHT = 11'd16   , // 字符区域高度
    parameter WHITE       = 24'hFFFFFF, // 背景色：白色
    parameter BLACK       = 24'h0      // 字符颜色：黑色
)(
    input             lcd_pclk  ,               // LCD驱动像素时钟
    input             sys_rst_n ,               // 系统复位，低电平有效
    input      [CH_NUM*36-1:0] data_all ,        // 所有通道频率BCD数据，每个通道占36bit
    input      [31:0] touch_data,               // 触摸坐标数据
    input             page      ,               // 翻页标志：0=第一页，1=第二页
    input      [10:0] pixel_xpos,               // 当前像素X坐标
    input      [10:0] pixel_ypos,               // 当前像素Y坐标
    
    // 日历RTC数据
    input [7:0] sec         , // 秒
    input [7:0] min         , // 分
    input [7:0] hour        , // 时
    input [7:0] day         , // 日
    input [7:0] mon         , // 月
    input [7:0] year        , // 年
    
    output reg [23:0] pixel_data                // 输出当前像素颜色
);

// 触摸坐标显示区域
localparam TOUCH_POS_X = 11'd600;
localparam TOUCH_POS_Y = 11'd20;
localparam TOUCH_WIDTH = 11'd144;
localparam TOUCH_HEIGHT = 11'd32;                // 字符区域高度


// 日期显示区域 (8x16点阵，两行)
localparam DATE_POS_X_1 = 11'd30; // 第一行字符区域起始X
localparam DATE_POS_Y_1 = 11'd30; // 第一行字符区域起始Y
localparam DATE_POS_X_2 = 11'd47; // 第二行字符区域起始X
localparam DATE_POS_Y_2 = 11'd47; // 第二行字符区域起始Y
localparam DATE_WIDTH_1 = 11'd80; // 第一行字符区域宽度，10个字符含分隔符
localparam DATE_WIDTH_2 = 11'd64; // 第二行字符区域宽度
// 数字点阵(8x16，最多11个字符)，白、黑已经在端口参数定义
parameter  LIGHTGRAY   = 24'hD6D6D6 ;
parameter  BLUE        = 24'h0023F5 ;
// 名字区域 (32x32，3个汉字)
parameter  NAME_WIDTH  = 11'd96     ;
parameter  NAME_HEIGHT = 11'd32     ;
parameter  NAME_POS_X  = 11'd700    ;
parameter  NAME_POS_Y  = 11'd440    ;
// 标题区域 (48x48，5个汉字)
parameter  TITLE_WIDTH = 11'd240    ;
parameter  TITLE_HEIGHT= 11'd48     ;
parameter  TITLE_POS_X = 11'd280    ;
parameter  TITLE_POS_Y = 11'd20      ;
// 通道显示区域 (32x32，3行3列，每个块显示"CH N:" + 下方频率)
parameter  HANZI_WIDTH = 11'd128     ;           // "CH N:" 四个字符总宽度(4*32)
parameter  HANZI_HEIGHT= 11'd32     ;           // 字符高度
parameter  HANZI_POS_X = 11'd100     ;           // 通道1左上角X坐标
parameter  HANZI_POS_Y = 11'd120     ;           // 通道1左上角Y坐标
parameter  CH_PITCH_X  = 11'd250    ;           // 通道块之间水平间距
parameter  CH_PITCH_Y  = 11'd100    ;           // 通道块之间垂直间距
parameter  CH_COLS     = 11'd3      ;           // 每行通道数量
parameter  CH_ROWS     = 11'd3      ;           // 总行数
parameter  CH_FREQ_OFF = 11'd96     ;           // 频率字符在块内X偏移（"CH N:"后面）
parameter  CH_FREQ_OFF_X = 11'd0     ;           // 频率区域X偏移
parameter  CH_FREQ_OFF_Y = HANZI_HEIGHT;         // 频率区域Y偏移，在通道名称下方
parameter  CH_FREQ_W   = 11'd176     ;           // 频率字符区域宽度（11个8x16字符）
parameter  CH_FREQ_H   = 11'd32     ;           // 频率字符区域高度
// 翻页按钮区域
parameter UP_DOWN_POS_X = 11'd650 ;
parameter UP_DOWN_POS_Y = 11'd420 ;
parameter UP_DOWN_WIDTH = 11'd96  ;
parameter UP_DOWN_HEIGHT = 11'd32 ;
// 频率数字点阵尺寸
parameter FREQ_WIDTH = 11'd32;
parameter FREQ_HEIGHT = 11'd32;
// 蓝色边框参数
parameter BORDER_BLUE_START_X_TOP = 11'd0; // 上边框
parameter BORDER_BLUE_END_X_TOP = 11'd800;
parameter BORDER_BLUE_START_Y_TOP = 11'd0;
parameter BORDER_BLUE_END_Y_TOP = 11'd20;

parameter BORDER_BLUE_START_X_BOTTOM = 11'd0; // 下边框
parameter BORDER_BLUE_END_X_BOTTOM = 11'd800;
parameter BORDER_BLUE_START_Y_BOTTOM = 11'd460;
parameter BORDER_BLUE_END_Y_BOTTOM = 11'd480;

parameter BORDER_BLUE_START_X_LEFT = 11'd0; // 左边框
parameter BORDER_BLUE_END_X_LEFT = 11'd20;
parameter BORDER_BLUE_START_Y_LEFT = 11'd20;
parameter BORDER_BLUE_END_Y_LEFT = 11'd460;

parameter BORDER_BLUE_START_X_RIGHT = 11'd780; // 右边框
parameter BORDER_BLUE_END_X_RIGHT = 11'd800;
parameter BORDER_BLUE_START_Y_RIGHT = 11'd20;
parameter BORDER_BLUE_END_Y_RIGHT = 11'd460;

//reg define
reg     [127:0 ] char    [14:0]  ;           // 8x16 英文字符/数字点阵数组
reg     [1023:0] name    [2:0]   ;           // 32x32 名字汉字点阵
reg     [2303:0] title   [4:0]   ;           // 48x48 标题汉字点阵
reg     [1023:0] channel [1:0]   ;           // "CH" 32x32点阵
reg     [1023:0] hanzi   [11:0]   ;           // 0~9、十 32x32汉字点阵
reg     [511:0]  freqNumber [11:0] ;          // 频率数字点阵：0~9、H、z
reg     [1023:0] up_down_page [3:0] ;         // 翻页图标点阵：上、下、一、页

//翻页数组赋值
always@(posedge lcd_pclk)begin
    up_down_page[0] <= {
        256'h00000000000000000000000000000010000000383FFFFFF80003000000030000,
        256'h00030000000300000003000000030000000380000003700000031C0000030F00,
        256'h00030380000301C0000300C0000300C000030000000300000003000000030000,
        256'h0003000000030000000300000003000000030000000300000002000000000000
    };
    up_down_page[1] <= {
        256'h0000000000000000000200000003800000030000000300000003000000030000,
        256'h00030000000300000003000000030000000300C00003FFE00003000000030000,
        256'h0003000000030000000300000003000000030000000300000003000000030000,
        256'h000300000003000000030000000300183FFFFFFC000000000000000000000000
    };    
    up_down_page[2] <= {
        256'h0000000000000000000000000000000000000000000000000000000000000000,
        256'h0000000000000000000000000000000000000000000000303FFFFFFC00000000,
        256'h0000000000000000000000000000000000000000000000000000000000000000,
        256'h0000000000000000000000000000000000000000000000000000000000000000
    };
    up_down_page[3] <= {
        256'h000000000000000000000020000000701FFFFFF8000300000003000000020000,
        256'h0104010001FFFF80018003000180030001800300018183000181830001818300,
        256'h0181830001830300018303000183030001830300018303000102C00000063800,
        256'h000E0E00000C0780001801E0007000F000C00070070000303800000000000000
    };
end 


//频率数组赋值
always@(posedge lcd_pclk)begin
    freqNumber[0] <=  {
                    256'h00000000000000000000000003C006200C30181818181808300C300C300C300C,
                    256'h300C300C300C300C300C300C1808181818180C30062003C00000000000000000
    };
    freqNumber[1] <= { 
                    256'h000000000000000000000000008001801F800180018001800180018001800180,
                    256'h018001800180018001800180018001800180018003C01FF80000000000000000
    };
    freqNumber[2] <= { 
                    256'h00000000000000000000000007E008381018200C200C300C300C000C00180018,
                    256'h0030006000C0018003000200040408041004200C3FF83FF80000000000000000
    };
    freqNumber[3] <= { 256'h00000000000000000000000007C0186030303018301830180018001800300060,
                    256'h03C0007000180008000C000C300C300C30083018183007C00000000000000000
    };
    freqNumber[4] <= { 256'h0000000000000000000000000060006000E000E0016001600260046004600860,
                    256'h086010603060206040607FFC0060006000600060006003FC0000000000000000
    };
    freqNumber[5] <= { 256'h0000000000000000000000000FFC0FFC10001000100010001000100013E01430,
                    256'h18181008000C000C000C000C300C300C20182018183007C00000000000000000
    };
    freqNumber[6] <= { 256'h00000000000000000000000001E006180C180818180010001000300033E03630,
                    256'h38183808300C300C300C300C300C180C18080C180E3003E00000000000000000
    };
    freqNumber[7] <= { 256'h0000000000000000000000001FFC1FFC10083010201020200020004000400040,
                    256'h0080008001000100010001000300030003000300030003000000000000000000
    };
    freqNumber[8] <= { 256'h00000000000000000000000007E00C301818300C300C300C380C38081E180F20,
                    256'h07C018F030783038601C600C600C600C600C3018183007C00000000000000000
    };
    freqNumber[9] <= { 256'h00000000000000000000000007C01820301030186008600C600C600C600C600C,
                    256'h701C302C186C0F8C000C0018001800103030306030C00F800000000000000000
    };
    freqNumber[10] <= { 256'h000000000000000000000000FC3F300C300C300C300C300C300C300C300C300C,
                    256'h3FFC300C300C300C300C300C300C300C300C300C300CFC3F0000000000000000
    };
    freqNumber[11] <= { 256'h00000000000000000000000000000000000000000000000000003FF830383030,
                    256'h206020E000C001800380030006000E040C04180C30183FF80000000000000000
    };

end 



//名字数组赋值
always@(posedge lcd_pclk)begin
   name[0] <=  1024'h0000000000000000000000000000000000000020000000700FFFFFF00001800000018000000180000001800000018000000180000001800000018000000180C007FFFFE000018000000180000001800000018000000180000001800000018000000180000001800000018000000180183FFFFFFC000000000000000000000000;
   name[1] <=  1024'h000000000000000000020000000180000001C0000000C0000000803007FFFFF8040000300C0000600C0000400C0000000000030001FFFF8000018000000180000001800000018010000180383FFFFFFC0001800000018000000180000001800000018000000180000001800000018000003F8000000700000002000000000000;
   name[2] <=  1024'h00000000000000000100000001C080080180FFFC2188801C118D8810199B8E20099B1C000D9018000DA0181009A1FFF801C03000018464007FFE63000660C200066182100661FFF806600200066002000460020004620200046402080C6BFFFC0878020008700200186002001020020020000200200002004000020000000000;
end
//通道数组赋值
always@(posedge lcd_pclk)begin
   channel[0] <=  1024'h000000000000000000000040080FFFE00C0001E006008300070074000300380002101820001FFFF80018103000181030011810307F9FFFF003181030031810300318103003181030031FFFF00318103003181030031810300318103003181030031811F00C90006038600000703E000E200FFFF80000FFF00000000000000000;
   channel[1] <=  1024'h0000000000000000000001000C0301C0060181800301C3000300C20003008418003FFFFC0000300000003000010420407F87FFE0030600C0030600C00307FFC0030600C0030600C0030600C00307FFC0030600C0030600C0030600C00307FFC0048600C01846008030200000301C0000000FFFFC00007FF00000000000000000;
end
//汉字数组赋值 零到十 加：
always@(posedge lcd_pclk)begin
   hanzi[0]  <=   1024'h00000000000000000000008003FFFFC0000180000001800007FFFFF80C0180180C0180301801802019F99F80000100000000000003F91F800003800000078000000C4000003C300000731C0001C187F00E0080FC3000801003FFFE0000000F000000180000206000001E80000003C0000000F000000038000000180000000000;
   hanzi[1]  <=   1024'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000303FFFFFFC0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
   hanzi[2]  <=   1024'h0000000000000000000000000000000000000000000000000000000000000000000000C007FFFFE0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000383FFFFFFC0000000000000000000000000000000000000000;
   hanzi[3]  <=   1024'h000000000000000000000000000000000000000000000020000000700FFFFFF0000000000000000000000000000000000000000000000000000000000000018003FFFFC0000000000000000000000000000000000000000000000000000000000000000000000000000000187FFFFFFC00000000000000000000000000000000;
   hanzi[4]  <=   1024'h000000000000000000000000080000200FFFFFF00C0C30300C0C30300C0C30300C0C30300C0C30300C0C30300C0830300C0830300C0830300C1830300C1830300C1830300C1830300C1030300C3030300C203FB00C601FF00CC000300D8000300E0000300C0000300C0000300FFFFFF00C0000300C0000300C00002000000000;
   hanzi[5]  <=   1024'h000000000000000000000000000000600FFFFFF000030000000300000003000000020000000600000006000000060000000600000006010007FFFF8000040300000C0300000C0300000C0300000C0300000C0300000803000018030000180300001803000018030000180300001003183FFFFFFC000000000000000000000000;
   hanzi[6]  <=   1024'h0000000000000000000400000006000000030000000180000001C0000001C0000000C00000008000000000183FFFFFFC00000000000000000010000000182000001C1000003808000038040000300600006003000060018000C001C0018000E0018000F003000070060000700C00003018000030100000002000000000000000;
   hanzi[7]  <=   1024'h000000000000000000060000000700000006000000060000000600000006000000060000000600100006003C000601C000061E000007E000001E000001E600001E0600002006000000060000000600000006000800060008000600080006000800060008000600080003001C0003FFFC0001FFF8000000000000000000000000;
   hanzi[8]  <=   1024'h0000000000000000000000000000200000103000001C2000001C20000018300000183000001810000018100000181000001810000010180000301800003008000030080000300C0000600400006006000040060000C0030000C0030001800180010001C0030000E0060000F0040000780800003E100000102000000000000000;
   hanzi[9]  <=   1024'h000000000000000000080000000C0000000800000008000000080000001800000018000000180C001FFFFC0000180800001808000018080000180800001808000010080000300800003008000030080000200800006008000040080000C008080080080801000808030008080600080C0C000FFC10000FF82000000000000000;
   hanzi[10] <=   1024'h0000000000000000000100000001C0000001800000018000000180000001800000018000000180000001800000018000000180183FFFFFFC000180000001800000018000000180000001800000018000000180000001800000018000000180000001800000018000000180000001800000018000000180000001000000000000;
   hanzi[11] <=   1024'h0000000000000000000000000000000000000000000000000007E0000007E0000007E0000007E0000007E0000007E000000000000000000000000000000000000000000000000000000000000007E0000007E0000007E0000007E0000007E0000007E00000000000000000000000000000000000000000000000000000000000;
   end


//标题数组赋值
always@(posedge lcd_pclk)begin
    title[0] <= 2304'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003E0000000000F80000000001F00000000007E0000000000FFFFFFF80003FFFFFFF8000FFFFFFFF8003F800003F000FE00000FC003F840007F000FE1F001FC003F00F80FF0000C007C7F800000001FFE000000003FF000000003FF8FC000003FFC1F000007FFC07C00007FFE01FFFFFF3FC007FFFFFF1C001FFFFFFF00007F00003E0001FC0000FC000FF00003F0007F820007E003FC0F803F800FE007C0FE00030003E7F800000000FFE000000001FF800000001FFC00000001FFE0000000FFFE0000003FFFE00000001FFE000000000F0000000000000000000000000000000000000000000000000000000000;
    title[1] <= {
        256'h0000000000000000000000000000000000000000000000000000000000000000,
        256'h000000000000000000000000000000000000000000000000000600000000000F,
        256'h80000FFFF00F00000FFFF01E00000F00703FFFFE0F00703FFFFE0F007078003E,
        256'h0F0070FC007C0F0071FE00780F0071EF01F00F0073C783E00FFFF787C7C00FFF,
        256'hF103EF800F1C0001FF00001C0000FC00001C0003FF000E1C000FEFE00E1C003F,
        256'h83FE0E1C01FE00FF0E1FFFF8001F0E1FF7C000030E1C03FFFFFC0E1C00FFFFFC,
        256'h0E1C00FFFFFC0E1C00F0003C0E1C00F0003C0E1C00F0003C0E1C00F0003C0E1C,
        256'h78F0003C0E3FF8F0003C0FFFF8F0003C7FFF80FFFFFC7FE000FFFFFC380000FF,
        256'hFFFC000000F0003C000000F0003C000000000000000000000000000000000000
    };
    title[2] <= {
        256'h0000000000000000000000000000000000000000000000000000000000000000,
        256'h00000000000000000000000000000000000F00000000000F00000000000F01FF,
        256'hFFFF000F01FFFFFF0E0F00003C000E0F00003C000E0FFE007C000E0FFE007800,
        256'h0E0F000078000E0F007FFFFF0E0F007FFFFF0E0F0078000F0E0F0078000FFFFF,
        256'hFE783C0FFFFFFE783C0F000000783C0F000F00783C0F000F00783C0F060F0078,
        256'h3C0F0F0F04783C0F0E0F0F783C0F0E0F0E783C0F1C0F1C783C0F1C0F3C787C0F,
        256'h380F7878780F780F7078780F700FE078F80FF003C078FE0F20070001FF80001E,
        256'h0003C7F0007C000F81FC01F0003F007F07C000FC001F3F0007F0000FFC001FC0,
        256'h0003300006000000000000000000000000000000000000000000000000000000
    };
    title[3] <= {
        256'h0000000000000000000000000000000000000000000000000000000000000000,
        256'h00000000000000000000000000000000000000C00000000003E00000000001F0,
        256'h0000000000F800003FFFFFFFFFFF3FFFFFFFFFFF3FFFFFFFFFFF000001C00000,
        256'h000007C000000C000F01800C1F003C03E01F0F80F00F807E03E3FFFF01F801E1,
        256'hFFFC07E00041FFF00180000C00C08100003C0703C3C000FE1E01E3F003F8F000,
        256'hF0FC1FC7FFFFF83F7F03FFFFF80F3C03FFF03C07100000F01001000000F00000,
        256'h000000F000007FFFFFFFFFFF7FFFFFFFFFFF7FFFFFFFFFFF000000F000000000,
        256'h00F00000000000F00000000000F00000000000F00000000000F00000000000F0,
        256'h0000000000000000000000000000000000000000000000000000000000000000

    };
    title[4] <= {
        256'h0000000000000000000000000000000000000000000000000000000000000000,
        256'h0000000000000000000000000000000004000001E0000F000001E0000F800001,
        256'hE00007C00001E00003E00001E00001F00001E000007C0001E00000380001E000,
        256'h00100001E00000000001E00000000001E00000000001E00000000001E0007FF0,
        256'h7FFFFFFF7FF07FFFFFFF7FF07FFFFFFF00F00001E00000F00001E00000F00001,
        256'hE00000F00001E00000F00001E00000F00001E00000F00001E00000F00001E000,
        256'h00F00001E00000F00001E00000F00401E00000F03C01E00000F0FC01E00000F3,
        256'hF801E00000FFE001E00000FF0001E00001FC0001E00003F00001E00000800001,
        256'hE00000000001E000000000000000000000000000000000000000000000000000
    };
    
    
end 


//字符数组赋值
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
    char[12] <= 128'h00000000000000007E00000000000000; // "-"
    char[13] <= 128'h00000000000018000000180000000000; // ":"
    char[14] <= 128'h00000000000000000000000000000000; // " "  placeholder for invalid BCD
end




//================= 组合逻辑：区域检测 + 字模点位提取 =================
//注：下方的in_title这些判断都使用了无符号数的下溢特性 类似与定义一个位宽wire [10:0] = 无符号11位，范围0~2047
//50-230 = -180 -180 + 2048 = 1868 所以50-230的结果为1868



//32×32字模点位提取函数：font = 单个汉字位图，relx/rely = 字内相对坐标
//位索引计算公式：(高度 - rely)*32 - (relx对32取模) - 1
function hanzi_bit;
    input [1023:0] font;
    input [10:0]   relx;
    input [10:0]   rely;
    reg   [10:0]   rly ;
    reg   [10:0]   idx ;
    begin
        //越界保护：如果rely≥32，索引会变成负数/越界,前位为零
        rly = (rely < 11'd32) ? rely : 11'd0;
        //32等于2的5次方，使用移位代替乘法
        idx = ((11'd32 - rly) << 5) - relx[4:0] - 11'd1;
        hanzi_bit = font[idx];
    end
endfunction

//48×48字模点位提取函数：font = 单个汉字位图，relx/rely = 字内相对坐标
//位索引计算公式：(高度 - rely)*48 - (relx对48取模) - 1
function hanzi_bit_48;
    input [2303:0] font;
    input [10:0]   relx;
    input [10:0]   rely;
    reg   [10:0]   rlx ;
    reg   [10:0]   rly ;
    
    reg   [11:0]   idx ;//总共2304bit
    begin
        //越界保护：如果rely≥48，索引会变成负数/越界，前位为0
        rly = (rely < 11'd48) ? rely : 11'd0;
        rlx = (relx < 11'd48) ? relx : 11'd0;
       idx = (12'd48 -  rly) * 12'd48 -  rlx - 12'd1;
        hanzi_bit_48 = font[idx];
    end
endfunction
//================= 日期显示区域（8×16，两行） =================
//PCF8563输出 秒/分/时/日/月/年 是BCD码：十位、个位各占4bit
//第1行 "20YY-MM-DD" = 10个字符 = 80像素
//第2行 "hh:mm:ss"   =  8个字符 = 64像素
//BCD半字节 → 字模索引：0~9映射到数字，非法值(>9)显示空白，避免显示'H'/'z'
function [3:0] nib2idx;
    input [3:0] nib;
    begin
        nib2idx = (nib <= 4'd9) ? nib : 4'd14;
    end
endfunction

//---- 第1行：20YY-MM-DD ----
wire [10:0] d1_relx = pixel_xpos - (DATE_POS_X_1 - 11'd1);
wire [10:0] d1_rely = pixel_ypos - DATE_POS_Y_1;       //使用y坐标，不是pixel_xpos
wire        in_d1   = (d1_relx < DATE_WIDTH_1) && (d1_rely < 11'd16);
wire [3:0]  d1_col  = d1_relx[6:3];                    //字符编号 = relx / 8

reg [3:0] d1_ch;
always @(*) begin
    case (d1_col)
       4'd0:    d1_ch = 4'd2;                        //'2' （20YY的千位）
        4'd1:    d1_ch = 4'd0;                       //'0' （百位）
        4'd2:    d1_ch = nib2idx(year[7:4]);         //年份十位
        4'd3:    d1_ch = nib2idx(year[3:0]);         //年份个位
        4'd4:    d1_ch = 4'd12;                      //'-' 横杠
        4'd5:    d1_ch = nib2idx({3'b000, mon[4]});  //月份十位（BCD仅第4位有效）
        4'd6:    d1_ch = nib2idx(mon[3:0]);          //月份个位
        4'd7:    d1_ch = 4'd12;                      //'-' 横杠
        4'd8:    d1_ch = nib2idx({2'b00, day[5:4]}); //日期十位
        default: d1_ch = nib2idx(day[3:0]);          //日期个位
    endcase
end

//点位索引公式：(16 - rely)*8 - (relx % 8) - 1，和数字区域公式一致
wire [6:0] d1_bit = ((11'd16 - d1_rely) << 3) - d1_relx[2:0] - 7'd1;
wire       d1_pix = char[d1_ch][d1_bit];

//---- 第2行：hh:mm:ss ----
wire [10:0] d2_relx = pixel_xpos - (DATE_POS_X_2 - 11'd1);
wire [10:0] d2_rely = pixel_ypos - DATE_POS_Y_2;
wire        in_d2   = (d2_relx < DATE_WIDTH_2) && (d2_rely < 11'd16);
wire [3:0]  d2_col  = d2_relx[6:3];

reg [3:0] d2_ch;
always @(*) begin
    case (d2_col)
        4'd0:    d2_ch = nib2idx({2'b00, hour[5:4]});  //小时十位
        4'd1:    d2_ch = nib2idx(hour[3:0]);           //小时个位
        4'd2:    d2_ch = 4'd13;                      //':' 冒号
        4'd3:    d2_ch = nib2idx({1'b0, min[6:4]});    //分钟十位
        4'd4:    d2_ch = nib2idx(min[3:0]);            //分钟个位
        4'd5:    d2_ch = 4'd13;                      //':' 冒号
        4'd6:    d2_ch = nib2idx({1'b0, sec[6:4]});    //秒钟十位
        default: d2_ch = nib2idx(sec[3:0]);            //秒钟个位
    endcase
end

wire [6:0] d2_bit = ((11'd16 - d2_rely) << 3) - d2_relx[2:0] - 7'd1;
wire       d2_pix = char[d2_ch][d2_bit];

//---- 数字区域（8×16，一共11个字符） ----
wire [10:0] char_relx = pixel_xpos - (CHAR_POS_X - 11'd1);
wire [10:0] char_rely = pixel_ypos - CHAR_POS_Y;
wire        in_char   = (char_relx < CHAR_WIDTH) && (char_rely < CHAR_HEIGHT);

wire [3:0]  char_col  = char_relx[6:3];                 //字符序号 (0~10) = relx/8
//字符0~8 → 取自数据的BCD码（亿位~个位），字符9 → "H"（字模10），字符10 → "z"（字模11）
wire [3:0]  char_bcd  = data_all[(4'd8 - char_col)*4 +: 4];
wire [3:0]  char_idx  = (char_col <= 4'd8 && char_bcd <= 4'd9) ? char_bcd
                      : (char_col == 4'd9) ? 4'd10 : 4'd11;
//点位索引：(16 - rely)*8 - (relx % 8) - 1
wire [6:0]  char_bit_idx = ((CHAR_HEIGHT - char_rely) << 3) - char_relx[2:0] - 7'd1;
wire        char_pix  = char[char_idx][char_bit_idx];


//---- 名称区域（32×32，3个汉字） ----
wire [10:0] name_relx = pixel_xpos - (NAME_POS_X - 11'd1);
wire [10:0] name_rely = pixel_ypos - NAME_POS_Y;
wire        in_name   = (name_relx < NAME_WIDTH) && (name_rely < NAME_HEIGHT);
wire        name_pix  = hanzi_bit(name[name_relx[9:5]], name_relx, name_rely);

//---- 触摸坐标显示区域（16×32，9个字符）：格式 "XXXX YYYY"，高16位=X，低16位=Y ----
//touch_data 已经是BCD码（每4bit一位十进制数字）
wire [10:0] touch_relx = pixel_xpos - (TOUCH_POS_X - 11'd1);
wire [10:0] touch_rely = pixel_ypos - TOUCH_POS_Y;
wire        in_touch   = (touch_relx < TOUCH_WIDTH) && (touch_rely < TOUCH_HEIGHT);
wire [3:0]  tp_col  = touch_relx[8:4];              //字符序号 (0~8)，每个字符宽16像素
//第0~3列 = X坐标千位~个位（touch_data[31:16]），第4列 = 空格，第5~8列 = Y坐标千位~个位（touch_data[15:0]）
wire [3:0]  t_bcd   = (tp_col < 4'd4) ? touch_data[(4'd7 - tp_col)*4 +: 4]
                                     : touch_data[(4'd8 - tp_col)*4 +: 4];
wire        t_blank = (tp_col == 4'd4);             //X和Y中间的空格
wire [3:0]  t_idx   = (t_bcd <= 4'd9) ? t_bcd : 4'd0;
//点位索引：(32 - rely)*16 - relx%16 - 1
wire [9:0]  t_bit   = ((11'd32 - touch_rely) << 4) - touch_relx[3:0] - 10'd1;
wire        touch_pix = (!t_blank) && freqNumber[t_idx][t_bit];

//---- 标题区域（48×48，5个汉字） ----
//字符选择：48不是2的整数次幂，使用比较器累加代替除法
wire [10:0] title_relx = pixel_xpos - (TITLE_POS_X - 11'd1);
wire [10:0] title_rely = pixel_ypos - TITLE_POS_Y;
wire        in_title  = (title_relx < TITLE_WIDTH) && (title_rely < TITLE_HEIGHT);
wire [2:0]  t_col = (title_relx >= 11'd48)  + (title_relx >= 11'd96)
                  + (title_relx >= 11'd144) + (title_relx >= 11'd192);         
                  
//字模内坐标：t_bx = relx - t_col*48 = relx对48取模，传入提取函数
wire [10:0] t_bx = title_relx - t_col * 11'd48;
wire [10:0] t_by = title_rely;
reg [2303:0] t_font;
always @(*) begin
    case (t_col)                      //通过case选择字模，防止索引越界
        3'd0: t_font = title[0]; 
        3'd1: t_font = title[1];
        3'd2: t_font = title[2]; 
        3'd3: t_font = title[3];
        default: t_font = title[4];
    endcase
end
wire title_pix = hanzi_bit_48(t_font, t_bx, t_by);


//---- 上一页/下一页标识（32×32，3个字）：第1页显示下一页，第2页显示上一页
wire [10:0] up_down_relx =  pixel_xpos - (UP_DOWN_POS_X - 11'd1);  
wire [10:0] up_down_rely = pixel_ypos - UP_DOWN_POS_Y; 
wire        in_up_down  = (up_down_relx < UP_DOWN_WIDTH) && (up_down_rely < UP_DOWN_HEIGHT);    
wire [1:0]  up_done_col = up_down_relx[6:5];          //每个汉字32像素，一共3个字
wire [10:0] up_done_bx  = up_down_relx[4:0];          //字模内X坐标（0~31）
wire [10:0] up_done_by  = up_down_rely;               //字模内Y坐标（0~31）
reg  [1023:0]  up_done_font;

always@(*)begin
    case(up_done_col)
        2'd0: up_done_font = page ? up_down_page[1] : up_down_page[0]; //up/down
        2'd1: up_done_font = up_down_page[2];                          //one
        default: up_done_font = up_down_page[3];                       //page
    endcase
end                 
wire up_done_pix = hanzi_bit(up_done_font, up_done_bx, up_done_by);
//---- 通道区域（3列 × 3行）：每个通道在下方显示对应频率 ----
wire [10:0] ch_relx = pixel_xpos - (HANZI_POS_X - 11'd1);
wire [10:0] ch_rely = pixel_ypos - HANZI_POS_Y;
wire        in_ch   = (ch_relx < CH_PITCH_X * CH_COLS) && (ch_rely < CH_PITCH_Y * CH_ROWS);

//行号、列号用比较器求和实现，避免除法：列号 = (relx>=250) + (relx>=500)
wire [1:0]  ch_col  = (ch_relx >= CH_PITCH_X) + (ch_relx >= CH_PITCH_X * 11'd2);
wire [1:0]  ch_row  = (ch_rely >= CH_PITCH_Y) + (ch_rely >= CH_PITCH_Y * 11'd2);
//块内相对坐标
wire [10:0] ch_bx   = ch_relx - ((ch_col == 2'd1) ? CH_PITCH_X          :
                                 (ch_col == 2'd2) ? CH_PITCH_X * 11'd2 : 11'd0);
wire [10:0] ch_by   = ch_rely - ((ch_row == 2'd1) ? CH_PITCH_Y          :
                                 (ch_row == 2'd2) ? CH_PITCH_Y * 11'd2 : 11'd0);
//通道编号1~9 = 行×3 + 列 + 1，映射到汉字hanzi[1]=一 … hanzi[9]=九
wire [3:0]  ch_num  = (ch_row << 1) + ch_row + ch_col + 4'd1;

//"通道N"：第1页 = 通道一 ~ 通道九；第2页 = 通道十 ~ 通道十八，每个块末尾带一个全角冒号
//第1页：字0=通[0] 字1=道[1] 字2=hanzi[ch_num]
//第2页：字0=通[0] 字1=道[1] 字2=hanzi[10](十) 字3=(一~八；通道十用冒号) 字4=冒号
wire [2:0]     ch_word_p1 = ch_bx[7:5];                   //bx/32 → 0,1,2
//wire [1023:0]  ch_font_p1 = (ch_word_p1 == 2'd0) ? channel[0] :
//                            (ch_word_p1 == 2'd1) ? channel[1] : hanzi[ch_num];
wire [1023:0]  ch_font_p1 = (ch_word_p1 == 3'd0) ? channel[0] :
                            (ch_word_p1 == 3'd1) ? channel[1] : 
                            (ch_word_p1 == 3'd2) ? hanzi [ch_num] : hanzi[11];

wire [2:0]     ch_word_p2 = ch_bx[7:5];                   //bx/32 -> 0~4
wire [1023:0]  ch_font_p2 = (ch_word_p2 == 3'd0) ? channel[0] :
                            (ch_word_p2 == 3'd1) ? channel[1] :
                            (ch_word_p2 == 3'd2) ? hanzi [10]  :
                            (ch_word_p2 == 3'd3) ? 
                            ((ch_num == 4'd1) ? hanzi [11] : hanzi[ch_num - 4'd1])
                                                 : hanzi [11];

wire [1023:0]  ch_font  = page ? ch_font_p2 : ch_font_p1;
//标签宽度：第2页“通道十一：”占5个字（160像素），通道十只占4个字
wire [10:0]    ch_lab_w = !page             ? HANZI_WIDTH :
                          (ch_num == 4'd1)  ? 11'd128 : 11'd160;
wire           ch_hz_pix = hanzi_bit(ch_font, ch_bx, ch_by);
wire           in_ch_hz  = in_ch && (ch_bx < ch_lab_w) && (ch_by < HANZI_HEIGHT);

//频率字符区域：每个通道在汉字下方显示频率数值
//通道索引：第1页 0~8，第2页 9~17
wire [4:0]  ch_idx   = (ch_row << 1) + ch_row + ch_col + (page ? 5'd9 : 5'd0);
//只有通道编号 < CH_NUM 才显示频率，未启用通道不绘制
wire        in_ch_freq = in_ch && (ch_idx < CH_NUM)
                      && (ch_bx < CH_FREQ_W)
                      && (ch_by >= CH_FREQ_OFF_Y)
                      && (ch_by <  CH_FREQ_OFF_Y + CH_FREQ_H);
wire [10:0] ch_fx    = ch_bx;                            //字符区域内X坐标 (0~175)
wire [10:0] ch_fy    = ch_by - CH_FREQ_OFF_Y;            //字符区域内Y坐标 (0~31)
wire [3:0]  ch_fcol  = ch_fx[8:4];                       //除以16 → 字符序号(0~10)
//选中当前通道的BCD数据
wire [35:0] ch_data  = data_all[ch_idx*36 +: 36]; //data_all[ ch_idx*36 + 35 : ch_idx*36 ]
wire [3:0]  ch_bcd   = ch_data[(4'd8 - ch_fcol) * 4 +: 4];  //9位BCD，第0位是最高位
wire [3:0]  ch_fidx  = (ch_fcol <= 4'd8 && ch_bcd <= 4'd9) ? ch_bcd
                     : (ch_fcol == 4'd9) ? 4'd10 : 4'd11; //第9号字符->"H",第10号->"z"
//点位索引：(32 - fy)*16 - fx%16 - 1
wire [9:0]  ch_fbit  = ((11'd32 - ch_fy) << 4) - ch_fx[3:0] - 10'd1;
wire        ch_freq_pix = freqNumber[ch_fidx][ch_fbit];

//边框绘制

wire in_top    = (pixel_ypos >=  BORDER_BLUE_START_Y_TOP)  && (pixel_ypos < BORDER_BLUE_END_Y_TOP)  && 
                 (pixel_xpos >=  BORDER_BLUE_START_X_TOP) && (pixel_xpos  < BORDER_BLUE_END_X_TOP);
wire in_bottom = (pixel_ypos >=  BORDER_BLUE_START_Y_BOTTOM) && (pixel_ypos <BORDER_BLUE_END_Y_BOTTOM) 
              && (pixel_xpos >=  BORDER_BLUE_START_X_BOTTOM) && (pixel_xpos <BORDER_BLUE_END_X_BOTTOM);
wire in_left   = (pixel_xpos >=  BORDER_BLUE_START_X_LEFT)   && (pixel_xpos <BORDER_BLUE_END_X_LEFT)  
              && (pixel_ypos >=  BORDER_BLUE_START_Y_LEFT) &&   (pixel_ypos <BORDER_BLUE_END_Y_LEFT);
wire in_right  = (pixel_xpos >=  BORDER_BLUE_START_X_RIGHT) && (pixel_xpos <BORDER_BLUE_END_X_RIGHT) 
              && (pixel_ypos >=  BORDER_BLUE_START_Y_RIGHT) && (pixel_ypos <BORDER_BLUE_END_Y_RIGHT);
wire in_border = in_top || in_bottom || in_left || in_right;                    
                    
//wire in_border = border_relx & border_rely;
                    
//================= 时序逻辑：像素数据输出 =================
always @(posedge lcd_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        pixel_data <= WHITE;
  //  else if (in_char ) pixel_data <= char_pix  ? BLACK : WHITE;
    else if (in_d1   ) pixel_data <= d1_pix   ? BLACK : WHITE;   //日期第1行：20YY-MM-DD
    else if (in_d2   ) pixel_data <= d2_pix   ? BLACK : WHITE;   //日期第2行：hh:mm:ss
    else if (in_touch) pixel_data <= touch_pix ? BLACK : WHITE;
   // else if (in_name ) pixel_data <= name_pix  ? BLACK : WHITE;
    else if (in_up_down) pixel_data <= up_done_pix ? BLACK : LIGHTGRAY;
    else if (in_title) pixel_data <= title_pix ? BLACK : WHITE;
    else if (in_ch_freq) pixel_data <= ch_freq_pix ? BLACK : WHITE;
    else if (in_ch_hz  ) pixel_data <= ch_hz_pix   ? BLACK : WHITE;
    else if (in_border)  pixel_data <= BLUE;
    else                 pixel_data <= WHITE;
end

endmodule

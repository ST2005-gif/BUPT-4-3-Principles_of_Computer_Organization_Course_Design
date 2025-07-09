module ver1 (
        //输入端口
        input wire [2:0] SWC_SWB_SWA,      // 模式选择信号
        input wire [3:0] IR7_IR4,          // 指令寄存器高4位
        input wire CLR,                    // 复位信号 (低有效)
        input wire T3,                     // 时序信号 T3 (作为ST0的时钟)          // 微指令时序信号
        input wire C, Z,                   // 状态标志：进位C，零Z
        //输出端口
        output reg SELCTL,                 // 选择控制信号
        output reg ABUS,                   // 控制ALU数据是否进入数据总线
        output reg SBUS,                   // 控制手动输入数据是否进入数据总线
        output reg MBUS,                   // 控制双端口存储器的数据送到数据总线
        output reg M,CIN,                  // M是控制ALU是逻辑运算还是算数运算 CIN用于区分S码和M对应的操作是有进位操作或是无进位操作
        output reg DRW,                    // 控制寄存器写入信号
        output reg LDZ,                    // 若为1，当运算结果为0时设Z为1，若不为0则设Z为0
        output reg LDC,                    // 若为1，当运算结果产生进位时设C为1，若无进位则设C为0
        output reg MEMW,                   // 控制存储器双端口RAM写入信号，为1时将总线中的值写入储存器
        output reg ARINC,                  // 控制地址寄存器AR的值加1信号
        output reg PCINC,                  // 控制地址寄存器PC的值加1信号
        output reg PCADD,                  // 控制PC加指令地址信号
        output reg LPC,                    // 控制将数据总线上数据写入PC寄存器
        output reg LAR,                    // 控制将数据总线上数据写入AR寄存器
        output reg LIR,                    // 控制将数据总线上数据写入IR寄存器
        output reg STOP,                   // 停止信号
        output reg SHORT,                  // 短延时信号
        output reg LONG,                   // 长延时信号
        output reg [3:0] S, SEL            // S控制ALU产生不同的函数 SEL用于 2 - 4 译码器
    );
    reg W1, W2, W3;
    reg ST0;                   // 内部状态触发器 (由T3下降沿触发)
    wire SST0;                  // ST0置位的条件 (组合逻辑)
    reg need_long_cycle;
    // ST0 状态触发器逻辑
    // 行为: 当CLR为0时，ST0异步复位为0。
    //       否则，在T3下降沿，如果SST0为1，则ST0置为1。
    //       ST0一旦为1，将保持为1，直到下一次CLR复位。

    always @(negedge T3 or negedge CLR) begin
        if (!CLR) begin
            ST0 <= 1'b0;
            W1 <= 1'b1;
            W2 <= 1'b0;
            W3 <= 1'b0;
            need_long_cycle <= 1'b0;
        end
        else begin
            if (SST0)
                ST0 <= 1'b1;
            if(SWC_SWB_SWA == 3'b100 && ST0 && W2) begin
                ST0<=1'b0;
            end
            // 状态机转换逻辑
            case ({W1, W2, W3})
                3'b100: begin // W1=1, W2=0, W3=0 (状态1)
                    W1 <= 1'b0;
                    W2 <= 1'b1;
                    W3 <= 1'b0;
                    // 在这里判断是否需要长周期，基于指令类型
                    need_long_cycle <= (IR7_IR4 == 4'b0101) || (IR7_IR4 == 4'b0110); // LD 或 ST 指令
                end
                3'b010: begin // W1=0, W2=1, W3=0 (状态2)
                    if (need_long_cycle) begin
                        W1 <= 1'b0;
                        W2 <= 1'b0;
                        W3 <= 1'b1;
                    end
                    else begin
                        W1 <= 1'b1;
                        W2 <= 1'b0;
                        W3 <= 1'b0;
                    end
                end
                3'b001: begin // W1=0, W2=0, W3=1 (状态3)
                    W1 <= 1'b1;
                    W2 <= 1'b0;
                    W3 <= 1'b0;
                end
                default: begin // 默认状态
                    W1 <= 1'b1;
                    W2 <= 1'b0;
                    W3 <= 1'b0;
                end
            endcase
        end
    end

    // 组合逻辑部分：计算控制输出和 ST0 的置位条件
    always @(W1,W2,W3) begin
        // 默认所有输出信号为低/无效

        case (SWC_SWB_SWA)
            3'b100: begin // 写寄存器模式
                if (ST0 == 1'b0) begin // 状态0 (第一拍)
                    if (W1) begin
                        SBUS <= 1'b1;
                        SEL <= 4'b0011;
                        SELCTL <= 1'b1;
                        DRW <= 1'b1;
                        STOP <= 1'b1;
                    end
                    if (W2) begin // W2 触发进入状态1
                        SBUS <= 1'b1;
                        SEL <= 4'b0100;
                        SELCTL <= 1'b1;
                        DRW <= 1'b1;
                        STOP <= 1'b1;
                    end
                end
                else begin // ST0 == 1'b1 (状态1, 第二拍)
                    if (W1) begin // 假设W1在第二拍也有意义
                        SBUS <= 1'b1;
                        SEL <= 4'b1001;
                        SELCTL <= 1'b1;
                        DRW <= 1'b1;
                        STOP <= 1'b1;
                    end
                    if (W2) begin // 假设W2在第二拍也有意义
                        SBUS <= 1'b1;
                        SEL <= 4'b1110;
                        SELCTL <= 1'b1;
                        DRW <= 1'b1;
                        STOP <= 1'b1;
                    end
                end
                ARINC <= 1'b0;
                CIN <= 1'b0;

                LPC <= 1'b0;
                LAR <= 1'b0;
                LIR <= 1'b0;
                LDZ <= 1'b0;
                LDC <= 1'b0;
                PCINC <= 1'b0;
                PCADD <= 1'b0;

                M <= 1'b0;
                MEMW <= 1'b0;

                SHORT <= 1'b0;
                LONG <= 1'b0;
                ABUS <= 1'b0;

                MBUS <= 1'b0;
                S <= 4'b0000;

            end

            3'b011: begin // 读寄存器模式 (单拍)
                if (W1) begin
                    SEL <= 4'b0001;
                    SELCTL <= 1'b1;
                    STOP <= 1'b1;

                    ARINC <= 1'b0;
                    CIN <= 1'b0;
                    DRW <= 1'b0;
                    LPC <= 1'b0;
                    LAR <= 1'b0;
                    LIR <= 1'b0;
                    LDZ <= 1'b0;
                    LDC <= 1'b0;
                    PCINC <= 1'b0;
                    PCADD <= 1'b0;

                    M <= 1'b0;
                    MEMW <= 1'b0;

                    SHORT <= 1'b0;
                    LONG <= 1'b0;
                    ABUS <= 1'b0;
                    SBUS <= 1'b0;
                    MBUS <= 1'b0;
                    S <= 4'b0000;

                end
                if (W2) begin
                    SEL <= 4'b1011;
                    SELCTL <= 1'b1;
                    STOP <= 1'b1;

                    ARINC <= 1'b0;
                    CIN <= 1'b0;
                    DRW <= 1'b0;
                    LPC <= 1'b0;
                    LAR <= 1'b0;
                    LIR <= 1'b0;
                    LDZ <= 1'b0;
                    LDC <= 1'b0;
                    PCINC <= 1'b0;
                    PCADD <= 1'b0;

                    M <= 1'b0;
                    MEMW <= 1'b0;

                    SHORT <= 1'b0;
                    LONG <= 1'b0;
                    ABUS <= 1'b0;
                    SBUS <= 1'b0;
                    MBUS <= 1'b0;
                    S <= 4'b0000;

                end
            end

            3'b010: begin // 读存储器模式
                if (ST0 == 1'b0) begin // 状态0 (第一拍，送地址)
                    if (W1) begin // W1 触发进入状态1
                        SBUS <= 1'b1;    // 假设地址源于SBUS (例如PC或立即数)
                        LAR <= 1'b1;     // 地址送MAR
                        STOP <= 1'b1;
                        SHORT <= 1'b1;   // 可能是地址长度控制
                        SELCTL <= 1'b1;  // 可能是选择SBUS的控制

                        ARINC <= 1'b0;
                        CIN <= 1'b0;
                        DRW <= 1'b0;
                        LPC <= 1'b0;

                        LIR <= 1'b0;
                        LDZ <= 1'b0;
                        LDC <= 1'b0;
                        PCINC <= 1'b0;
                        PCADD <= 1'b0;

                        M <= 1'b0;
                        MEMW <= 1'b0;


                        LONG <= 1'b0;
                        ABUS <= 1'b0;

                        MBUS <= 1'b0;
                        S <= 4'b0000;
                        SEL <= 4'b0000;
                    end
                end
                else begin // ST0 == 1'b1 (状态1, 第二拍，读数据)
                    if (W1) begin // 假设W1在第二拍也有意义 (或应为W2/W3?)
                        MBUS <= 1'b1;    // 数据从内存总线来
                        ARINC <= 1'b1;   // 数据送AR并自增 (AR通常是累加器或数据缓冲)
                        STOP <= 1'b1;
                        SHORT <= 1'b1;
                        SELCTL <= 1'b1;  // 可能是选择MBUS的控制


                        CIN <= 1'b0;
                        DRW <= 1'b0;
                        LPC <= 1'b0;
                        LAR <= 1'b0;
                        LIR <= 1'b0;
                        LDZ <= 1'b0;
                        LDC <= 1'b0;
                        PCINC <= 1'b0;
                        PCADD <= 1'b0;

                        M <= 1'b0;
                        MEMW <= 1'b0;


                        LONG <= 1'b0;
                        ABUS <= 1'b0;
                        SBUS <= 1'b0;

                        S <= 4'b0000;
                        SEL <= 4'b0000;
                    end
                end
            end

            3'b001: begin // 写存储器模式
                if (ST0 == 1'b0) begin // 状态0 (第一拍，送地址)
                    if (W1) begin // W1 触发进入状态1
                        SBUS <= 1'b1;    // 假设地址源于SBUS
                        LAR <= 1'b1;     // 地址送MAR
                        STOP <= 1'b1;
                        SHORT <= 1'b1;
                        SELCTL <= 1'b1;

                        ARINC <= 1'b0;
                        CIN <= 1'b0;
                        DRW <= 1'b0;
                        LPC <= 1'b0;

                        LIR <= 1'b0;
                        LDZ <= 1'b0;
                        LDC <= 1'b0;
                        PCINC <= 1'b0;
                        PCADD <= 1'b0;

                        M <= 1'b0;
                        MEMW <= 1'b0;


                        LONG <= 1'b0;
                        ABUS <= 1'b0;

                        MBUS <= 1'b0;
                        S <= 4'b0000;
                        SEL <= 4'b0000;
                    end
                end
                else begin // ST0 == 1'b1 (状态1, 第二拍，写数据)
                    if (W1) begin // 假设W1在第二拍也有意义 (或应为W2/W3?)
                        SBUS <= 1'b1;    // 数据源于SBUS (例如DR)
                        MEMW <= 1'b1;    // 内存写使能
                        ARINC <= 1'b1;   // 可能是写完后对某个寄存器操作，或者此信号在此处用途不同
                        STOP <= 1'b1;
                        SHORT <= 1'b1;
                        SELCTL <= 1'b1;


                        CIN <= 1'b0;
                        DRW <= 1'b0;
                        LPC <= 1'b0;
                        LAR <= 1'b0;
                        LIR <= 1'b0;
                        LDZ <= 1'b0;
                        LDC <= 1'b0;
                        PCINC <= 1'b0;
                        PCADD <= 1'b0;

                        M <= 1'b0;



                        LONG <= 1'b0;
                        ABUS <= 1'b0;

                        MBUS <= 1'b0;
                        S <= 4'b0000;
                        SEL <= 4'b0000;
                    end
                end
            end

            3'b000: begin // 取指令/执行指令模式
                if (ST0 == 1'b0) begin //
                    if(W1) begin
                        STOP <= 1'b1; // 指令周期结束

                        ARINC <= 1'b0;
                        CIN <= 1'b0;
                        DRW <= 1'b0;
                        LPC <= 1'b0;
                        LAR <= 1'b0;
                        LIR <= 1'b0;
                        LDZ <= 1'b0;
                        LDC <= 1'b0;
                        PCINC <= 1'b0;
                        PCADD <= 1'b0;
                        SELCTL <= 1'b0;
                        M <= 1'b0;
                        MEMW <= 1'b0;

                        SHORT <= 1'b0;
                        LONG <= 1'b0;
                        ABUS <= 1'b0;
                        SBUS <= 1'b0;
                        MBUS <= 1'b0;
                        S <= 4'b0000;
                        SEL <= 4'b0000;
                    end
                    if(W2) begin
                        SBUS <= 1'b1; // 假设指令源于SBUS (例如PC或立即数)
                        LPC <= 1'b1;  // 指令送PC

                        ARINC <= 1'b0;
                        CIN <= 1'b0;
                        DRW <= 1'b0;

                        LAR <= 1'b0;
                        LIR <= 1'b0;
                        LDZ <= 1'b0;
                        LDC <= 1'b0;
                        PCINC <= 1'b0;
                        PCADD <= 1'b0;
                        SELCTL <= 1'b0;
                        M <= 1'b0;
                        MEMW <= 1'b0;
                        STOP <= 1'b0;
                        SHORT <= 1'b0;
                        LONG <= 1'b0;
                        ABUS <= 1'b0;

                        MBUS <= 1'b0;
                        S <= 4'b0000;
                        SEL <= 4'b0000;
                    end
                end
                else begin
                    if (W1) begin // W1 通常是取指令周期
                        LIR <= 1'b1;     // 指令装入IR
                        PCINC <= 1'b1;   // PC自增

                        ARINC <= 1'b0;
                        CIN <= 1'b0;
                        DRW <= 1'b0;
                        LPC <= 1'b0;
                        LAR <= 1'b0;

                        LDZ <= 1'b0;
                        LDC <= 1'b0;

                        PCADD <= 1'b0;
                        SELCTL <= 1'b0;
                        M <= 1'b0;
                        MEMW <= 1'b0;
                        STOP <= 1'b0;
                        SHORT <= 1'b0;
                        LONG <= 1'b0;
                        ABUS <= 1'b0;
                        SBUS <= 1'b0;
                        MBUS <= 1'b0;
                        S <= 4'b0000;
                        SEL <= 4'b0000;
                    end
                    // 根据指令操作码 IR7_IR4 执行 (通常在 W2, W3 等后续周期)
                    case (IR7_IR4)
                        4'b0001: begin // ADD指令
                            if (W2) begin
                                S <= 4'b1001;    // ALU功能: A+B
                                CIN <= 1'b1;     // 初始进位（若需要，通常ADD不设初始进位除非是ADC）
                                // 这里 CIN<=1 可能表示 A+B+1 或 ALU 结构需要
                                ABUS <= 1'b1;    // A总线有效 (一个操作数来自A总线)
                                DRW <= 1'b1;     // 结果写入数据寄存器DR
                                LDZ <= 1'b1;     // 更新零标志
                                LDC <= 1'b1;     // 更新进位标志

                                ARINC <= 1'b0;


                                LPC <= 1'b0;
                                LAR <= 1'b0;
                                LIR <= 1'b0;


                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;
                                M <= 1'b0;
                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;
                                LONG <= 1'b0;

                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                        end
                        4'b0010: begin // SUB指令
                            if (W2) begin
                                S <= 4'b0110;    // ALU功能: A-B (通常A+~B+1)
                                ABUS <= 1'b1;
                                DRW <= 1'b1;
                                LDZ <= 1'b1;
                                LDC <= 1'b1;     // 更新借位/进位标志

                                ARINC <= 1'b0;
                                CIN <= 1'b0;

                                LPC <= 1'b0;
                                LAR <= 1'b0;
                                LIR <= 1'b0;


                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;
                                M <= 1'b0;
                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;
                                LONG <= 1'b0;

                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                        end
                        4'b0011: begin // AND指令
                            if (W2) begin
                                M <= 1'b1;       // M<=1 通常表示逻辑运算
                                S <= 4'b1011;    // ALU功能: A AND B
                                ABUS <= 1'b1;
                                DRW <= 1'b1;
                                LDZ <= 1'b1;
                                // LDC 通常不为AND更新，除非设计特殊

                                ARINC <= 1'b0;
                                CIN <= 1'b0;

                                LPC <= 1'b0;
                                LAR <= 1'b0;
                                LIR <= 1'b0;

                                LDC <= 1'b0;
                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;

                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;
                                LONG <= 1'b0;

                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                        end
                        4'b0100: begin // INC指令 (假设是对A总线上的数据INC)
                            if (W2) begin
                                S <= 4'b0000;    // ALU功能: A (配合CIN<=1可以实现A+1, 或者ALU有专用INC)
                                // 如果S<=0000是传送A, 那么需要CIN<=1来实现A+1
                                // 如果ALU本身有INC A的操作码S，则CIN可能不需要
                                // 假设 S<=0000, CIN<=1 -> A+1 (或者S设计为INC)
                                ABUS <= 1'b1;    // A总线有效
                                DRW <= 1'b1;
                                LDZ <= 1'b1;
                                LDC <= 1'b1;     // INC会影响进位

                                ARINC <= 1'b0;
                                CIN <= 1'b0;

                                LPC <= 1'b0;
                                LAR <= 1'b0;
                                LIR <= 1'b0;


                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;
                                M <= 1'b0;
                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;
                                LONG <= 1'b0;

                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                        end
                        4'b0101: begin // LD指令 (从内存加载数据)
                            if (W2) begin // W2: 送地址到MAR
                                M <= 1'b1;       // 逻辑运算 (可能是地址计算的一部分或选择通路)
                                S <= 4'b1010;    // ALU功能 (可能是地址计算或传送)
                                ABUS <= 1'b1;    // A总线有效 (地址的一部分)
                                LAR <= 1'b1;     // 地址装入MAR
                                LONG <= 1'b1;    // 长地址模式

                                ARINC <= 1'b0;
                                CIN <= 1'b0;
                                DRW <= 1'b0;
                                LPC <= 1'b0;

                                LIR <= 1'b0;
                                LDZ <= 1'b0;
                                LDC <= 1'b0;
                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;

                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;


                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                            if (W3) begin // W3: 从内存读数据到DR
                                DRW <= 1'b1;     // 结果写入DR
                                MBUS <= 1'b1;    // 数据来自内存总线

                                ARINC <= 1'b0;
                                CIN <= 1'b0;

                                LPC <= 1'b0;
                                LAR <= 1'b0;
                                LIR <= 1'b0;
                                LDZ <= 1'b0;
                                LDC <= 1'b0;
                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;
                                M <= 1'b0;
                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;
                                LONG <= 1'b0;
                                ABUS <= 1'b0;
                                SBUS <= 1'b0;

                                S <= 4'b0000;
                                SEL <= 4'b0000;
                            end
                        end
                        4'b0110: begin // ST指令 (数据存到内存)
                            if (W2) begin // W2: 送地址到MAR
                                M <= 1'b1;
                                S <= 4'b1111;    // ALU功能 (可能是地址计算或传送)
                                ABUS <= 1'b1;
                                LAR <= 1'b1;
                                LONG <= 1'b1;

                                ARINC <= 1'b0;
                                CIN <= 1'b0;
                                DRW <= 1'b0;
                                LPC <= 1'b0;

                                LIR <= 1'b0;
                                LDZ <= 1'b0;
                                LDC <= 1'b0;
                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;

                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;


                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                            if (W3) begin // W3: 数据写入内存
                                S <= 4'b1010;    // ALU功能 (可能是将DR内容传送到数据总线)
                                // 或者选择数据源 (如DR) 到 SBUS
                                M <= 1'b1;
                                ABUS <= 1'b1;    // 如果数据源自ABUS (例如寄存器内容)
                                // 如果数据源自DR，则可能是SBUS <= 1'b1; 且SEL选择DR
                                MEMW <= 1'b1;    // 内存写使能

                                ARINC <= 1'b0;
                                CIN <= 1'b0;
                                DRW <= 1'b0;
                                LPC <= 1'b0;
                                LAR <= 1'b0;
                                LIR <= 1'b0;
                                LDZ <= 1'b0;
                                LDC <= 1'b0;
                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;


                                STOP <= 1'b0;
                                SHORT <= 1'b0;
                                LONG <= 1'b0;

                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                        end
                        4'b0111: begin // JC指令 (条件转移，若C<=1)
                            if (W2) begin
                                if (C) begin
                                    PCADD <= 1'b1; // PC装入地址 (来自总线或立即数)

                                    ARINC <= 1'b0;
                                    CIN <= 1'b0;
                                    DRW <= 1'b0;
                                    LPC <= 1'b0;
                                    LAR <= 1'b0;
                                    LIR <= 1'b0;
                                    LDZ <= 1'b0;
                                    LDC <= 1'b0;
                                    PCINC <= 1'b0;

                                    SELCTL <= 1'b0;
                                    M <= 1'b0;
                                    MEMW <= 1'b0;
                                    STOP <= 1'b0;
                                    SHORT <= 1'b0;
                                    LONG <= 1'b0;
                                    ABUS <= 1'b0;
                                    SBUS <= 1'b0;
                                    MBUS <= 1'b0;
                                    S <= 4'b0000;
                                    SEL <= 4'b0000;
                                end
                            end
                        end
                        4'b1000: begin // JZ指令 (条件转移，若Z<=1)
                            if (W2) begin
                                if (Z) begin
                                    PCADD <= 1'b1;

                                    ARINC <= 1'b0;
                                    CIN <= 1'b0;
                                    DRW <= 1'b0;
                                    LPC <= 1'b0;
                                    LAR <= 1'b0;
                                    LIR <= 1'b0;
                                    LDZ <= 1'b0;
                                    LDC <= 1'b0;
                                    PCINC <= 1'b0;

                                    SELCTL <= 1'b0;
                                    M <= 1'b0;
                                    MEMW <= 1'b0;
                                    STOP <= 1'b0;
                                    SHORT <= 1'b0;
                                    LONG <= 1'b0;
                                    ABUS <= 1'b0;
                                    SBUS <= 1'b0;
                                    MBUS <= 1'b0;
                                    S <= 4'b0000;
                                    SEL <= 4'b0000;
                                end
                            end
                        end
                        4'b1001: begin // JMP指令 (无条件转移)
                            if (W2) begin
                                M <= 1'b1;
                                S <= 4'b1111;    // ALU功能 (可能是传送地址)
                                ABUS <= 1'b1;    // 地址来自A总线 (例如，立即数或寄存器内容)
                                LPC <= 1'b1;     // 地址装入PC

                                ARINC <= 1'b0;
                                CIN <= 1'b0;
                                DRW <= 1'b0;

                                LAR <= 1'b0;
                                LIR <= 1'b0;
                                LDZ <= 1'b0;
                                LDC <= 1'b0;
                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;

                                MEMW <= 1'b0;
                                STOP <= 1'b0;
                                SHORT <= 1'b0;
                                LONG <= 1'b0;

                                SBUS <= 1'b0;
                                MBUS <= 1'b0;

                                SEL <= 4'b0000;
                            end
                        end
                        4'b1110: begin // STP指令 (停机)
                            if (W2) begin
                                STOP <= 1'b1;

                                ARINC <= 1'b0;
                                CIN <= 1'b0;
                                DRW <= 1'b0;
                                LPC <= 1'b0;
                                LAR <= 1'b0;
                                LIR <= 1'b0;
                                LDZ <= 1'b0;
                                LDC <= 1'b0;
                                PCINC <= 1'b0;
                                PCADD <= 1'b0;
                                SELCTL <= 1'b0;
                                M <= 1'b0;
                                MEMW <= 1'b0;

                                SHORT <= 1'b0;
                                LONG <= 1'b0;
                                ABUS <= 1'b0;
                                SBUS <= 1'b0;
                                MBUS <= 1'b0;
                                S <= 4'b0000;
                                SEL <= 4'b0000;
                            end
                        end
                        //以下为拓展指令
                        4'b1010: begin // OUT指令 (将B的值输出)
                            if (W2) begin
                                M <= 1'b1;
                                S <= 4'b1010;    // ALU功能 (可能是传送数据)
                                ABUS <= 1'b1;    // 数据来自A总线 (例如，寄存器内容)
                            end
                        end
                        4'b1011: begin // MOV指令 (将A的值设置为B)
                            if (W2) begin
                                M <= 1'b1;
                                S <= 4'b1010;    // ALU功能: A (通常表示传送)
                                ABUS <= 1'b1;
                                DRW <= 1'b1;
                            end
                        end
                        4'b1100: begin // CMP指令 (A-B, 设置标志)
                            if(W2) begin
                                S <= 4'b0110;
                                ABUS <= 1'b1;
                                LDZ <= 1'b1;
                                LDC <= 1'b1;
                            end
                        end
                        4'b1101: begin // NOT指令 (将A取反，结果保存在A中)
                            if(W2) begin
                                M <= 1'b1;
                                S <= 4'b0000;
                                ABUS <= 1'b1;
                                DRW <= 1'b1;
                                LDC <= 1'b1;
                            end
                        end
                        4'b1111: begin // DEC指令（A-1, 结果保存在A中）
                            if(W2) begin
                                S <= 4'b1111;
                                CIN <= 1'b1;
                                ABUS <= 1'b1;
                                DRW <= 1'b1;
                                LDZ <= 1'b1;
                                LDC <= 1'b1;     // INC会影响进位
                            end
                        end
                        //拓展指令结束
                        default: begin
                            // 可选：处理未定义指令，例如置STOP<=1
                        end
                    endcase
                end
            end
            default: begin // 未定义的SWC_SWB_SWA模式
                ARINC <= 1'b0;
                CIN <= 1'b0;
                DRW <= 1'b0;
                LPC <= 1'b0;
                LAR <= 1'b0;
                LIR <= 1'b0;
                LDZ <= 1'b0;
                LDC <= 1'b0;
                PCINC <= 1'b0;
                PCADD <= 1'b0;
                SELCTL <= 1'b0;
                M <= 1'b0;
                MEMW <= 1'b0;
                STOP <= 1'b0;
                SHORT <= 1'b0;
                LONG <= 1'b0;
                ABUS <= 1'b0;
                SBUS <= 1'b0;
                MBUS <= 1'b0;
                S <= 4'b0000;
                SEL <= 4'b0000;
            end
        endcase
    end

    assign SST0 = (ST0 == 1'b0) && (
               (SWC_SWB_SWA == 3'b100 && W2) || // 写寄存器模式，W2有效
               (SWC_SWB_SWA == 3'b010 && W1) || // 读存储器模式，W1有效
               (SWC_SWB_SWA == 3'b001 && W1) || // 写存储器模式，W1有效
               (SWC_SWB_SWA == 3'b000 && W2)
           );
endmodule

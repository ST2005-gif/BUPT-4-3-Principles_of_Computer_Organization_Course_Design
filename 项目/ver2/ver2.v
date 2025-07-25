module ver2 (
        //输入端口
        input wire [2:0] SWC_SWB_SWA,      // 模式选择信号
        input wire [3:0] IR7_IR4
,          // 指令寄存器高4位
        input wire CLR,                    // 复位信号 (低有效)
        input wire T3,                     // 时序信号 T3 (作为ST0的时钟)
        input wire W1, W2, W3,             // 微指令时序信号
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
    //状态标识
    // 内部信号声明
    reg ST0;
    wire WRITE_REG, READ_REG, INS_FETCH, WRITE_MEM, READ_MEM;
    wire ADD, SUB, AND, INC, LD, ST, JC, JZ, JMP, STP;
    wire NOP, OUT, NOT, CMP, MOV, DEC;
    reg [3:1] W; // 用于存储W信号的状态
    wire short_command;
    wire long_command;

    // 在解码阶段确定指令长度
    assign short_command = (NOP || ADD || SUB || AND || INC || (JC && !C) ||
                         (JZ && !Z) || OUT || NOT || CMP || MOV || DEC ||
                         READ_MEM || WRITE_MEM);

    assign long_command = 1'b0;

    // T3下降沿计数器逻辑
    always @(negedge T3 or negedge CLR) begin
        if (!CLR) begin
            W[1] <= 1'b1;
            W[2] <= 1'b0;
            W[3] <= 1'b0;
        end
        else begin
            if(W[1]) begin
                if(short_command) begin
                    W[1] <= 1'b1;
                    W[2] <= 1'b0;
                    W[3] <= 1'b0;
                end
                else begin
                    W[1] <= 1'b0;
                    W[2] <= 1'b1;
                    W[3] <= 1'b0;
                end
            end
            else if(W[2]) begin
                if(long_command) begin
                    W[1] <= 1'b0;
                    W[2] <= 1'b0;
                    W[3] <= 1'b1;
                end
                else begin
                    W[1] <= 1'b1;
                    W[2] <= 1'b0;
                    W[3] <= 1'b0;
                end
            end
            else if(W[3]) begin
                W[1] <= 1'b1;
                W[2] <= 1'b0;
                W[3] <= 1'b0; // 重置为初始状态
            end
        end
    end

    // ST0状态机 - 指令执行状态
    always @(negedge T3 or negedge CLR) begin
        if (!CLR) begin
            ST0 <= 1'b0;
        end
        else begin
            if (!ST0 && ((WRITE_REG && W[2]) || (READ_MEM && W[1]) ||
                         (WRITE_MEM && W[1]) || (INS_FETCH && W[2]))) begin
                ST0 <= 1'b1;
            end
            else if (ST0 && (WRITE_REG && W[2])) begin
                ST0 <= 1'b0;
            end
        end
    end

    // 操作模式译码
    assign WRITE_REG = (SWC_SWB_SWA == 3'b100);
    assign READ_REG = (SWC_SWB_SWA == 3'b011);
    assign INS_FETCH = (SWC_SWB_SWA == 3'b000);
    assign READ_MEM = (SWC_SWB_SWA == 3'b010);
    assign WRITE_MEM = (SWC_SWB_SWA == 3'b001);

    // 指令译码
    assign ADD = (IR7_IR4 == 4'b0001) && INS_FETCH && ST0;
    assign SUB = (IR7_IR4 == 4'b0010) && INS_FETCH && ST0;
    assign AND = (IR7_IR4 == 4'b0011) && INS_FETCH && ST0;
    assign INC = (IR7_IR4 == 4'b0100) && INS_FETCH && ST0;
    assign LD = (IR7_IR4 == 4'b0101) && INS_FETCH && ST0;
    assign ST = (IR7_IR4 == 4'b0110) && INS_FETCH && ST0;
    assign JC = (IR7_IR4 == 4'b0111) && INS_FETCH && ST0;
    assign JZ = (IR7_IR4 == 4'b1000) && INS_FETCH && ST0;
    assign JMP = (IR7_IR4 == 4'b1001) && INS_FETCH && ST0;
    assign STP = (IR7_IR4 == 4'b1110) && INS_FETCH && ST0;
    assign NOP = (IR7_IR4 == 4'b0000) && INS_FETCH && ST0;
    assign OUT = (IR7_IR4 == 4'b1010) && INS_FETCH && ST0;
    assign NOT = (IR7_IR4 == 4'b1101) && INS_FETCH && ST0;
    assign CMP = (IR7_IR4 == 4'b1100) && INS_FETCH && ST0;
    assign MOV = (IR7_IR4 == 4'b1011) && INS_FETCH && ST0;
    assign DEC = (IR7_IR4 == 4'b1111) && INS_FETCH && ST0;

    // 全时序逻辑控制 - 所有控制信号在T3下降沿更新
    always @(negedge T3 or negedge CLR) begin
        if (!CLR) begin
            // 复位所有控制信号
            SELCTL <= 1'b0;
            DRW <= 1'b0;
            LPC <= 1'b0;
            PCINC <= 1'b0;
            PCADD <= 1'b0;
            LAR <= 1'b0;
            ARINC <= 1'b0;
            LIR <= 1'b0;
            LDZ <= 1'b0;
            LDC <= 1'b0;
            CIN <= 1'b0;
            M <= 1'b0;
            MEMW <= 1'b0;
            ABUS <= 1'b0;
            SBUS <= 1'b0;
            MBUS <= 1'b0;
            STOP <= 1'b0;
            SHORT <= 1'b0;
            LONG <= 1'b0;
            S <= 4'b0000;
            SEL <= 4'b0000;
        end
        else begin
            // 控制信号合成 - 所有控制信号同步更新
            SBUS <= (WRITE_REG && (W[1] || W[2])) || (READ_MEM && (W[1] && !ST0)) ||
                 (WRITE_MEM && W[1]) || (INS_FETCH && (W[1] && !ST0));

            SEL[3] <= (WRITE_REG && (W[1] || W[2]) && ST0) || (READ_REG && W[2]);
            SEL[2] <= WRITE_REG && W[2];
            SEL[1] <= (WRITE_REG && ((W[1] && !ST0) || (W[2] && ST0))) || (READ_REG && W[2]);
            SEL[0] <= (WRITE_REG && W[1]) || (READ_REG && (W[1] || W[2]));

            SELCTL <= ((WRITE_REG || READ_REG) && (W[1] || W[2])) || ((READ_MEM || WRITE_MEM) && W[1]);

            DRW <= (WRITE_REG && (W[1] || W[2])) ||
                ((ADD || SUB || AND || INC || NOT || MOV || DEC) && W[1]) ||
                (LD && W[2]);

            STOP <= ((WRITE_REG || READ_REG) && (W[1] || W[2])) ||
                 ((READ_MEM || WRITE_MEM) && W[1]) ||
                 (STP && W[1]) ||
                 (INS_FETCH && !ST0 && W[1]);

            LAR <= ((READ_MEM || WRITE_MEM) && W[1] && !ST0) || ((ST || LD) && W[1]);

            SHORT <= ((READ_MEM || WRITE_MEM) && W[1]) ||
                  ((NOP || ADD || SUB || AND || INC || (JC && !C) ||
                    (JZ && !Z) || OUT || NOT || CMP || MOV) && W[1]);

            MBUS <= (READ_MEM && W[1] && ST0) || (LD && W[2]);

            ARINC <= (WRITE_MEM || READ_MEM) && W[1] && ST0;

            MEMW <= (WRITE_MEM && W[1] && ST0) || (ST && W[2]);

            CIN <= (ADD || DEC)&& W[1];

            ABUS <= ((ADD || SUB || AND || INC || LD || ST || JMP || OUT || MOV || CMP || NOT || DEC) && W[1]) ||
                 (ST && W[2]);

            LDZ <= (ADD || SUB || AND || INC || CMP || DEC) && W[1];
            LDC <= (ADD || SUB || INC || CMP || NOT || DEC) && W[1];

            M <= ((AND || LD || ST || JMP || OUT || MOV || NOT) && W[1]) ||
              (ST && W[2]);

            S[3] <= ((ADD || AND || LD || ST || JMP || OUT || MOV || DEC) && W[1]) ||
             (ST && W[2]);
            S[2] <= ((SUB || ST || JMP || CMP || DEC) && W[1]);
            S[1] <= ((SUB || AND || LD || ST || JMP || OUT || MOV || CMP || DEC) && W[1]) ||
             (ST && W[2]);
            S[0] <= (ADD || AND || ST || JMP || DEC) && W[1];

            LPC <= (JMP && W[1]) || (INS_FETCH && !ST0 && W[1]);

            LONG <= 1'b0; // 没有启用长周期控制

            PCADD <= ((C && JC) || (Z && JZ)) && W[1];

            // 先更新LIR信号
            LIR <= (INS_FETCH && W[2] && !ST0) ||
                ((NOP || ADD || SUB || AND || INC || (JC && !C) ||
                  (JZ && !Z) || OUT || MOV || CMP || NOT) && W[1]) ||
                ((LD || ST || (JC && C) || (JZ && Z) || JMP) && W[2]);

            // 后更新PCINC信号
            PCINC <= (INS_FETCH && W[2] && !ST0) ||
                  ((NOP || ADD || SUB || AND || INC || (JC && !C) ||
                    (JZ && !Z) || OUT || MOV || CMP || NOT) && W[1]) ||
                  ((LD || ST || (JC && C) || (JZ && Z) || JMP) && W[2]);
        end
    end

endmodule


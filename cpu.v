///////////////////////////////////////////////////////////////////////////
// MODULE: CPU for TSC microcomputer: cpu.v
// Author: 
// Description: 

// DEFINITIONS
`define WORD_SIZE 16    // data and address word size


//TSC design
// MODULE DECLARATION

/* 구조
    cpu: CU, RF, ALU, SE(추가해도되고 안해도 되고) 모듈로 결합
    
    CU: instruction 담당
    RF: 레지스터
    ALU: 연산 담당
    SE: Imm sign extension 담당
*/

//해결해야 하는 문제 : control unit 작성 + 모듈끼리 연결

module cpu (
    output readM,                       // read from memory
    output [`WORD_SIZE-1:0] address,    // current address for data
    inout [`WORD_SIZE-1:0] data,        // data being input or output
    input inputReady,                   // indicates that data is ready from the input port
    input reset_n,                      // active-low RESET signal
    input clk,                          // clock signal

    // for debuging/testing purpose
    output [`WORD_SIZE-1:0] num_inst,   // number of instruction during execution // 얘가 출력 평가용
    output [`WORD_SIZE-1:0] output_port // this will be used for a "WWD" instruction //출력 평가용
);
    reg [15:0] PC;
    wire [15:0] next_PC;
    reg [15:0] data_out;
    
    wire [15:0] SE_output;
    wire [1:0]  RF_addr1 = data[11:10];
    wire [1:0]  RF_addr2 = data[9:8];
    wire [1:0]  RF_addr3;
    wire [15:0] RF_data3;
    wire RF_write;
    wire [15:0] RF_data1;
    wire [15:0] RF_data2;
    wire [3:0]  ALU_function;
    wire [15:0] ALU_out;
    wire ALU_Cout;
    wire isImm;
    wire [15:0] ALU_B;

    assign data = (readM) ? 16'bz : data_out;
    assign address = PC;
    assign readM = (!reset_n) ? 1'b0 : 1'b1;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            PC <= 16'b0;
        end
        else begin
            PC <= next_PC;
        end
    end

    SE sign_ext(
        .in(data[7:0]),
        .out(SE_output)
    );

    RF reg_file(
        .addr1(RF_addr1),
        .addr2(RF_addr2),
        .addr3(RF_addr3),
        .data_in(RF_data3),
        .write(RF_write),
        .clk(clk),
        .reset(!reset_n),
        .data1(RF_data1),
        .data2(RF_data2)
    );

    assign ALU_B = (isImm) ? SE_output : RF_data2;
    ALU alu_inst (
        .A(RF_data1),
        .B(ALU_B),
        .Cin(1'b0),
        .OP(ALU_function),
        .Cout(ALU_Cout),
        .C(ALU_out)
    );

    ControlUnit cu (
        .clk(clk),
        .reset_n(reset_n),
        .data(data),
        .PC(PC),
        .next_PC(next_PC),
        .SE_output(SE_output),
        .ALU_function(ALU_function),
        .output_port(output_port),
        .num_inst(num_inst),
        .ALU_out(ALU_out),
        .RF_data1(RF_data1),
        .RF_data2(RF_data2),
        .RF_data3(RF_data3),
        .RF_write_addr(RF_addr3),
        .inputReady(inputReady),
        .RF_write(RF_write),
        .isImm(isImm),
        .readM()
    );
endmodule

/* 레지스터 개수는 평가에 크게 상관없으므로 4개로 구현 */
module RF( 
    input [1:0] addr1,// read1
    input [1:0] addr2, // read2
    input [1:0] addr3, // write
    input [15:0] data_in, //data to write
    input write, //sig
    input clk,
    input reset,
    output reg [15:0] data1,
    output reg [15:0] data2
    );

    // FILLME
    reg [15:0] regfile [3:0]; // 4 registers of 16 bits each

    always @(*) begin
        case(addr1)
            2'b00: data1 = regfile[0];
            2'b01: data1 = regfile[1];
            2'b10: data1 = regfile[2];
            2'b11: data1 = regfile[3];
            default: data1 = 16'h0000; // default case
        endcase
        case(addr2)
            2'b00: data2 = regfile[0];
            2'b01: data2 = regfile[1];
            2'b10: data2 = regfile[2];
            2'b11: data2 = regfile[3];
            default: data2 = 16'h0000; // default case
        endcase
    end


    always @(posedge clk) begin
        if (reset) begin
            regfile[0] <= 16'h0000;
            regfile[1] <= 16'h0000;
            regfile[2] <= 16'h0000;
            regfile[3] <= 16'h0000;
        end
        if (write) begin
            case(addr3)
                2'b00: regfile[0] <= data_in;
                2'b01: regfile[1] <= data_in;
                2'b10: regfile[2] <= data_in;
                2'b11: regfile[3] <= data_in;
            endcase
        end
    end
endmodule

/*ALU 또한 이대로 유지*/
module ALU(
    input [15:0] A,
    input [15:0] B,
    input Cin,// 초기 값
    input [3:0] OP,
    output reg Cout,// 올림수
    output reg [15:0] C // 결과
    );
    always @(*) begin
        case (OP)
            //Arithmetic
            4'b0000: {Cout, C} = A + B + Cin; // ADD
            4'b0001: {Cout, C} = A - (B+ Cin); // SUB
            //Bitwise Boolean
            4'b0010: {Cout, C} = {1'b0 , A};// ID
            4'b0011: {Cout, C} = {1'b0, ~(A & B)}; // NAND
            4'b0100: {Cout, C} ={1'b0, ~(A | B)};// NOR
            4'b0101: {Cout, C} = {1'b0,~(A ^ B)};// XNOR
            4'b0110: {Cout, C}= {1'b0, ~A};// NOT
            4'b0111: {Cout, C}={1'b0, A & B};// AND
            4'b1000: {Cout, C} = {1'b0, A | B};// OR
            4'b1001: {Cout, C}= {1'b0, A ^ B};// XOR
            //shifting
            4'b1010: {Cout, C} = {1'b0, A >> 1};// LRS
            4'b1011: {Cout, C} = {1'b0, A[15], A[15:1]};// ARS
            4'b1100: {Cout, C} = {1'b0 , A[0], A[15:1]};//RR
            4'b1101: {Cout, C}= {1'b0, A<<1};//LLS
            4'b1110: {Cout, C} = {1'b0, A[14:0], 1'b0};//ALS
            4'b1111: {Cout, C}= {1'b0, A[14:0], A[15]};//LR
            default: {Cout, C} = 17'b0;
        endcase
    end

    /*
        // Arithmetic
    `define	OP_ADD	4'b0000
    `define	OP_SUB	4'b0001
    //  Bitwise Boolean operation
    `define	OP_ID	4'b0010
    `define	OP_NAND	4'b0011
    `define	OP_NOR	4'b0100
    `define	OP_XNOR	4'b0101
    `define	OP_NOT	4'b0110
    `define	OP_AND	4'b0111
    `define	OP_OR	4'b1000
    `define	OP_XOR	4'b1001
    // Shifting
    `define	OP_LRS	4'b1010
    `define	OP_ARS	4'b1011
    `define	OP_RR	4'b1100
    `define	OP_LLS	4'b1101
    `define	OP_ALS	4'b1110
    `define	OP_RL	4'b1111
    */
endmodule

module SE(// sign extention, 8비트만 받음, j-type은 PC 계산할 때 그때 사용
    input [7:0] in,
    output reg [15:0] out
    );
    always @(*) begin
        if (in[7] == 1) begin
            out = {8'hFF, in}; // 음수인 경우 상위 8비트를 1로 채움
        end else begin
            out = {8'h00, in}; // 양수인 경우 상위 8비트를 0으로 채움
        end
    end
endmodule

//PC만 계산, 나머지 연산은 ALU,RF에서 처리
module ControlUnit(
    input clk,
    input reset_n,
    input [15:0] data, // instruction
    input [15:0] PC, output reg [15:0] next_PC,
    input [15:0] SE_output, // sign-extended immediate value--외부에서 받은 extended imm
    output reg [3:0] ALU_function,// ALU에 어떤 연산을 수행할지 지시하는 신호 --ALU_OP
    output reg [7:0] Itype_imm,
    output reg [3:0] OP,
    output reg [`WORD_SIZE-1:0] mem_address, // memory access를 위한 주소
    output reg [`WORD_SIZE-1:0] output_port, // WWD 명령어를 위한 출력 포트
    output [15:0] num_inst,

    //ALU에서 받는 신호
    input [15:0] ALU_out, // RF에서 ALU로 데이터 연결--rf 데이터를 여기서 받음
    //ALU로 보내는 신호
    output reg[15:0] data_1, data_2, // ALU에 들어갈 데이터

    //RF로 보내는 신호
    output reg [15:0] RF_data3,// RF에 쓰기 위한 데이터
    output reg [1:0] RF_write_addr, // RF에 쓰기 위한 주소

    //RF에서 받는 신호
    input [15:0] RF_data1, RF_data2,

    //state용 신호
    input inputReady,
    output reg RF_write, //RF에서 write 신호
    output reg isImm, // ALU의 B 입력이 Imm인지 reg인지 구분하는 신호
    output reg readM // memory read signal- 1이면 memory에서 읽기, 0이면 memory에 쓰기
);
    reg [1:0] RF_addr1, RF_addr2, RF_addr3; //rs, rt, rd -- 모두 RF 주소로 연결됨

    reg [15:0] inst_count;
    assign num_inst = inst_count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            inst_count <= 16'b0;
        end
        else if (inputReady) begin
            inst_count <= inst_count + 1'b1;
        end
    end

    always @(*) begin
        if(inputReady) begin
            // instruction이 준비되면 다음 명령어를 처리
            OP = data[15:12]; // opcode는 instruction의 상위 6비트
            Itype_imm = data[7:0]; // I-type 명령어의 즉시값은 하위 8비트
            RF_addr1 = data[11:10]; // rs는 instruction의 9-8비트
            RF_addr2 = data[9:8]; // rt는 instruction의 7-6비트
            RF_addr3 = data[7:6]; // rd는 instruction의 5-4비트
        end 
        else begin
            // instruction이 준비되지 않으면 아무 작업도 수행하지 않음
            next_PC = PC; // PC 유지
        end
    end

    always @(*) begin 
        RF_write = 0;
        isImm = 0;
        readM = 1;
        ALU_function = 4'b0000;
        data_1 = RF_data1;
        data_2 = RF_data2;
        RF_data3 = ALU_out;
        RF_write_addr = RF_addr3;
        next_PC = PC;

        if (inputReady) begin
            next_PC = PC + 16'h0001; // 다음 명령어로 이동

            case (data [15:12]) 
                
                4'b0100: begin //op = 4 (ADI)
                    RF_write = 1; // RF에 쓰기 허용
                    isImm = 1;
                    data_1 = RF_data1; // ALU의 A 입력에 rs 데이터 연결
                    data_2 = SE_output; // ALU의 B 입력에 sign-extended immediate value 연결
                    ALU_function = 4'b0000; // ALU에 ADD 연산 지시
                    RF_data3 = ALU_out; // ALU의 결과를 RF에 쓰기
                    RF_write_addr = RF_addr2;
                end
                
                4'b0110: begin //op = 6 (LHI)
                    RF_write =1;
                    RF_data3 = {Itype_imm, 8'h00}; // 상위 8비트에 즉시값을 넣고 하위 8비트는 0으로 설정
                    RF_write_addr = RF_addr2; // rt에 결과를 쓰기
                end
                
                // J-type
                4'b1001: begin //op = 9 (JMP)
                    next_PC = {PC[15:12], data[11:0]};
                end
                
                // R-type
                4'b1111: begin
                    case (data [5:0]) 
                    //ADD $1, $2, $0 ; $3 ← $0 + $1
                        6'b000000: begin //op = 15, func = 0 (ADD)
                            ALU_function = 4'b0000; // ALU에 ADD 연산 지시
                            data_1 = RF_data1; // ALU의 A 입력에 rs 데이터 연결
                            data_2 = RF_data2; // ALU의 B 입력에 rt 데이터 연결
                            RF_data3 = ALU_out; // ALU의 결과를 RF에 쓰기
                            RF_write_addr = RF_addr3; // rd에 결과를 쓰기
                            RF_write = 1'b1; // RF에 쓰기 허용
                        end
                    
                    //WWD $0 ; output port ← $0
                        6'b011100: begin //op = 15, func = 28 (WWD)
                            data_1 = RF_data1; // ALU의 A 입력에 rs 데이터 연결
                            output_port = RF_data1; // RF의 rs 데이터를 output_port에 연결
                        end
                        
                        default: begin
                            RF_write = 0; //RF에서 write 신호
                            isImm = 0; // ALU의 B 입력이 Imm인지 reg인지 구분하는 신호
                            readM = 1; // memory read signal- 1이면 memory에서 읽기, 0이면 memory에 쓰기
                        end
                    endcase
                end
                default: begin
                    RF_write = 0; //RF에서 write 신호
                    isImm = 0; // ALU의 B 입력이 Imm인지 reg인지 구분하는 신호
                    readM = 1; // memory read signal- 1이면 memory에서 읽기, 0이면 memory에 쓰기
                end
            endcase
        end
    end
endmodule



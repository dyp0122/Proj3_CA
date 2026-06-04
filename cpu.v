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

    reg [15:0] PC, next_PC; //pc 변수

    //modules 추가
    
    wire [15:0] RF_to_ALU_data1, RF_to_ALU_data2; // RF에서 ALU로 데이터 연결하기 위한 wire
    wire [1:0] CU_to_RF_addr1, CU_to_RF_addr2, CU_to_RF_addr3; // Control Unit에서 RF로 주소 연결하기 위한 wire 
    wire [15:0] CU_to_RF_data;
    wire isImm; wire RF_write;
    ControlUnit cu(
        .data(), // FILLME: connect instruction data from memory
        .PC(PC), // FILLME: connect current PC value
        .ALU_OP(), // FILLME: connect ALU operation code output
        .RF_write(RF_write), // FILLME: connect RF write enable output
        .RF_addr1(CU_to_RF_addr1), // FILLME: connect RF read address 1 output
        .RF_addr2(CU_to_RF_addr2), // FILLME: connect RF read address 2 output
        .RF_addr3(CU_to_RF_addr3), // FILLME: connect RF write address output
        .RF_data3(CU_to_RF_data), // FILLME: connect RF data to write output
        .next_PC() // FILLME: connect next PC value output
        .isImm(isImm) // FILLME: connect isImm signal output
    );

    RF rf(
        .addr1(CU_to_RF_addr1), // FILLME: connect RF read address 1
        .addr2(CU_to_RF_addr2), // FILLME: connect RF read address 2
        .addr3(CU_to_RF_addr3), // FILLME: connect RF write address
        .data3(CU_to_RF_data), // FILLME: connect RF data to write
        .write(RF_write), // FILLME: connect RF write enable signal
        .clk(clk),
        .reset(reset_n),
        .data1(RF_to_ALU_data1), // FILLME: connect RF data output 1
        .data2(RF_to_ALU_data2) // FILLME: connect RF data output 2
    );
    SE se(
        .in(), // FILLME: connect immediate value from instruction
        .out() // FILLME: connect sign-extended output
    );
    wire [15:0] inputB 
    assign inputB = (isImm) ? SE_output : RF_to_ALU_data2; // ALU의 B 입력은 즉시값 또는 레지스터 값 중 하나
    ALU alu(
        .A(), // FILLME: connect ALU input A
        .B(), // FILLME: connect ALU input B
        .Cin(), // FILLME: connect ALU carry-in
        .OP(), // FILLME: connect ALU operation code
        .Cout(), // FILLME: connect ALU carry-out
        .C() // FILLME: connect ALU output C
    );



    //PC
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) 
            begin PC <= 16'h0000; end // reset 시 PC 초기화
        else 
            begin PC <= next_PC; end// 다음 PC로 업데이트
    end
    // for debuging/testing purpose
    output [`WORD_SIZE-1:0] num_inst,   // number of instruction during execution // 얘가 출력 평가용
    output [`WORD_SIZE-1:0] output_port // this will be used for a "WWD" instruction //출력 평가용
);

    
endmodule



/* 레지스터 개수는 평가에 크게 상관없으므로 4개로 구현 */
module RF( 
    input [1:0] addr1,// read1
    input [1:0] addr2, // read2
    input [1:0] addr3, // write
    input [15:0] data3, //data to write
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
                2'b00: regfile[0] <= data3;
                2'b01: regfile[1] <= data3;
                2'b10: regfile[2] <= data3;
                2'b11: regfile[3] <= data3;
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


//CU와 ALU, RF 사이 연결이 필요
module ControlUnit(
    input [15:0] data, // instruction
    input [15:0] PC,
    output reg [3:0] ALU_OP,
    output reg RF_write,
    output reg [1:0] RF_addr1, RF_addr2, RF_addr3, //rs, rt, rd -- 모두 RF 주소로 연결됨
    output reg [15:0] RF_data3,
    output reg [15:0] next_PC
    output reg RF_write,//RF에서 write 신호
    output reg isImm // ALU의 B 입력이 Imm인지 reg인지 구분하는 신호
);
    
    always @(*) begin
        case (data [15:10]) 
            // I-type
            6'b000000: begin //op = 0 (BNE)
                
            end
            6'b000001: begin //op = 1 (BEQ)
                
            end
            6'b000010: begin //op = 2 (BGZ)
                
            end
            6'b000011: begin //op = 3 (BLT)
                
            end
            6'b000100: begin //op = 4 (ADI)
                
            end
            6'b000101: begin //op = 5 (ORI)
                
            end
            6'b000110: begin //op = 6 (LHI)
                
            end
            6'b000111: begin //op = 7 (LWD)
                
            end
            6'b001000: begin //op = 8 (SWD)
                
            end
            // J-type
            6'b001001: begin //op = 9 (JMP)
                assign next_PC = {PC[15:14], data[11:0], 2'b00}
            end
            6'b001010: begin //op = 10 (JAL)
                assign next_PC = {PC[15:14], data[11:0], 2'b00}
            end
            // R-type
            6'b001111: begin
                assign RF_addr1 = data[11:10]; // rs
                assign RF_addr2 = data[9:8]; // rt  
                assign RF_addr3 = data[7:6]; // rd
                case (data [5:0]) 
                    6'b000000: begin //op = 15, func = 0 (ADD)
                        ALU_OP = 4'b0000; // ALU에 ADD 연산 지시
                    end
                    6'b000001: begin //op = 15, func = 1 (SUB)
                        ALU_OP = 4'b0001; // ALU에 SUB 연산 지시
                    end
                    6'b000010: begin //op = 15, func = 2 (AND)
                        ALU_OP = 4'b0111; // ALU에 AND 연산 지시
                    end
                    6'b000011: begin //op = 15, func = 3 (ORR)
                        
                    end
                    6'b000100: begin //op = 15, func = 4 (NOT)
                        
                    end
                    6'b000101: begin //op = 15, func = 5 (TCP)
                        
                    end
                    6'b000110: begin //op = 15, func = 6 (SHL)
                        
                    end
                    6'b000111: begin //op = 15, func = 7 (SHR)
                        
                    end
                    6'b011001: begin //op = 15, func = 25 (JPR)
                        
                    end
                    6'b011010: begin //op = 15, func = 26 (JRL)
                        
                    end
                    6'b011011: begin //op = 15, func = 27 (RWD)
                        
                    end
                    6'b011100: begin //op = 15, func = 28 (WWD)
                        
                    end
                    6'b011101: begin //op = 15, func = 29 (HLT)
                        
                    end
                    default: begin
                        // FILLME: handle invalid function code if necessary
                    end
                endcase
            end
            default: begin
                // FILLME: handle invalid opcode if necessary
            end
        endcase
    end
endmodule
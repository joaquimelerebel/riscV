`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/20/2023 10:59:00 AM
// Design Name: 
// Module Name: parser_nop_custom
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// could be included in the decoder.sv  
module parser_nop_custom
#(
    //parameter nop_fu = ALU;
    parameter nop_op = ariane_pkg::ADD,
    parameter nop_rd  = 5'b0,
    parameter nop_rs1  = 5'b0,
    parameter nop_imm = 5'b1
)
(
    input  logic                                rstn_i, 
    input  logic                                clk_i,
    input  logic                                flush_i,
    
    input logic[3:0]                            debug_leds,
    
    input  ariane_pkg::scoreboard_entry_t       entry_score_i,
    output ariane_pkg::scoreboard_entry_t       entry_score_o
);
    
    enum int unsigned { IDLE = 0, WAITS_NOP = 2 } state, next_state;
    
    logic detect_RET, detect_NOP;
    
    /*state machine*/
    always_comb begin
        entry_score_o = entry_score_i;
            
        if(flush_i) begin 
            next_state = IDLE;
            detect_RET = 1'b0;
            detect_NOP = 1'b0;
        end else begin 
            detect_RET = 1'b0;
            detect_NOP = 1'b0;
            // FSM
            case( state ) 
                IDLE : begin
                    next_state = IDLE;
                    // detect the return
                    if( (entry_score_i.ex.valid == 1'b0) && 
                        (entry_score_i.op == ariane_pkg::JALR) &&
                        (entry_score_i.rd[5:0] == 6'b0) &&
                        ( entry_score_i.rs1[5:0] == 6'h1 ) ) begin
                            next_state = WAITS_NOP;
                            detect_RET = 1'b1;
                    end
                end
                WAITS_NOP : begin
                    next_state = IDLE;
                   
                    if ( (entry_score_i.op != nop_op) || 
                        (entry_score_i.rd[4:0] != nop_rd) ||
                        (entry_score_i.rs1[4:0] != nop_rs1) ||
                        (entry_score_i.result[4:0] != nop_imm) ) begin
                            entry_score_o.ex.cause = riscv::ILLEGAL_INSTR;
                            entry_score_o.ex.valid = 1'b1;
                            detect_NOP = 1'b1;
                    end else begin 
                         entry_score_o = entry_score_i;
                    end     
               end
               default :
                   begin 
                        next_state = IDLE;
                        entry_score_o = entry_score_i;
                   end 
            endcase
        end 
    end
    
   
    always_ff @(posedge clk_i) begin
        if(rstn_i == 1'b0) begin 
            state <= IDLE;
         end else begin 
            state <= next_state;
         end
    end
    
endmodule

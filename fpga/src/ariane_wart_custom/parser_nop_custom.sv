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
    input  logic                                clk_i,
    input  logic                                rst_ni,
    input  logic                                flush_i,
    
    output logic[9:0]                           debug_leds,
    
    input  ariane_pkg::scoreboard_entry_t       entry_score_i,
    output ariane_pkg::scoreboard_entry_t       entry_score_o
);
    
    enum int unsigned { IDLE = 0, WAITS_NOP = 2 } state, next_state;
    
    logic detect_RET, detect_NOP, prev_nop, prev_ret, detect_prep_NOP, prev_prep_nop;
    logic[9:0] leds_s;
    
    ariane_pkg::scoreboard_entry_t prev_entry_i, prev_entry_o;
    
    always_comb begin
        if(flush_i) begin 
            detect_NOP = 1'b0;
        end else begin 
            if ( (entry_score_i.op == nop_op) || 
               (entry_score_i.rd[4:0] != nop_rd) ||
               (entry_score_i.rs1[4:0] != nop_rs1) ||
               (entry_score_i.result[4:0] != nop_imm) 
              ) begin
                    detect_NOP = 1'b1;
             end 
             else begin
               detect_NOP = 1'b0;
             end
         end
    end 
    
    
    /*state machine*/
    always_comb begin
        entry_score_o = entry_score_i;
            
        if(flush_i) begin 
            next_state = IDLE;
            detect_RET = 1'b0;
            detect_prep_NOP = 1'b0;
            prev_entry_i = '0;
        end else begin 
            detect_RET = 1'b0;
            detect_prep_NOP = 'b0;
            next_state = IDLE;
            //detect_NOP = 1'b0;
            // FSM
            case( state ) 
                IDLE : begin
                    // detect the return
                    if( (entry_score_i.ex.valid == 1'b0) && 
                        (entry_score_i.op == ariane_pkg::JALR) &&
                        (entry_score_i.rd[5:0] == 6'b0) &&
                        ( entry_score_i.rs1[5:0] == 6'h1 ) ) begin
                            next_state = WAITS_NOP;
                            detect_RET = 1'b1;
                            prev_entry_i = entry_score_i;
                    end else begin
                        prev_entry_i = '0;
                    end
                end
                WAITS_NOP : begin
                   
                   if ( prev_entry_o != entry_score_i ) begin
                       //entry_score_o.ex.cause = riscv::LD_ACCESS_FAULT;
                       //entry_score_o.ex.valid = 1'b1;
                       detect_prep_NOP = 1'b1; 
                       prev_entry_i = '0;
                       
                       /*if ( (entry_score_i.op == nop_op) //|| 
                         //  (entry_score_i.rd[4:0] != nop_rd) ||
                          // (entry_score_i.rs1[4:0] != nop_rs1) ||
                          // (entry_score_i.result[4:0] != nop_imm) 
                          ) begin
                                //entry_score_o.ex.cause = 'b0;
                                //entry_score_o.ex.valid = 1'b0;
                                detect_NOP = 1'b1;
                         end*/
                     end else begin
                        prev_entry_i = entry_score_i; 
                     end 
                 end
               default :
                   begin 
                        next_state = IDLE;
                        prev_entry_i = '0;
                   end 
            endcase
        end 
    end
    
   
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            state <= IDLE;
            prev_entry_o <= '0;
         end else begin 
            state <= next_state;
            prev_entry_o <= prev_entry_i;
         end
    end
    
   assign debug_leds = leds_s;
         
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            prev_nop <= 1'b0;
            prev_ret <= 1'b0;
            prev_prep_nop <= 1'b0;
            leds_s <= 4'b0;
         end else begin
            prev_ret <= detect_RET;
            prev_nop <= detect_NOP;
            prev_prep_nop <= detect_prep_NOP;
            
            if((prev_ret == 1'b0) && (detect_RET == 1'b1)) begin
                leds_s[8] <= !leds_s[8]; 
            end 
            
            if((prev_prep_nop == 1'b0) && (detect_prep_NOP == 1'b1)) begin
                leds_s[7] <= !leds_s[7]; 
            end 
            
            if((prev_nop == 1'b0) && (detect_NOP == 1'b1)) begin 
                leds_s[9] <= !leds_s[9];
                leds_s[6:0] <= entry_score_i.op[6:0];
            end 
         end
    end
    
endmodule

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


//uld be included in the decoder.sv  
module parser_nop_custom_fetch

#(
    //parameter nop_fu = ALU;        
 parameter nop_inst = 32'h00008067,
 parameter ret_inst = 32'h00100013
)
(
    input  logic                                clk_i,
    input  logic                                rst_ni,
    input  logic                                flush_i,
    
    output logic[9:0]                           debug_leds,
    
    input  ariane_pkg::fetch_entry_t       entry_i,
    output ariane_pkg::fetch_entry_t       entry_o
);
    
    enum int unsigned { IDLE = 0, WAITS_NOP = 2 } state, next_state;
    
    logic detect_RET, detect_NOP, prev_nop, prev_ret, detect_prep_NOP, prev_prep_nop;
    logic[9:0] leds_s;
    
    ariane_pkg::fetch_entry_t prev_entry;
    
    /*state machine*/
    always_comb begin
        entry_o = entry_i;
        detect_RET = 1'b0;
        detect_prep_NOP = 1'b0;
        detect_NOP = 1'b0;
       
        // FSM
        case( state ) 
            IDLE : begin
                next_state = IDLE;
                // detect the return
                if( (entry_i.instruction == ret_inst) ) begin
                        next_state = WAITS_NOP;
                        detect_RET = 1'b1;
                end
            end
            WAITS_NOP : begin
               next_state = WAITS_NOP; 
               if ( prev_entry != entry_i ) begin
                   
                   detect_prep_NOP = 1'b1;
                   next_state = IDLE;
                   entry_o.ex.cause = riscv::INSTR_ACCESS_FAULT;
                   entry_o.ex.valid = 1'b1;
               
                   if ( entry_i.instruction == nop_inst ) begin
                            entry_o.ex.cause = 'b0;
                            entry_o.ex.valid = 1'b0;
                            detect_NOP = 1'b1;
                     end
                 end
             end
           default :
               begin 
                    next_state = IDLE;
               end 
        endcase
    end 
    
   
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            state <= IDLE;
            prev_entry <= '0;
         end else begin 
            state <= next_state;
            prev_entry <= entry_i;
         end
    end
    
   assign debug_leds = leds_s;
         
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            prev_nop <= 1'b0;
            prev_ret <= 1'b0;
            prev_prep_nop <= 1'b0;
            leds_s <= '0;
         end else begin
            prev_ret <= detect_RET;
            prev_nop <= detect_NOP;
            prev_prep_nop <= detect_prep_NOP;
            
            if((prev_ret == 1'b0) && (detect_RET == 1'b1)) begin
                leds_s[0] <= !leds_s[0]; 
            end 
            
            if((prev_prep_nop == 1'b0) && (detect_prep_NOP == 1'b1)) begin
                leds_s[1] <= !leds_s[1]; 
            end 
            
            if((prev_nop == 1'b0) && (detect_NOP == 1'b1)) begin 
                leds_s[2] <= !leds_s[2];
                //leds_s[6:0] <= entry_score_i.op[6:0];
            end 
         end
    end
    
endmodule

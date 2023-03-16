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
 
module parser_nop_custom_commit
#(
    parameter nop_op = ariane_pkg::ADD,
    parameter nop_rd  = 5'b0,
    parameter nop_rs1  = 5'b0,
    parameter nop_imm_ret = 5'h1,
    parameter nop_imm_call = 5'h2,
    parameter NR_COMMIT_PORTS = 2
)
(
    input  logic                                                    clk_i,
    input  logic                                                    rst_ni,
    input  logic                                                    flush_i,
    input  logic                                                    csr_en_i,
    // does the commit stages wants to commit the nth instruction
    input logic [NR_COMMIT_PORTS-1:0]                               commit_ack_o,
    // what instruction will be commited
    input  ariane_pkg::scoreboard_entry_t [NR_COMMIT_PORTS-1:0]     commit_instr_i,
    output logic [3:0]                                              leds, 
    output ariane_pkg::exception_t                                  exception_o
   
);
    
    enum int unsigned { IDLE, WAITS_NOP } state, next_state;
    
    logic detect_RET, detect_CALL, detect_NOP_RET, detect_NOP_CALL;
       
       
    logic prev_detect_CALL, prev_detect_RET;
    
    logic detect_prep_NOP_CALL, detect_prep_NOP_RET;
    
    logic prev_detect_prep_NOP_CALL, prev_detect_prep_NOP_RET;
       
    logic prev_nop_ret, prev_nop_call;  
    logic[3:0] leds_s;
       
    ariane_pkg::scoreboard_entry_t prev_entry;
    


function logic is_ret(ariane_pkg::scoreboard_entry_t entry);
        if( (entry.op == ariane_pkg::JALR)  &&
            (entry.rd[5:0] == 6'h0)         &&
            (entry.rs1[5:0] == 6'h1) )      begin
            is_ret = 1'b1;
        end else begin 
            is_ret = 1'b0;
        end
endfunction

function logic is_call(ariane_pkg::scoreboard_entry_t entry);
        if( ( entry.rd[5:0] == 6'h1 /*ajouter le 5*/              ) &&
            (     ( entry.op == ariane_pkg::JALR ) ||
                  ( entry.op == ariane_pkg::JAL  ) ) 
          ) begin
           is_call = 1'b1;
        end else begin 
            is_call = 1'b0;
        end
endfunction


function logic is_nop_ret(ariane_pkg::scoreboard_entry_t entry);
        if( (entry.op == nop_op)                &&
            (entry.rd[4:0] == nop_rd)           &&
            (entry.rs1[4:0] == nop_rs1)         &&
            (entry.result[4:0] == nop_imm_ret))     begin
            is_nop_ret = 1'b1;
        end else begin 
            is_nop_ret = 1'b0;
        end
endfunction

function logic is_nop_call(ariane_pkg::scoreboard_entry_t entry);
        if( (entry.op == nop_op)                &&
            (entry.rd[4:0] == nop_rd)           &&
            (entry.rs1[4:0] == nop_rs1)         &&
            (entry.result[4:0] == nop_imm_call))     begin
            is_nop_call = 1'b1;
        end else begin 
            is_nop_call = 1'b0;
        end
endfunction

    
    /* state machine */
    always_comb begin        
        detect_RET          = 1'b0;
        detect_CALL         = 1'b0;
        detect_prep_NOP_CALL= 1'b0;
        detect_prep_NOP_RET = 1'b0;
        detect_NOP_RET      = 1'b0;
        detect_NOP_CALL     = 1'b0;
        
        
        
        // FSM
        case( state ) 
            IDLE : begin
                next_state = IDLE;
                
                // detect commit available
                if( (commit_ack_o[0] == 1'b1)                   && 
                    (commit_instr_i[0].ex.valid == 1'b0)       
                  ) begin
                     
                     // detect the return
                     if( is_ret(commit_instr_i[0]) ) begin 
                        next_state = WAITS_NOP;
                        detect_RET = 1'b1;
                        
                        if( commit_ack_o[1] == 1'b1 ) begin
                            // detect that we are supposed to have the right nop after
                            detect_prep_NOP_RET = 1'b1;
                            next_state = IDLE;
                        
                            if ( is_nop_ret(commit_instr_i[1]) )    begin
                                detect_NOP_RET = 1'b1;
                            end
                        end
                        
                     // detect the call
                     end else 
                     if( is_call(commit_instr_i[0]) ) begin
                       next_state = WAITS_NOP;
                       detect_CALL = 1'b1;
                       
                       if( commit_ack_o[1] == 1'b1 ) begin
                            // detect that we are supposed to have the right nop after
                            detect_prep_NOP_CALL = 1'b1;
                            next_state = IDLE;
                            
                            if ( is_nop_call(commit_instr_i[1]) )    begin
                                detect_NOP_CALL = 1'b1;
                            end
                       end
                     end
     
                end
                 
                if( (commit_ack_o[1] == 1'b1)                  && 
                    (commit_instr_i[1].ex.valid == 1'b0)     ) begin
                     // detect the return
                     if( is_ret(commit_instr_i[1]) ) begin 
                        next_state = WAITS_NOP;
                        detect_RET = 1'b1;
                     // detect the call
                     end else 
                     if( is_call(commit_instr_i[1]) ) begin
                        next_state = WAITS_NOP;
                        detect_CALL = 1'b1;
                     end
                end
            end
            WAITS_NOP : begin
               next_state = WAITS_NOP;
               
               // only check the first one because means that the jalr was on the commit_instr_i[0] and commit_instr_i[1] was not commited at the same time 
               // or on commit_instr_i[1] and not the ret is on commit[0]
               if(  (prev_entry != commit_instr_i[0]) && 
                    (commit_ack_o[0]) ) begin
                    
                   if( prev_detect_CALL ) begin 
                        // detect that we are supposed to have the right nop after
                         detect_prep_NOP_CALL = 1'b1;
                         next_state = IDLE;
                         if ( is_nop_call(commit_instr_i[0]) )    begin
                            detect_NOP_CALL = 1'b1;
                         end
                    end else 
                    if( prev_detect_RET ) begin
                        // detect that we are supposed to have the right nop after
                        detect_prep_NOP_RET = 1'b1;
                        next_state = IDLE;
                        
                        if ( is_nop_ret(commit_instr_i[0]) )    begin
                            detect_NOP_RET = 1'b1;
                        end
                    end
                   
                   // detect call or ret on the second instruction
                   if( commit_ack_o[1] && !commit_instr_i[1].ex.valid ) begin
                         // detect the return
                         if( is_ret(commit_instr_i[1]) ) begin 
                            next_state = WAITS_NOP;
                            detect_RET = 1'b1;
                         // detect the call
                         end else 
                         if( is_call(commit_instr_i[1]) ) begin
                               next_state = WAITS_NOP;
                               detect_CALL = 1'b1;
                         end
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
            prev_detect_CALL <= '0;
            prev_detect_RET  <= '0;
            prev_entry <= '0;
         end else begin 
            state <= next_state;
            prev_detect_RET  <= detect_RET; 
            prev_detect_CALL <= detect_CALL;
            prev_entry <= commit_instr_i[0];
         end
    end
   
   /*assign leds[0] = csr_en_i;
    
   assign leds[1] = detect_NOP_CALL;
   assign leds[2] = detect_NOP_RET;
     */ 
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            exception_o.valid <= 1'b0;
            exception_o.cause <= '0;
            exception_o.tval  <= '0;
        end else begin
            if( detect_prep_NOP_CALL && !detect_NOP_CALL && csr_en_i) begin
                exception_o.cause <= riscv::BREAKPOINT;
                exception_o.valid <= 1'b1;
            end else 
            if( detect_prep_NOP_RET && !detect_NOP_RET && csr_en_i) begin
                exception_o.cause <= riscv::BREAKPOINT;
                exception_o.valid <= 1'b1;
            end else begin 
                exception_o.valid <= 1'b0;
                exception_o.cause <= '0;
            end
        end
    end
   
   
   //assign leds = '0;
      
   assign leds = leds_s;
         
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            //prev_nop <= 1'b0;
            //prev_ret <= 1'b0;
            prev_nop_ret  <= '0;
            prev_nop_call <= '0;
            prev_detect_prep_NOP_CALL <= '0;
            prev_detect_prep_NOP_RET <= '0;
            leds_s <= '0;
         end else begin
            //prev_ret <= detect_RET;
            prev_nop_ret <= detect_NOP_RET;
            prev_nop_call <= detect_NOP_CALL;
            prev_detect_prep_NOP_CALL <= detect_prep_NOP_CALL;
            prev_detect_prep_NOP_RET <= detect_prep_NOP_RET;
            //prev_prep_nop <= detect_prep_NOP;
            
            
            if((prev_detect_prep_NOP_RET == 1'b0) && (detect_prep_NOP_RET == 1'b1)) begin
                leds_s[0] <= !leds_s[0]; 
            end
            
            if((prev_nop_ret == 1'b0) && (detect_NOP_RET == 1'b1)) begin
                leds_s[1] <= !leds_s[1];
                //leds_s[6:0] <= entry_score_i.op[6:0]; 
            end 
            
            if((prev_detect_prep_NOP_CALL == 1'b0) && (detect_prep_NOP_CALL == 1'b1)) begin
                leds_s[2] <= !leds_s[2]; 
            end 
            
            if((prev_nop_call == 1'b0) && (detect_NOP_CALL == 1'b1)) begin 
                leds_s[3] <= !leds_s[3];
                
            end 
         end
    end
    
endmodule

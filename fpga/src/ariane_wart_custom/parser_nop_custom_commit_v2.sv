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
 
module parser_nop_custom_commit_v2
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
    output logic [9:0]                                              leds, 
    output ariane_pkg::exception_t                                  exception_o
   
);
    
    enum int unsigned { IDLE, WAITS_NOP } state_RET, state_CALL, next_state_RET, next_state_CALL;
    
    logic detect_RET, detect_CALL, detect_NOP_RET, detect_NOP_CALL;
       
       
    logic prev_detect_CALL, prev_detect_RET;
    
    logic detect_prep_NOP_CALL, detect_prep_NOP_RET;
    
    logic prev_detect_prep_NOP_CALL, prev_detect_prep_NOP_RET;
       
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
        if( ( entry.fu == ariane_pkg::CTRL_FLOW  ) && 
            ( entry.rd[5:0] != 6'h0              ) &&
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

    
    /*state machine for the RET*/
    always_comb begin        
        detect_RET = 1'b0;
        detect_prep_NOP_RET = 1'b0;
        detect_NOP_RET = 1'b0;
        
        // FSM
        case( state_RET ) 
            IDLE : begin
                next_state_RET = IDLE;
                
                // detect the return
                if( (commit_ack_o[0] == 1'b1)                   && 
                    (commit_instr_i[0].ex.valid == 1'b0)        && 
                    is_ret(commit_instr_i[0]) )                 begin
                        next_state_RET = WAITS_NOP;
                        detect_RET = 1'b1;
                    
                    // check if the ret is in the second that might be ACK at the same time 
                    if( commit_ack_o[1] == 1'b1 ) begin
                        detect_prep_NOP_RET = 1'b1;
               
                        next_state_RET = IDLE;
                        
                        if ( is_nop_ret(commit_instr_i[1]) )    begin
                            detect_NOP_RET = 1'b1;
                         end
                    end
     
                end else 
                if( (commit_ack_o[1] == 1'b1)                  && 
                    (commit_instr_i[1].ex.valid == 1'b0)       && 
                    is_ret(commit_instr_i[1]) )                begin
                            next_state_RET = WAITS_NOP;
                            detect_RET = 1'b1;
                end
            end
            WAITS_NOP : begin
               next_state_RET = WAITS_NOP;
               
               // only check the first one because means that the jalr was on the commit_instr_i[0] and commit_instr_i[1] was not commited at the same time 
               // or on commit_instr_i[1] and not the ret is on commit[0]
               if ( (prev_entry != commit_instr_i[0])   &&
                    (commit_ack_o[0] == 1'b1))          begin
                    
                    detect_prep_NOP_RET = 1'b1;
                    next_state_RET = IDLE;
               
                    if ( is_nop_ret(commit_instr_i[0]) )    begin
                            detect_NOP_RET = 1'b1;
                     end
               end
           end
           default :
               begin 
                    next_state_RET = IDLE;
               end 
        endcase
    end 


    /*state machine for the CALLS*/
    always_comb begin        
        detect_CALL = 1'b0;
        detect_prep_NOP_CALL = 1'b0;
        detect_NOP_CALL = 1'b0;
        
        // FSM
        case( state_CALL ) 
            IDLE : begin
                next_state_CALL = IDLE;
                
                // detect the return
                if( (commit_ack_o[0] == 1'b1)                   && 
                    (commit_instr_i[0].ex.valid == 1'b0)        && 
                    is_call(commit_instr_i[0]) )                 begin
                        next_state_CALL = WAITS_NOP;
                        detect_CALL = 1'b1;
                    
                    // check if the ret is in the second that might be ACK at the same time 
                    if( commit_ack_o[1] == 1'b1 ) begin
                        detect_prep_NOP_CALL = 1'b1;
               
                        next_state_CALL = IDLE;
                        
                        if ( is_nop_call(commit_instr_i[1]) )    begin
                            detect_NOP_CALL = 1'b1;
                         end
                    end
     
                end else 
                if( (commit_ack_o[1] == 1'b1)                  && 
                    (commit_instr_i[1].ex.valid == 1'b0)       && 
                    is_call(commit_instr_i[1]) )                begin
                            next_state_CALL = WAITS_NOP;
                            detect_CALL = 1'b1;
                end
            end
            WAITS_NOP : begin
               next_state_CALL = WAITS_NOP;
               
               // only check the first one because means that the jalr was on the commit_instr_i[0] and commit_instr_i[1] was not commited at the same time 
               // or on commit_instr_i[1] and not the ret is on commit[0]
               if ( (prev_entry != commit_instr_i[0])   &&
                    (commit_ack_o[0] == 1'b1))          begin
                    
                    detect_prep_NOP_CALL = 1'b1;
                    next_state_CALL = IDLE;
               
                    if ( is_nop_call(commit_instr_i[0]) )    begin
                            detect_NOP_CALL = 1'b1;
                     end
               end
           end
           default :
               begin 
                    next_state_CALL = IDLE;
               end 
        endcase
    end 

   // registers
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            state_RET <= IDLE;
            state_CALL <= IDLE;

            prev_detect_CALL <= '0;
            prev_detect_RET  <= '0;
            prev_entry <= '0;
         end else begin 
            state_CALL <= next_state_CALL;
            state_RET <= next_state_RET;

            prev_detect_RET  <= detect_RET; 
            prev_detect_CALL <= detect_CALL;
            prev_entry <= commit_instr_i[0];
         end
    end
   
    
    //assign leds[0] = csr_en_i;

    // assign the exception
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            exception_o.valid <= 1'b0;
            exception_o.cause <= '0;
            exception_o.tval  <= '0;
         end else begin
            if( detect_prep_NOP_CALL && !detect_NOP_CALL && csr_en_i) begin
                exception_o.cause <= riscv::BREAKPOINT;
                exception_o.valid <= 1'b1;
                //exception_o.tval <= commit_instr_i[0].pc;
            end else 
            if( detect_prep_NOP_RET && !detect_NOP_RET && csr_en_i) begin
                exception_o.cause <= riscv::BREAKPOINT;
                exception_o.valid <= 1'b1;
                //exception_o.tval <= commit_instr_i[0].pc;
            end else begin 
                exception_o.valid <= 1'b0;
                exception_o.cause <= '0;
                
            end
         end
    end
    
    
    
    logic prev_nop_ret, prev_nop_call;  
    logic[9:0] leds_s;
    
    //assign leds = '0;
    //assign leds[0] = detect_prep_NOP_CALL;
    //assign leds[1] = detect_NOP_CALL;
    //assign leds[2] = detect_prep_NOP_RET;
    //assign leds[3] = detect_NOP_RET;
    
   assign leds = leds_s;
         
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
           
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
            
            leds_s[4] = csr_en_i;
            
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

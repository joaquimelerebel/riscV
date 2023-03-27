`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: "Les Vieux Briscards" for 3rd national RISC-V student contest 2022-2023

// This module will check whether returns are followed by nop with immediate #1
// If a function reutrns and the instruction commited after is not a nop, an exception 
// and cfi_signal is issued.
// cfi_signal will have the effect of setting pc to 0 and therefore crashing the core. 

// This module works hands in hands with the nop call detector

//////////////////////////////////////////////////////////////////////////////////


module parser_nop_custom_commit_ret #(
    parameter nop_op = ariane_pkg::ADD,
    parameter nop_rd  = 5'b0,
    parameter nop_rs1  = 5'b0,
    parameter nop_imm = 2'b1,
    parameter NR_COMMIT_PORTS = 2
)
(
    input  logic                                                    clk_i,
    input  logic                                                    rst_ni,
    input  logic                                                    flush_i,
    input  logic                                                    csr_en_i,
    // does the commit stages wants to commit the nth instruction
    input logic [NR_COMMIT_PORTS-1:0]                               commit_ack_i,
    // what instruction will be commited
    input  ariane_pkg::scoreboard_entry_t [NR_COMMIT_PORTS-1:0]     commit_instr_i,
    output logic[3:0]                                               leds,
    output logic                                                    cfi_signal,
    output ariane_pkg::exception_t                                  exception_o
);
    
    enum int unsigned { IDLE, WAITS_NOP } state, next_state;
    
    logic detect_RET, detect_NOP, prev_nop, prev_ret, detect_prep_NOP, prev_prep_nop, prev_ex;
       
    ariane_pkg::scoreboard_entry_t prev_entry;



function logic is_ret(ariane_pkg::scoreboard_entry_t entry);
        if( (entry.op == ariane_pkg::JALR)  &&
            (entry.rd[5:0] == 6'b0)         &&
            (entry.rs1[5:0] == 6'h1 ) )     begin
            is_ret = 1'b1;
        end else begin 
            is_ret = 1'b0;
        end
endfunction


function logic is_nop(ariane_pkg::scoreboard_entry_t entry);
        if( (entry.op == nop_op)                &&
            (entry.rd[4:0] == nop_rd)           &&
            (entry.rs1[4:0] == nop_rs1)         &&
            (entry.result[1:0] == nop_imm))     begin
            is_nop = 1'b1;
        end else begin 
            is_nop = 1'b0;
        end
endfunction


    /*state machine*/
    always_comb begin        
        detect_RET = 1'b0;
        detect_prep_NOP = 1'b0;
        detect_NOP = 1'b0;
        
        // FSM
        case( state ) 
            IDLE : begin
                next_state = IDLE;
                
                // detect the return
                if( (commit_ack_i[0] == 1'b1)                   && 
                    (commit_instr_i[0].ex.valid == 1'b0)        && 
                    is_ret(commit_instr_i[0]) )                 begin
                        next_state = WAITS_NOP;
                        detect_RET = 1'b1;
                    
                    // check if the ret is in the second that might be ACK at the same time 
                    if( commit_ack_i[1] == 1'b1 ) begin
                        detect_prep_NOP = 1'b1;
               
                        next_state = IDLE;
                        
                        if ( is_nop(commit_instr_i[1]) )    begin
                            detect_NOP = 1'b1;
                         end
                    end
     
                end else 
                if( (commit_ack_i[1] == 1'b1)                  && 
                    (commit_instr_i[1].ex.valid == 1'b0)       && 
                    is_ret(commit_instr_i[1]) )                begin
                            next_state = WAITS_NOP;
                            detect_RET = 1'b1;
                end
            end
            WAITS_NOP : begin
               next_state = WAITS_NOP;
               
               // only check the first one because means that the jalr was on the commit_instr_i[0] and commit_instr_i[1] was not commited at the same time 
               // or on commit_instr_i[1] and not the ret is on commit[0]
               if ( (prev_entry != commit_instr_i[0])   &&
                    (commit_ack_i[0] == 1'b1))          begin
                    
                    detect_prep_NOP = 1'b1;
                    next_state = IDLE;
               
                    if ( is_nop(commit_instr_i[0]) )    begin
                            detect_NOP = 1'b1;
                     end
                     
                     if( (commit_ack_i[1] == 1'b1)                  && 
                         (commit_instr_i[1].ex.valid == 1'b0)       && 
                         is_ret(commit_instr_i[1]) )                begin
                            next_state = WAITS_NOP;
                            detect_RET = 1'b1;
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
            prev_entry <= commit_instr_i[0];
         end
    end
   
   
    ariane_pkg::exception_t ex_d;
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            ex_d.valid <= 1'b0;
            ex_d.cause <= '0;
            ex_d.tval  <= '0;
           // cfi_signal <= 1'b0;
         end else begin
            if(detect_prep_NOP && !detect_NOP && csr_en_i) begin
                ex_d.cause <= riscv::ILLEGAL_INSTR;
                ex_d.valid <= 1'b1;
                ex_d.tval <= prev_entry.pc;
                //cfi_signal <= 1'b1;
            end else begin 
                ex_d.valid <= 1'b0;
                ex_d.cause <= '0;
                ex_d.tval <= '0;
                //cfi_signal <= 1'b0;
            end
         end
    end
    
    
    int counter;
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            counter = 0;
            exception_o = '0;
            cfi_signal = '0;
         end else begin
            cfi_signal = '0;
            exception_o = '0;
             
            if( ex_d.valid || counter > 0 ) begin
                exception_o = ex_d;
                cfi_signal = '1; 
                counter = counter + 1;
                if(counter > 10) begin
                    counter = 0; 
                end
            end 
         end
    end
    
    
   
   //keep the exception going for 2 clock cycles
    
   logic[3:0] leds_s; 
   assign leds = leds_s;
         
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            prev_nop <= 1'b0;
            prev_ret <= 1'b0;
            prev_prep_nop <= 1'b0;
            prev_ex <= 1'b0;
            leds_s <= '0;
         end else begin
            prev_ret <= detect_RET;
            prev_nop <= detect_NOP;
            prev_prep_nop <= detect_prep_NOP;
            prev_ex <= exception_o.valid;
            
            if((prev_ret == 1'b0) && (detect_RET == 1'b1)) begin
                leds_s[0] <= !leds_s[0]; 
            end 
            
            if((prev_prep_nop == 1'b0) && (detect_prep_NOP == 1'b1)) begin
                leds_s[1] <= !leds_s[1];
                //leds_s[6:0] <= entry_score_i.op[6:0]; 
            end 
            
            if((prev_nop == 1'b0) && (detect_NOP == 1'b1)) begin 
                leds_s[2] <= !leds_s[2];
                
            end 
            
            if((prev_ex == 1'b0) && (exception_o.valid == 1'b1)) begin 
                leds_s[3] <= !leds_s[3];
                
            end 
            
         end
    end
    
endmodule

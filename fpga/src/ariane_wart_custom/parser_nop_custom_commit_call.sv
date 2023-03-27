`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: "Les Vieux Briscards" for 3rd national RISC-V student contest 2022-2023  

// This module will check whether calls are followed by nop with immediate #2
// in the case of an indirect call, the number of arguments of the called function 
// is put in a CSR, we get it in csr_indi_nb_args_i and we compare it with 
// nop.imm[10:2] which are the arguments taken by the function.
// If a function is called and not followed by the right nop, an exception and cfi_signal
// is issued.
// cfi_signal will have the effect of setting pc to 0 and therefore crashing the core. 

// This module works hands in hands with the nop ret detector

//////////////////////////////////////////////////////////////////////////////////

module parser_nop_custom_commit_call #(
    parameter nop_op = ariane_pkg::ADD,
    parameter nop_rd  = 5'b0,
    parameter nop_rs1  = 5'b0,
    parameter nop_imm = 2'h2,
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
    output logic[4:0]                                               leds, 
    // signal that their is an error -> put pc to 0 (needs to change for a proposer exception)
    output logic                                                    cfi_signal,
    // number of arguments from the csr (assigned when indirect call will come)
    input  logic[8:0]                                               csr_indi_nb_args_i,
    // reset the csr to all 1's so that we can 
    output logic                                                    rst_nop_id_csr_o,
    output ariane_pkg::exception_t                                  exception_o
);
    
    enum int unsigned { IDLE, WAITS_NOP } state, next_state;
    
    logic detect_CALL, detect_NOP, prev_nop, prev_ret, detect_prep_NOP, prev_prep_nop, prev_ex;
       
    ariane_pkg::scoreboard_entry_t prev_entry;
    
    logic rst_csr_q, rst_csr_d;


function logic is_call(ariane_pkg::scoreboard_entry_t entry);
        if( (   ( entry.op == ariane_pkg::JALR ) || 
                (entry.op == ariane_pkg::JAL) )  &&
                (entry.rd[5:0] == 6'b1) )     begin
            is_call = 1'b1;
        end else begin 
            is_call = 1'b0;
        end
endfunction

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

// check if their is the right number of args in the case of an indirect call
function logic is_args_ok(ariane_pkg::scoreboard_entry_t entry);
        is_args_ok = '0;
        if(csr_indi_nb_args_i != '1) begin
            // variadic case
            if( entry.result[11] && ( entry.result[10:2] >= csr_indi_nb_args_i ) )  begin
                is_args_ok = '1; 
            end else 
            // non variadic case
            if( !entry.result[11] && ( entry.result[10:2] == csr_indi_nb_args_i ) ) begin
                is_args_ok = '1;
            end 
        end else begin
            is_args_ok = '1; 
        end 
            
endfunction


    /*state machine*/
    always_comb begin        
        detect_CALL = 1'b0;
        detect_prep_NOP = 1'b0;
        detect_NOP = 1'b0;
        rst_csr_d = 1'b0;
        
        if( !csr_en_i ) begin
            rst_csr_d = 1'b1;
        end
        
        // FSM
        case( state ) 
            IDLE : begin
                next_state = IDLE;
                
                // detect the call
                if( (commit_ack_i[0] == 1'b1)                   && 
                    (commit_instr_i[0].ex.valid == 1'b0)        && 
                    is_call(commit_instr_i[0]) )                begin
                        next_state = WAITS_NOP;
                        detect_CALL = 1'b1;
                    
                    // check if the ret is in the second that might be ACK at the same time 
                    if( commit_ack_i[1] == 1'b1 ) begin
                        detect_prep_NOP = 1'b1;
               
                        next_state = IDLE;
                        
                        if ( is_nop(commit_instr_i[1]) && is_args_ok(commit_instr_i[1]) )    begin
                            detect_NOP = 1'b1;
                        end
                        rst_csr_d = 1'b1;
                    end
     
                end else 
                if( (commit_ack_i[1] == 1'b1)                  && 
                    (commit_instr_i[1].ex.valid == 1'b0)       && 
                    is_call(commit_instr_i[1]) )                begin
                            next_state = WAITS_NOP;
                            detect_CALL = 1'b1;
                end
            end
            WAITS_NOP : begin
               next_state = WAITS_NOP;
               
               // only check the first one because means that the jalr was on the commit_instr_i[0] and commit_instr_i[1] was not commited at the same time 
               // or on commit_instr_i[1] and not the ret is on commit[0]
               if ( (prev_entry != commit_instr_i[0])   &&
                    (commit_ack_i[0] == 1'b1)           && 
                    (commit_instr_i[0].ex.valid == 1'b0) )          begin
                    
                    detect_prep_NOP = 1'b1;
                    next_state = IDLE;
               
                    if ( is_nop(commit_instr_i[0]) && is_args_ok(commit_instr_i[0]))    begin
                            detect_NOP = 1'b1;
                    end
                    rst_csr_d = 1'b1;
                    
                    if( (commit_ack_i[1] == 1'b1)                  && 
                        (commit_instr_i[1].ex.valid == 1'b0)       && 
                        is_call(commit_instr_i[1]) )                begin
                            next_state = WAITS_NOP;
                            detect_CALL = 1'b1;
                    end
                         
               end
           end
           default :
               begin 
                    next_state = IDLE;
               end 
        endcase
    end 
    
    
    assign rst_nop_id_csr_o = rst_csr_q;
   
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            state <= IDLE;
            prev_entry <= '0;
            rst_csr_q <= '0;
         end else begin 
            state <= next_state;
            prev_entry <= commit_instr_i[0];
            rst_csr_q <= rst_csr_d;
         end
    end
   
    ariane_pkg::exception_t  ex_d; 
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            ex_d.valid <= 1'b0;
            ex_d.cause <= '0;
            ex_d.tval  <= '0;
            //cfi_signal <= 1'b0;
         end else begin
            if(detect_prep_NOP && !detect_NOP && csr_en_i) begin
                ex_d.cause <= riscv::ILLEGAL_INSTR;
                ex_d.valid <= 1'b1;
                ex_d.tval <= prev_entry.pc;
                //cfi_signal <= 1'b1;
            end else begin 
                ex_d.valid <= 1'b0;
                ex_d.cause <= '0;
                ex_d.tval  <= '0;
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
    
    
   
   logic[4:0] leds_s;
   assign leds = leds_s;
         
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            prev_nop <= 1'b0;
            prev_ret <= 1'b0;
            prev_prep_nop <= 1'b0;
            prev_ex <= '0;
            leds_s <= '0;
         end else begin
            prev_ret <= detect_CALL;
            prev_nop <= detect_NOP;
            prev_prep_nop <= detect_prep_NOP;
            prev_ex <= exception_o.valid;
            leds_s[4] <= csr_en_i;
            
            //leds_s[3:0] <= prev_entry.fu;
            //leds_s[9:6] <= prev_entry.result[4:0];
            
            
            if((prev_ret == 1'b0) && (detect_CALL == 1'b1)) begin
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

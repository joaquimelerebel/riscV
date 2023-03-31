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

module fw_cfi_shadow_stack #(
    parameter nop_op = ariane_pkg::ADD,
    parameter nop_rd  = 5'b0,
    parameter nop_rs1  = 5'b0,
    parameter nop_imm = 2'h2,
    parameter NR_COMMIT_PORTS = 2,
    parameter SHADOW_STACK_SIZE = 100
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
    output logic[9:0]                                               leds, 
    // signal that their is an error -> put pc to 0 (needs to change for a proposer exception)
    output logic                                                    cfi_signal,
    // number of arguments from the csr (assigned when indirect call will come)
    input  logic[8:0]                                               csr_indi_nb_args_i,
    // reset the csr to all 1's so that we can identify reset from no args 
    output logic                                                    rst_nop_id_csr_o,
    output ariane_pkg::exception_t                                  exception_o
);
    
    enum int unsigned { IDLE, WAITS_NOP } state_fw_cfi, next_state_fw_cfi;
    
    logic detect_CALL, detect_NOP, prev_nop, prev_ret, detect_prep_NOP, prev_prep_nop, prev_ex;
    logic prev_call, prev_prep_ss, prev_good_ret;
     
    ariane_pkg::scoreboard_entry_t prev_entry;
    
    logic rst_csr_q, rst_csr_d;


function logic is_call(ariane_pkg::scoreboard_entry_t entry);
        if( (   ( entry.op == ariane_pkg::JALR ) || 
                (entry.op == ariane_pkg::JAL) )  &&
                ( (entry.rd[5:0] == 6'b1)        || 
                  (entry.rd[5:0] == 6'h5) ) )    begin
            is_call = 1'b1;
        end else begin 
            is_call = 1'b0;
        end
endfunction

function logic is_ret(ariane_pkg::scoreboard_entry_t entry);
        if( (entry.op == ariane_pkg::JALR)  &&
            (entry.rd[5:0] == 6'b0)         &&
            ( (entry.rs1[5:0] == 6'h1 )     ||
              (entry.rs1[5:0] == 6'h5) ) )  begin
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

///////////////////////////////////////////////////////////////////////
////////              Forward ControlFlow Integrity          //////////             
///////////////////////////////////////////////////////////////////////


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
        case( state_fw_cfi ) 
            IDLE : begin
                next_state_fw_cfi = IDLE;
                
                // detect the call
                if( (commit_ack_i[0] == 1'b1)                   && 
                    (commit_instr_i[0].ex.valid == 1'b0)        && 
                    is_call(commit_instr_i[0]) )                begin
                        next_state_fw_cfi = WAITS_NOP;
                        detect_CALL = 1'b1;
                    
                    // check if the call is in the second that might be ACK at the same time 
                    if( commit_ack_i[1] == 1'b1 ) begin
                        detect_prep_NOP = 1'b1;
               
                        next_state_fw_cfi = IDLE;
                        
                        if ( is_nop(commit_instr_i[1] ) && is_args_ok(commit_instr_i[1]) )    begin
                            detect_NOP = 1'b1;
                        end
                        rst_csr_d = 1'b1;
                    end
     
                end else 
                if( (commit_ack_i[1] == 1'b1)                  && 
                    (commit_instr_i[1].ex.valid == 1'b0)       && 
                    is_call(commit_instr_i[1]) )                begin
                            next_state_fw_cfi = WAITS_NOP;
                            detect_CALL = 1'b1;
                end
            end
            WAITS_NOP : begin
               next_state_fw_cfi = WAITS_NOP;
               
               // only check the first one because means that the jalr was on the commit_instr_i[0] and commit_instr_i[1] was not commited at the same time 
               // or on commit_instr_i[1] and not the ret is on commit[0]
               if ( (prev_entry != commit_instr_i[0])   &&
                    (commit_ack_i[0] == 1'b1)           && 
                    (commit_instr_i[0].ex.valid == 1'b0) )          begin
                    
                    detect_prep_NOP = 1'b1;
                    next_state_fw_cfi = IDLE;
               
                    if ( is_nop(commit_instr_i[0]) && is_args_ok(commit_instr_i[0]))    begin
                            detect_NOP = 1'b1;
                    end
                    rst_csr_d = 1'b1;
                    
                    if( (commit_ack_i[1] == 1'b1)                  && 
                        (commit_instr_i[1].ex.valid == 1'b0)       && 
                        is_call(commit_instr_i[1]) )                begin
                            next_state_fw_cfi = WAITS_NOP;
                            detect_CALL = 1'b1;
                    end
                         
               end
           end
           default :
               begin 
                    next_state_fw_cfi = IDLE;
               end 
        endcase
    end 
    
    
    assign rst_nop_id_csr_o = rst_csr_q;
   
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            state_fw_cfi <= IDLE;
            prev_entry <= '0;
            rst_csr_q <= '0;
         end else begin 
            state_fw_cfi <= next_state_fw_cfi;

            if(commit_ack_i[0]) begin
                prev_entry <= commit_instr_i[0];
            end else begin
                prev_entry <= prev_entry;
            end
            
            rst_csr_q <= rst_csr_d;
         end
    end
   
///////////////////////////////////////////////////////////////////////
////////                     shadow stack                    //////////             
///////////////////////////////////////////////////////////////////////   
   
logic [riscv::XLEN-1:0]         data_i_stack, data_o_stack;
logic                           push_s_s, pop_s_s;
logic                           full_ss;

logic                           detect_RET, detect_GOOD_RET, detect_prep_SS;

enum int unsigned { IDLE_SS, WAITS_PC } state_shadow_stack, next_state_shadow_stack;

ras_shadow_stack #(
   .DATA_W(riscv::XLEN),
   .DEPTH(SHADOW_STACK_SIZE)                             
)
ras_shadow_stack
(
   .clk(clk_i),
   .rstn(rst_ni),
   
   .i_push(push_s_s),
   .i_data(data_i_stack),                   
   .o_full(full_ss), // check the flag in input

   .i_pop(pop_s_s),
   .o_data(data_o_stack),                   
   .o_empty() //check the flag
);   

// add elements to the stack
always_ff @(posedge clk_i) begin
    if(!rst_ni) begin
        push_s_s <= '0;
        pop_s_s <= '0;
        data_i_stack <= '0;
        state_shadow_stack <= IDLE_SS;
    end else begin
        push_s_s <= '0;
        pop_s_s <= '0;
        data_i_stack <= '0;
        state_shadow_stack <= next_state_shadow_stack;
        
        // add the return address to the stack
        if(     (commit_ack_i[0] == 1'b1)                   && 
                (commit_instr_i[0].ex.valid == 1'b0)        && 
                is_call( commit_instr_i[0]) )               begin
                
                data_i_stack <= commit_instr_i[0].pc + 4;
                push_s_s <= '1;
        end else 
        // cannot do 0 and 1 at the same time otherwise their is a problem in fw edge
        if(     (commit_ack_i[1] == 1'b1)                   && 
                (commit_instr_i[1].ex.valid == 1'b0)        && 
                is_call(commit_instr_i[1]) )                begin
                
                data_i_stack <= commit_instr_i[1].pc + 4;
                push_s_s <= '1;
        end            
        
        // detect that SS was used 
        if(detect_GOOD_RET) begin
            pop_s_s <= '1;
        end
    end
end   

/*state machine for the shadow stack*/
always_comb begin        
    detect_RET = 1'b0;
    detect_prep_SS = 1'b0;
    detect_GOOD_RET = 1'b0;
    
    // FSM
    case( state_shadow_stack ) 
        IDLE_SS : begin
            next_state_shadow_stack = IDLE_SS;
            
            // detect the return
            if( (commit_ack_i[0] == 1'b1)                   && 
                (commit_instr_i[0].ex.valid == 1'b0)        && 
                is_ret(commit_instr_i[0]) )                begin
                    next_state_shadow_stack = WAITS_PC;
                    detect_RET = 1'b1;
                
                // check if the return is in the second that might be ACK at the same time 
                if( commit_ack_i[1] && !commit_instr_i[1].ex.valid ) begin
                    detect_prep_SS = 1'b1;
           
                    next_state_shadow_stack = IDLE_SS;
                    
                    if ( data_o_stack == commit_instr_i[1].pc )    begin
                         detect_GOOD_RET = 1'b1;
                    end
                end
 
            end else 
            if( (commit_ack_i[1] == 1'b1)                  && 
                (commit_instr_i[1].ex.valid == 1'b0)       && 
                is_ret(commit_instr_i[1]) )                begin
                        next_state_shadow_stack = WAITS_PC;
                        detect_RET = 1'b1;
            end
        end
        WAITS_PC : begin
           next_state_shadow_stack = WAITS_PC;
           
           // only check the first one because means that the jalr was on the commit_instr_i[0] and commit_instr_i[1] was not commited at the same time 
           // or on commit_instr_i[1] and not the ret is on commit[0]
           if ( (prev_entry != commit_instr_i[0])   &&
                commit_ack_i[0]                     && 
                !commit_instr_i[0].ex.valid )       begin
                
                detect_prep_SS = 1'b1;
                next_state_shadow_stack = IDLE_SS;
           
                if ( data_o_stack == commit_instr_i[0].pc )    begin
                
                        detect_GOOD_RET = 1'b1;
                end
                
                if( commit_ack_i[1]                  && 
                    !commit_instr_i[1].ex.valid      && 
                    is_ret(commit_instr_i[1]) )                begin
                    
                        next_state_shadow_stack = WAITS_PC;
                        detect_RET = 1'b1;
                end
                     
           end
       end
       default :
           begin 
                next_state_shadow_stack = IDLE_SS;
           end 
    endcase
end 

   
///////////////////////////////////////////////////////////////////////
///////                      EXCEPTION                       //////////             
///////////////////////////////////////////////////////////////////////
   
   
    ariane_pkg::exception_t  ex_d, ex_q; 
    
    logic is_ss_det, is_nop_det, is_full_det;
    
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
        
            ex_d.valid <= 1'b0;
            ex_d.cause <= '0;
            ex_d.tval  <= '0;
            is_nop_det <= '0;
            is_ss_det <= '0;
            is_full_det <= '0;
         end else begin
         
            is_nop_det <= '0;
            is_ss_det <= '0;
            is_full_det <= '0;
            ex_d.valid <= 1'b0;
            ex_d.cause <= '0;
            ex_d.tval  <= '0;
            
            if( detect_prep_SS && !detect_GOOD_RET  && csr_en_i ) begin
                
                ex_d.cause <= riscv::ILLEGAL_INSTR;
                ex_d.valid <= 1'b1;
                ex_d.tval <= prev_entry.pc;
                is_ss_det <= '1;
            end else 
            if( full_ss && csr_en_i) begin
                
                ex_d.cause <= riscv::ILLEGAL_INSTR;
                ex_d.valid <= 1'b1;
                ex_d.tval <= prev_entry.pc;
                is_full_det <= '1;
            end else 
            if( detect_prep_NOP && !detect_NOP && csr_en_i) begin 
                
                ex_d.cause <= riscv::ILLEGAL_INSTR;
                ex_d.valid <= 1'b1;
                ex_d.tval <= prev_entry.pc;
                is_nop_det <= '1;
            end
         end
    end
   
    
    int counter;
    assign exception_o = ex_q;
    
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
        
            counter <= 0;
            ex_q <= '0;
            cfi_signal <= '0;
         end else begin
         
            cfi_signal <= '0;
        
            if( ex_d.valid ) begin
            
                ex_q <= ex_d;
                counter <= counter + 1;
            end else 
            if( counter > 0 ) begin
            
                cfi_signal <= '1; 
                ex_q <= ex_q;
                counter <= counter + 1;
                if(counter > 3) begin
                    counter <= 0; 
                end
            end else 
            begin
                ex_q <= '0;
            end
         end
    end
    
   
   logic[9:0] leds_s;
   assign leds = leds_s;
         
    always_ff @(posedge clk_i) begin
        if(rst_ni == 1'b0) begin 
            prev_nop <= 1'b0;
            prev_ret <= 1'b0;
            prev_call <= 1'b0;
            prev_prep_ss <= 1'b0;
            prev_prep_nop <= 1'b0;
            prev_good_ret <= 1'b0;
            prev_ex <= '0;
            leds_s <= '0;
         end else begin
         
            prev_call <= detect_CALL;
            prev_nop <= detect_NOP;
            prev_prep_nop <= detect_prep_NOP;
            
            prev_ret <= detect_RET;
            prev_prep_ss <= detect_prep_SS;
            prev_good_ret <= detect_GOOD_RET;
            
            prev_ex <= exception_o.valid;
            
            leds_s[9] <= csr_en_i;
            
            /*if((prev_call == 1'b0) && (detect_CALL == 1'b1)) begin
                leds_s[0] <= !leds_s[0]; 
            end 
            
            if((prev_prep_nop == 1'b0) && (detect_prep_NOP == 1'b1)) begin
                leds_s[1] <= !leds_s[1];
            end 
            
            if((prev_nop == 1'b0) && (detect_NOP == 1'b1)) begin 
                leds_s[2] <= !leds_s[2];                
            end*/ 
            
            if((prev_ex == 1'b0) && (exception_o.valid == 1'b1) && (is_ss_det) ) begin 
                leds_s[0] <= !leds_s[0];  
            end else 
            if((prev_ex == 1'b0) && (exception_o.valid == 1'b1) && (is_nop_det) ) begin 
                leds_s[1] <= !leds_s[1];  
            end else 
            if((prev_ex == 1'b0) && (exception_o.valid == 1'b1) && (is_full_det) ) begin 
                leds_s[2] <= !leds_s[2];  
            end
            
            if((prev_ret == 1'b0) && (detect_RET == 1'b1)) begin 
                leds_s[5] <= !leds_s[5];  
            end 
            if((prev_prep_ss == 1'b0) && (detect_prep_SS == 1'b1)) begin 
                leds_s[6] <= !leds_s[6];  
            end 
            if((prev_good_ret == 1'b0) && (detect_GOOD_RET == 1'b1)) begin 
                leds_s[7] <= !leds_s[7];  
            end 
         end
    end
    
    
    
///////////////////////////////////////////////////////////////////////
///////                         DEBUG                        //////////             
///////////////////////////////////////////////////////////////////////

always @ (posedge clk_i) begin
    // print if detected a ss probleme
    if(is_ss_det) begin
        $display("ss probleme around : %x", commit_instr_i[0].pc);
    end else 
    if(is_nop_det) begin
        $display("fw cfi probleme around : %x", commit_instr_i[0].pc);
    end
    
end 
    
    
endmodule

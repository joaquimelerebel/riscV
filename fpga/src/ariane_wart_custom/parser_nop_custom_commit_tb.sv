`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2023 07:14:26 PM
// Design Name: 
// Module Name: parser_nop_custom_commit_tb
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


module parser_nop_custom_commit_tb
();

logic                                                   commit_ack;
ariane_pkg::scoreboard_entry_t                   commit_instr;
ariane_pkg::exception_t                                 exception;


ariane_pkg::scoreboard_entry_t                    commit_instr_table[];

logic clk_i;

always
  begin
    #5 clk_i = 1;
    #5 clk_i = 0;
end


initial begin 
    commit_instr_table[0] = trash;
    commit_instr_table[1] = trash;
    commit_instr_table[2] = call_jalr;
    commit_instr_table[3] = nop_call;
    
    commit_instr_table[4] = trash;
    commit_instr_table[5] = trash;
    commit_instr_table[6] = call_jal;
    commit_instr_table[7] = nop_call;
    
    commit_instr_table[8] = trash;
    commit_instr_table[9] = trash;
    commit_instr_table[10] = call_jal;
    commit_instr_table[11] = nop_call;
    
    commit_instr_table[8] = trash;
    commit_instr_table[9] = trash;
    commit_instr_table[10] = ret;
    commit_instr_table[11] = nop_ret;
    
    commit_instr_table[12] = trash;
    commit_instr_table[13] = trash;
    commit_instr_table[14] = ret;
    commit_instr_table[15] = nop_ret;
    commit_instr_table[16] = call_jal;
    commit_instr_table[17] = nop_call;
    
    foreach (commit_instr_table[i]) begin
        commit_instr = commit_instr_table[i]; 
        #5;
    end 
end 

parser_nop_custom_commit_call 
(
    .clk_i,
    .rst_n('1),
    .flush_i('0),
    .csr_en_i('1),
    // does the commit stages wants to commit the nth instruction
    .commit_ack_o(commit_ack),
    // what instruction will be commited
    .commit_instr_i(commit_instr),
    .leds(), 
    .exception_o(exception)
);


ariane_pkg::scoreboard_entry_t call_jalr = '{
                                    pc : '0,
                                    trans_id:'0,
                                    fu : ariane_pkg::CTRL_FLOW,
                                    op : ariane_pkg::JALR,
                                    rs1 : 32'h0,
                                    rs2 : 32'h0,
                                    rd : 32'h1,
                                    use_imm : '0,
                                    use_zimm : '0,
                                    use_pc : '0,
                                    bp : '0,
                                    is_compressed : '0,
                                    result : 32'h0,
                                    valid : '1,
                                    ex : '0
                                };
  
 ariane_pkg::scoreboard_entry_t ret = '{
                                    pc : '0,
                                    trans_id:'0,
                                    fu : ariane_pkg::CTRL_FLOW,
                                    op : ariane_pkg::JALR,
                                    rs1 : 32'h1,
                                    rs2 : 32'h0,
                                    rd : 32'h0,
                                    use_imm : '0,
                                    use_zimm : '0,
                                    use_pc : '0,
                                    bp : '0,
                                    is_compressed : '0,
                                    result : 32'h0,
                                    valid : '1,
                                    ex : '0
                                }; 
  
ariane_pkg::scoreboard_entry_t call_jal = '{
                                    pc : '0,
                                    trans_id:'0,
                                    fu : ariane_pkg::CTRL_FLOW,
                                    op : ariane_pkg::JAL,
                                    rs1 : 32'h0,
                                    rs2 : 32'h0,
                                    rd : 32'h1,
                                    use_imm : '0,
                                    use_zimm : '0,
                                    use_pc : '0,
                                    bp : '0,
                                    is_compressed : '0,
                                    result : 32'h0,
                                    valid : '1,
                                    ex : '0
                                };
            
 ariane_pkg::scoreboard_entry_t trash = '{
                                    pc : '0,
                                    trans_id:'0,
                                    fu : ariane_pkg::ALU,
                                    op : ariane_pkg::ADD,
                                    rs1 : 32'h2,
                                    rs2 : 32'h3,
                                    rd : 32'h3,
                                    use_imm : '1,
                                    use_zimm : '0,
                                    use_pc : '0,
                                    bp : '0,
                                    is_compressed : '0,
                                    result : 32'h20,
                                    valid : '1,
                                    ex : '0
                                };

ariane_pkg::scoreboard_entry_t nop_ret = '{
                                    pc : '0,
                                    trans_id:'0,
                                    fu : ariane_pkg::ALU,
                                    op : ariane_pkg::ADD,
                                    rs1 : '0,
                                    rs2 : '0,
                                    rd : '0,
                                    use_imm : '1,
                                    use_zimm : '0,
                                    use_pc : '0,
                                    bp : '0,
                                    is_compressed : '0,
                                    result : 32'h1,
                                    valid : '1,
                                    ex : '0
                                };
                                
ariane_pkg::scoreboard_entry_t nop_call = '{
                                    pc : '0,
                                    trans_id:'0,
                                    fu : ariane_pkg::ALU,
                                    op : ariane_pkg::ADD,
                                    rs1 : '0,
                                    rs2 : '0,
                                    rd : '0,
                                    use_imm : '1,
                                    use_zimm : '0,
                                    use_pc : '0,
                                    bp : '0,
                                    is_compressed : '0,
                                    result : 32'h2,
                                    valid : '1,
                                    ex : '0
                                };

endmodule

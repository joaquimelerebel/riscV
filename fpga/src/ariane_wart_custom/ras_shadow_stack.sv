/*===============================================================================================================================
   Design       : Single-clock Synchronous LIFO/Stack
   Description  : Fully synthesisable, configurable Single-clock Synchronous LIFO/Stack based on registers.
                  - Configurable Data width.
                  - Configurable Depth.
                  - Push and increment / decrement and pop -- pointer mode.
                  - All status signals have zero cycle latency.
                  
   Developer    : Mitu Raj, chip@chipmunklogic.com at Chipmunk Logic ™, https://chipmunklogic.com
   Date         : Oct-02-2021
   
   Modified to fit the need of the Shadow Stack with an address space more important than the check space
   we count the number of call but we disable the shadow stack when it is full, when we detect the counter is comming back
   to a number addressable by the SS we re enable it.
===============================================================================================================================*/

module ras_shadow_stack #(
                    parameter DATA_W     = 4           ,        // Data width
                    parameter ADD_DEPTH  = 32          ,        // 2^ADD_DEPTH is the number of call that can be made  
                    parameter REAL_DEPTH = 100                  // Depth of Stack                             
                 )

                (
                   input                   clk         ,        // Clock
                   input                   rstn        ,        // Active-low Synchronous Reset
                   
                   input                   i_push      ,        // Push
                   input  [DATA_W - 1 : 0] i_data      ,        // Write-data                   
                   output                  o_full      ,        // Full signal

                   input                   i_pop       ,        // Pop
                   output [DATA_W - 1 : 0] o_data      ,        // Read-data                   
                   output                  o_empty     ,        // Empty signal
                   output                  o_usable_res         // is the output ok for address check or not 
                );


/*-------------------------------------------------------------------------------------------------------------------------------
   Internal Registers/Signals
-------------------------------------------------------------------------------------------------------------------------------*/
logic [DATA_W - 1 : 0]        stack [REAL_DEPTH]      ;
logic [ADD_DEPTH-1 : 0]       stack_ptr_rg            ;
logic                         push, pop, full, empty, usable  ;


/*-------------------------------------------------------------------------------------------------------------------------------
   Synchronous logic to push and pop from Stack
-------------------------------------------------------------------------------------------------------------------------------*/
always @ (posedge clk) begin
   
   // Reset
   if (!rstn) begin       
      
      stack        <= '{default: 1'b0} ;
      stack_ptr_rg <= 0                ;

   end
   
   // Out of Reset
   else begin      
      
      // Push to Stack    
      if (push && !full) begin
         stack [stack_ptr_rg] <= i_data    ;               
      end
      
      // Stack pointer update
      if (push & !pop) begin
         stack_ptr_rg <= stack_ptr_rg + 1  ;
      end
      else if (!push & pop) begin
         stack_ptr_rg <= stack_ptr_rg - 1  ;
      end
    
   end

end


/*-------------------------------------------------------------------------------------------------------------------------------
   Continuous Assignments
-------------------------------------------------------------------------------------------------------------------------------*/
assign full    = (stack_ptr_rg == REAL_DEPTH)               ;
assign usable  = (stack_ptr_rg <= REAL_DEPTH)               ;
assign empty   = (stack_ptr_rg == 0         )               ;

assign push    = i_push & !full                        ;
assign pop     = i_pop  & !empty                       ;

assign o_full  = full                                  ;
assign o_usable_res = usable                           ; 
assign o_empty = empty                                 ;  

assign o_data  = (empty && usable) ? '0 : stack [stack_ptr_rg - 1] ;   


/*---------------------------
    DEBUG
 ----------------------------*/
 
always @ (posedge clk) begin
    if(push) begin
        $display("ss : push of = %x, at pos : %d",i_data, stack_ptr_rg);
    end
end 
 
 

endmodule

/*=============================================================================================================================*/
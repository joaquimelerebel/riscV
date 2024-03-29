/*===============================================================================================================================
   Design       : Single-clock Synchronous LIFO/Stack
   Description  : Fully synthesisable, configurable Single-clock Synchronous LIFO/Stack based on registers.
                  - Configurable Data width.
                  - Configurable Depth.
                  - Push and increment / decrement and pop -- pointer mode.
                  - All status signals have zero cycle latency.
                  
   Developer    : Mitu Raj, chip@chipmunklogic.com at Chipmunk Logic ™, https://chipmunklogic.com
   Date         : Oct-02-2021
===============================================================================================================================*/

module ras_shadow_stack #(
                    parameter DATA_W     = 4           ,        // Data width
                    parameter DEPTH      = 8           ,         // Depth of Stack 
                    parameter SP_WIDTH   = 32                    // Depth of Stack                             
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
                   output                  o_valid              // valid output 
                );


/*-------------------------------------------------------------------------------------------------------------------------------
   Internal Registers/Signals
-------------------------------------------------------------------------------------------------------------------------------*/
logic [DATA_W - 1 : 0]        stack [DEPTH]           ;
logic [SP_WIDTH-1 : 0]        stack_ptr_rg            ;
logic                         push, pop, full, empty, valid  ;


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
      if (push) begin
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
assign full    = (stack_ptr_rg >= DEPTH)               ;
assign empty   = (stack_ptr_rg == 0    )               ;
assign valid   = (stack_ptr_rg < DEPTH )               ;

assign push    = i_push & !full                        ;
assign pop     = i_pop  & !empty                       ;

assign o_full  = full                                  ;
assign o_empty = empty                                 ;  
assign o_valid = valid                                 ;

assign o_data  = (empty | !valid) ? '0 : stack [stack_ptr_rg - 1];   


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
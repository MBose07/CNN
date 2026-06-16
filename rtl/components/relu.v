module relu #(
    parameter W = 16 
) (
    input [W-1 : 0] din ,

    output [W-1 : 0] dout 
);

assign dout = (din [W-1]  == 0 ) ? din : 0 ;

endmodule
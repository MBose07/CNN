module shift_reg #(
    parameter N = 16 ,
    parameter D = 6
) (
    input [N -1 : 0] d_in ,
    input clk ,
    input ce ,
    input rst_n ,
    output [N-1 : 0] d_out
);

reg [ N-1 : 0] delay [0 : D-1 ] ;
reg [31: 0] i ; 
always @(posedge clk or negedge rst_n ) begin
    if(!rst_n) begin
        delay [0] <= 0 ;
        for (i = 0; i < D -1 ; i = i +1 ) begin
            delay[i + 1] <= 0 ;
        end
    end
    else if(ce) begin 
        delay [0] <= d_in ;
        for (i = 0; i < D -1 ; i = i +1 ) begin
            delay[i + 1] <= delay [i] ;
        end
    end
end
assign d_out = delay [D-1] ;
endmodule
module mac #(
    parameter W =  4   ,  //INTW format
    parameter Q = 4  ,
    parameter WA = 16
) (
    input load ,
    input ce ,
    input clk ,
    input rst_n ,

    input signed [W + Q -1:0] act_i ,
    input signed [W + Q -1:0] w_i ,
    input signed [WA + Q -1:0] partial_sum_i ,

    output reg signed[W + Q -1:0]  act_o ,
    output reg signed [W + Q -1:0] w_o ,
    output reg signed  [WA + Q -1:0] partial_sum_o
);
wire [2 * (WA + Q) -1:0] mul_temp = (act_i * w_i)   ;
always @(posedge clk or negedge rst_n ) begin
    if(!rst_n) begin
        partial_sum_o <= 0 ;
        act_o <= 0 ; 
        w_o <= 0 ; 
    end
    else if (load) begin
        act_o <= act_i ;
        w_o <= w_i ;
        partial_sum_o <= 0 ;
    end
    else if (ce) begin
        w_o <= w_i ;
        act_o <= act_i ;
        partial_sum_o <= partial_sum_i + (mul_temp >> Q ) ;
    end
end
endmodule
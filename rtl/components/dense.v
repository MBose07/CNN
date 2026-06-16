module dense #(
    parameter W = 16 ,
    parameter Q  = 12 ,
    parameter WA = 16 ,
    parameter N = 4 ,  // Number of pixels in the flattened feature map
    parameter M = 10   // Number of output classes (0-9)
) (
    input clk ,
    input rst_n ,
    input ce ,
    input valid_ip ,

    input signed [W+Q -1 : 0] data_in ,
    input signed [(W + Q)*M -1 : 0] w_in ,

    output signed [(WA + Q)*M -1 : 0 ] data_out
);

    genvar i ;
    generate
        for (i = 0; i < M ; i = i + 1 ) begin : DENSE
            mac # (
                .W(W),
                .Q(Q),
                .WA(WA) 
            ) m_den (
                .clk(clk) , 
                .rst_n(rst_n) ,
                .ce(ce && valid_ip) ,


                .load(1'b0) ,
                .act_i(data_in),

                .w_i(w_in[(W + Q)*(i+1) - 1 : (W + Q)*i]) ,

                .partial_sum_i(data_out[(WA + Q)*(i+1) - 1 : (WA + Q)*i]) ,
                .partial_sum_o(data_out[(WA + Q)*(i+1) - 1 : (WA + Q)*i]) ,

                .act_o(),
                .w_o()
            ) ;
        end
    endgenerate

endmodule
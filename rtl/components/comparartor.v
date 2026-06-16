module comparator #(
    parameter W = 16 
) (
    input signed [ W-1 : 0] d1 ,
    input signed [ W -1 : 0] d2 ,
    input signed [ W -1 : 0] d3 ,
    input signed [ W -1 : 0] d4 ,
    output signed [W -1 : 0] d_op
);
    wire signed [W-1 :0] temp1 ,temp2 ;
    assign temp1 = d1 >d2 ? d1 :d2 ;
    assign temp2 = d3 >d4 ? d3 :d4 ;
    assign d_op = temp1 > temp2 ? temp1 : temp2 ;
endmodule
module max_pool #(
    parameter M = 4 ,  // width of input feature map
    parameter P = 2 ,  // pooling window size
    parameter W  =  16 // total bit width
) (
    input clk ,
    input ce  ,
    input rst_n ,
    input signed [W -1 : 0] din ,

    output signed [W-1:0] data_out ,
    output valid_data ,
    output comp
);
    reg signed [W-1 : 0] del [ 0 : M + P -1];

    reg [15:0] col_cnt;
    reg [15:0] row_cnt;

    wire signed [W -1  : 0] d1 , d2 , d3 , d4 ;

    assign d1 = del [M + 1] ; // Top-Left
    assign d2 = del [M] ;     // Top-Right
    assign d3 = del [1] ;     // Bottom-Left
    assign d4 = del [0] ;     // Bottom-Right

    integer i ; 

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
            for (i = 0 ; i < M + P ; i = i + 1 ) begin
                del[i] <= 0;
            end
        end
        else if (ce) begin
            del [0] <= din ;
            for (i = 0 ; i < M + P - 1 ; i = i + 1 ) begin
                del [i+1] <= del [i];
            end

            if (col_cnt == M - 1) begin
                col_cnt <= 0;
                row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end

    // The Comparator Tree
    comparator #(
        .W(W)
    ) c (
        .d1(d1) ,
        .d2(d2) ,
        .d3(d3) ,
        .d4(d4) ,
        .d_op(data_out)
    );
    assign valid_data = ce && (col_cnt[0] == 1'b1) && (row_cnt[0] == 1'b1);
    assign comp = (col_cnt == M - 1) && (row_cnt == M - 1) && ce;

endmodule
module argmax #(
    parameter CLASSES = 10,
    parameter W_TOTAL = 28
) (
    input signed [(CLASSES * W_TOTAL) - 1 : 0] scores_in,

    output reg [$clog2(CLASSES) + 1 :0] predicted_class
);
    integer i;
    reg signed [W_TOTAL-1:0] current_max;
    reg signed [W_TOTAL-1:0] temp_score;

    always @(*) begin
        current_max = scores_in [W_TOTAL -1 : 0] ;
        predicted_class = 0 ;
        for (i = 1; i < CLASSES; i = i + 1) begin
            temp_score = scores_in[i * W_TOTAL +: W_TOTAL];
            if (temp_score > current_max) begin
                current_max = temp_score;
                predicted_class = i[3:0];
            end
        end
    end
endmodule
`timescale 1ns / 1ps

module cnn_accelerator_top #(
    parameter n = 10,         // Input image dimension (n x n)
    parameter k = 3,          // Kernel size
    parameter s = 1,          // Convolution stride
    parameter P = 2,          // Pooling window size
    parameter W = 16,         // Integer bit width
    parameter Q = 12,         // Fractional bit width
    parameter CLASSES = 10    // Number of output digits (0-9)
)(
    input clk,
    input ce,
    input load,               // Loads weights into the Conv MAC array
    input rst_n,

    // Streaming input pixel
    input signed [W + Q - 1 : 0] activation,

    // Massive parallel weight buses (Hardcoded or driven by BRAM/ROM)
    input signed [(k * k) * (W + Q) - 1 : 0] conv_weight,
    input signed [(W + Q) * CLASSES - 1 : 0] dense_weight,

    // Final Outputs
    output [$clog2(CLASSES) + 1 : 0] predicted_class,
    output valid_prediction
);

    localparam CONV_OUT_DIM = ((n - k) / s) + 1;

    localparam TOTAL_W = W + Q;

    wire signed [TOTAL_W - 1 : 0] conv_to_relu;
    wire valid_conv;
    wire end_conv;

    wire signed [TOTAL_W - 1 : 0] relu_to_pool;

    wire signed [TOTAL_W - 1 : 0] pool_to_dense;
    wire valid_pool;
    wire pool_comp; 

    wire signed [(TOTAL_W * CLASSES) - 1 : 0] dense_scores;

    // -------------------------------------------------------------------------
    // Stage 1: Convolution
    // -------------------------------------------------------------------------
    convolver #(
        .n(n),
        .k(k),
        .s(s),
        .N(W),
        .Q(Q)
    ) conv_inst (
        .clk(clk),
        .ce(ce),
        .load(load),
        .rst_n(rst_n),
        .activation(activation),
        .weight1(conv_weight),
        .conv_op(conv_to_relu),
        .valid_conv(valid_conv),
        .end_conv(end_conv)
    );

    // -------------------------------------------------------------------------
    // Stage 2: Activation (ReLU)
    // -------------------------------------------------------------------------
    // Purely combinational. Clips negative sums to zero instantly.
    relu #(
        .W(TOTAL_W)
    ) relu_inst (
        .din(conv_to_relu),
        .dout(relu_to_pool)
    );

    // -------------------------------------------------------------------------
    // Stage 3: Max Pooling
    // -------------------------------------------------------------------------
    max_pool #(
        .M(CONV_OUT_DIM), 
        .P(P),
        .W(TOTAL_W)
    ) pool_inst (
        .clk(clk),
        .ce(ce && valid_conv),
        .rst_n(rst_n),
        .din(relu_to_pool),
        .data_out(pool_to_dense),
        .valid_data(valid_pool),
        .comp(pool_comp)
    );

    // -------------------------------------------------------------------------
    // Stage 4: Dense (Fully Connected Matrix-Vector Multiplier)
    // -------------------------------------------------------------------------
    dense #(
        .W(W),
        .Q(Q),
        .WA(W),       // Wide accumulator parameter
        .M(CLASSES)
    ) dense_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .valid_ip(valid_pool),  
        .data_in(pool_to_dense),
        .w_in(dense_weight),
        .data_out(dense_scores)
    );

    // -------------------------------------------------------------------------
    // Stage 5: Argmax (Combinational Decider)
    // -------------------------------------------------------------------------
    argmax #(
        .CLASSES(CLASSES),
        .W_TOTAL(TOTAL_W)
    ) argmax_inst (
        .scores_in(dense_scores),
        .predicted_class(predicted_class)
    );

    // -------------------------------------------------------------------------
    // Final Control Logic
    // -------------------------------------------------------------------------
    // The Dense array finishes accumulating its final scores on the exact 
    // clock cycle that the Max Pooler hits its M*M limit and outputs 'comp'.
    assign valid_prediction = pool_comp;

endmodule
`timescale 1ns / 1ps

module cnn_mnist_tb;

    // --- MNIST Network Parameters ---
    parameter n = 28;         // 28x28 MNIST Image
    parameter k = 3;          // 3x3 Kernel
    parameter s = 1;          // Stride 1
    parameter P = 2;          // 2x2 Pooling
    parameter W = 16;         // Integer width
    parameter Q = 12;         // Fractional bits
    parameter CLASSES = 10;   // Digits 0-9
    
    parameter TOTAL_W = W + Q;
    parameter CLK_PERIOD = 10;
    
    // Post-pool dimension is 13x13 = 169 flattened features
    parameter FLATTENED_FEATURES = 169;

    // --- Testbench Signals ---
    reg clk;
    reg ce;
    reg load;
    reg rst_n;
    
    reg signed [TOTAL_W - 1 : 0] activation;
    reg signed [(k * k) * TOTAL_W - 1 : 0] conv_weight;
    reg signed [TOTAL_W * CLASSES - 1 : 0] dense_weight;
    
    wire [$clog2(CLASSES) + 1 : 0] predicted_class;
    wire valid_prediction;

    // --- Hex File Memory Arrays ---
    reg [TOTAL_W - 1 : 0] conv_mem  [0 : 8];
    reg [TOTAL_W - 1 : 0] dense_mem [0 : (CLASSES * FLATTENED_FEATURES) - 1]; // 1690 values
    reg [TOTAL_W - 1 : 0] image_mem [0 : (n * n) - 1];                        // 784 pixels

    integer i, j;
    integer p_idx; // Tracks which pooled pixel we are currently processing

    // --- Instantiate the Top Level SOC ---
    cnn_accelerator_top #(
        .n(n), .k(k), .s(s), .P(P), .W(W), .Q(Q), .CLASSES(CLASSES)
    ) uut (
        .clk(clk),
        .ce(ce),
        .load(load),
        .rst_n(rst_n),
        .activation(activation),
        .conv_weight(conv_weight),
        .dense_weight(dense_weight),
        .predicted_class(predicted_class),
        .valid_prediction(valid_prediction)
    );

    // --- Clock Generation ---
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Dynamic Memory Controller for Dense Layer ---
    // This feeds 10 new weights to the MAC array every time a valid pooled pixel arrives.
    always @(posedge clk) begin
        // Monitor the internal handshake wire between the Pooler and the Dense layer
        if (uut.valid_pool && p_idx < FLATTENED_FEATURES) begin
            p_idx = p_idx + 1;
            
            // Fetch the 10 weights for the next pixel
            if (p_idx < FLATTENED_FEATURES) begin
                for (j = 0; j < CLASSES; j = j + 1) begin
                    // 2D addressing to match PyTorch's [10, 169] flattened tensor
                    dense_weight[j*TOTAL_W +: TOTAL_W] = dense_mem[j * FLATTENED_FEATURES + p_idx];
                end
            end
        end
    end

    // --- Main Stimulus Block ---
    initial begin
        $dumpfile("mnist_hardware_waves.vcd");
        $dumpvars(0, cnn_mnist_tb);

        // 1. Load Data from Python Hex Files
        $readmemh("data/conv_weights.hex", conv_mem);
        $readmemh("data/dense_weights.hex", dense_mem);
        $readmemh("data/image.hex", image_mem);

        clk = 0;
        ce = 0;
        load = 0;
        rst_n = 1;
        activation = 0;
        p_idx = 0;
        
        // 2. Pack Convolution Weights (Static)
        for (i = 0; i < 9; i = i + 1) begin
            conv_weight[i*TOTAL_W +: TOTAL_W] = conv_mem[i];
        end
        
        // 3. Pre-load the first column of Dense Weights for Pixel 0
        for (j = 0; j < CLASSES; j = j + 1) begin
            dense_weight[j*TOTAL_W +: TOTAL_W] = dense_mem[j * FLATTENED_FEATURES + 0];
        end

        // 4. Hardware Reset Sequence
        #(CLK_PERIOD * 2);
        rst_n = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);

        // 5. Latch weights into Convolver
        load = 1;
        #(CLK_PERIOD);
        load = 0;

        // 6. Stream the 28x28 Image
        ce = 1;
        $display("--------------------------------------------------");
        $display("  Streaming 28x28 MNIST Image from Memory...");
        $display("--------------------------------------------------");
        
        for(i = 0; i < (n * n); i = i + 1) begin
            activation = image_mem[i];
            #(CLK_PERIOD);
        end
        
        // Flush pipeline (Feed 0s to push the last spatial windows through)
        activation = 0;
        
        // 7. Wait for Prediction
        $display("  Processing layers (Spatial Shift -> Pool -> Dense MVM)...");
        wait(valid_prediction == 1'b1);
        
        #(CLK_PERIOD * 2); 
        
        // 8. Verdict
        $display("==================================================");
        $display("  HARDWARE INFERENCE COMPLETE");
        $display("  Silicon Predicted Class: %0d", predicted_class);
        $display("==================================================");
        
        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
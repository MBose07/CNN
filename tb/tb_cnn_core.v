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
    reg [TOTAL_W - 1 : 0] dense_mem [0 : (CLASSES * FLATTENED_FEATURES) - 1]; 
    
    reg [TOTAL_W - 1 : 0] image_mem [0 : 78399];                              
    // Ground truth labels for accuracy checking
    reg [3:0]             label_mem [0 : 99];                                 

    integer i, j, img_num;
    integer p_idx; 
    integer correct_count = 0;
    reg [3:0] expected_label;

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

    always @(posedge clk) begin
        if (uut.valid_pool && p_idx < FLATTENED_FEATURES) begin
            p_idx = p_idx + 1;
            if (p_idx < FLATTENED_FEATURES) begin
                for (j = 0; j < CLASSES; j = j + 1) begin
                    dense_weight[j*TOTAL_W +: TOTAL_W] = dense_mem[j * FLATTENED_FEATURES + p_idx];
                end
            end
        end
    end

    initial begin
        // $dumpfile("mnist_hardware_waves.vcd");
        // $dumpvars(0, cnn_mnist_tb);

        // 1. Load Data from Python Hex Files
        $readmemh("data/conv_weights.hex", conv_mem);
        $readmemh("data/dense_weights.hex", dense_mem);
        $readmemh("data/test_images.hex", image_mem);
        $readmemh("data/test_labels.hex", label_mem);

        clk = 0; ce = 0; load = 0; rst_n = 1; activation = 0;
        
        // 2. Pack Convolution Weights (Static across all images)
        for (i = 0; i < 9; i = i + 1) begin
            conv_weight[i*TOTAL_W +: TOTAL_W] = conv_mem[i];
        end

        $display("==================================================");
        $display(" 🚀 STARTING 100-IMAGE BATCH INFERENCE...");
        $display("==================================================");

        // 3. Loop Through All 100 Images
        for (img_num = 0; img_num < 100; img_num = img_num + 1) begin
            
            p_idx = 0;
            
            // A. Pre-load the first column of Dense Weights for Pixel 0
            for (j = 0; j < CLASSES; j = j + 1) begin
                dense_weight[j*TOTAL_W +: TOTAL_W] = dense_mem[j * FLATTENED_FEATURES + 0];
            end

            // B. Hardware Reset Sequence (clears internal accumulators/counters)
            ce = 0;
            rst_n = 0;
            #(CLK_PERIOD * 2);
            rst_n = 1;
            #(CLK_PERIOD * 2);

            // C. Latch weights into Convolver
            load = 1;
            #(CLK_PERIOD);
            load = 0;

            // E. Stream the 28x28 Image
            ce = 1;
            for(i = 0; i < (n * n); i = i + 1) begin
                // Calculate absolute address in the flattened 78,400 array
                activation = image_mem[(img_num * n * n) + i];
                #(CLK_PERIOD);
            end
            
            // Flush pipeline
            activation = 0;
            
            // F. Wait for Prediction
            wait(valid_prediction == 1'b1);
            #(CLK_PERIOD * 2); 
            
            // G. Capture and Compare Prediction
            expected_label = label_mem[img_num];
            
            if (predicted_class === expected_label) begin
                correct_count = correct_count + 1;
                $display("[PASS] Image %02d | Pred: %0d | Actual: %0d", img_num, predicted_class, expected_label);
            end else begin
                $display("[FAIL] Image %02d | Pred: %0d | Actual: %0d", img_num, predicted_class, expected_label);
            end

            // Let the hardware rest before the next digit
            ce = 0;
            #(CLK_PERIOD * 20);
        end

        $display("==================================================");
        $display("  FINAL BATCH INFERENCE ACCURACY: %0d / 100", correct_count);
        $display("==================================================");
        
        $finish;
    end

endmodule
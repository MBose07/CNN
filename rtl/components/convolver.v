module convolver #(
    parameter n = 10,         // n * n input map
    parameter k = 3,          // kernel size
    parameter s = 1,          // value of stride
    parameter N = 16,         // total bit width
    parameter Q = 12          // number of fractional bits
)(
    input clk,
    input ce,
    input load,
    input rst_n,
    input signed [N + Q -1:0] activation,
    input signed [(k*k)*(N+Q)-1:0] weight1,
    output signed [N + Q -1:0] conv_op,
    output valid_conv,
    output end_conv
);

  // We need k*k MAC connections PLUS (k-1) shift register connections.
  // Total size = k*k + k - 1. So the array goes from 0 to k*k + k - 1.
  reg [31:0] count,count2,count3,row_count;
  reg en1,en2,en3;
  wire signed [ N + Q -1 : 0] bus_in [0 : (k*k) + k - 1]; 

  assign bus_in[0] = 0;
  // The final output is at the very end of the expanded chain
  assign conv_op = bus_in[(k*k) + k - 1]; 

  genvar i, j;

  // 1. Generate the Delay Lines (Shift Registers)
  // We only need k-1 delay lines (e.g., between row 0->1, and 1->2)
  generate
      for(i = 0; i < k - 1; i = i + 1) begin: del
          // Note: added instance name 'sr_inst' which is required in Verilog
          shift_reg #(
              .N(N + Q ) ,
              .D(n-k)
          ) sr_inst( 
              // Input comes from the end of a row
              .d_in (bus_in[ i * (k + 1) + k ]), 
              .clk(clk),
              .ce(ce),
              .rst_n(rst_n),
              // Output goes to the start of the next row
              .d_out(bus_in[ i * (k + 1) + k + 1 ]) 
          );
      end
  endgenerate

  // 2. Generate the MAC Units
  generate
      for (i = 0; i < k; i = i + 1) begin :ROW
          for (j = 0; j < k ; j = j + 1) begin :COL
              mac #(
                  .W(N),       // Set MAC data width to 16
                  .WA(N) ,       // Set Accumulator width to 16 to match bus_in
                  .Q(Q)
              )m(
                  .clk(clk),
                  .ce(ce),
                  .load(load),
                  .rst_n(rst_n),
                  .act_i(activation),
                  .w_i(weight1 [((k * i) + j) * (N+Q) + (N+Q-1) : ((k * i) + j) * (N+Q)]),
                  // Indexing logic: i * (k + 1) accounts for the extra shift reg wire
                  .partial_sum_i(bus_in[ i * (k + 1) + j ]),
                  .act_o(),
                  .w_o(),
                  .partial_sum_o(bus_in[ i * (k + 1) + j + 1 ])
              );
          end
      end
  endgenerate

  always@(posedge clk) 
  begin
    if(!rst_n)
    begin
      count <=0;                      //master counter: counts the clock cycles
      count2<=0;                      //counts the valid convolution outputs
      count3<=0;                      // counts the number of invalid onvolutions where the kernel wraps around the next row of inputs.
      row_count <= 0;                 //counts the number of rows of the output. 
      en1<=0;
      en2<=1;
      en3<=0;
    end
    else if(ce)
    begin
      if(count == (k-1)*n+k-1)        // time taken for the pipeline to fill up is (k-1)*n+k-1
      begin
        en1 <= 1'b1;
        count <= count+1'b1;
      end
      else
      begin
        count<= count+1'b1;
      end
    end
    if(en1 && en2)
    begin
      if(count2 == n-k)
      begin
        count2 <= 0;
        en2 <= 0 ;
        row_count <= row_count + 1'b1;
      end
      else
      begin
        count2 <= count2 + 1'b1;
      end
    end

    if(~en2) 
    begin
    if(count3 == k-2)
    begin
      count3<=0;
      en2 <= 1'b1;
    end
    else
      count3 <= count3 + 1'b1;
    end
    //one in every 's' convolutions becomes valid, also some exceptional cases handled for high when count2 = 0
    if((((count2 + 1) % s == 0) && (row_count % s == 0))||
      (count3 == k-2)&&(row_count % s == 0)||(count == (k-1)*n+k-1))
    begin
      en3 <= 1;
    end
    else 
      en3 <= 0;
  end
      assign end_conv = (count>= n*n+2) ? 1'b1 : 1'b0;
      assign valid_conv = (en1&&en2&&en3 && (~ end_conv));
endmodule
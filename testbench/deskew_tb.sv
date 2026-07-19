///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                                       //
//  File Name     : deskew_tb.v                                                                                                          //
//  Port Details  : Inputs  - i_clk , i_s1 , i_s2                                                                                        //
//                  Outputs - o_stream , o_aligned                                                                                       //
//  Description   : Testbench for Deskew logic and stream conctenation assignment                                                        //
//                                                                                                                                       //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module deskew_tb;

  reg i_clk;
  reg i_reset;
  reg [3:0] i_s1, i_s2;
  wire [7:0] o_stream;
  wire o_aligned;
  int seed;
  string test;

  // Design module instantiation
  deskew deskew_tb (
      i_clk,
	  i_reset,
      i_s1,
      i_s2,
      o_stream,
      o_aligned
  );

  // Testing reset
  task reset;
	  @(posedge i_clk) i_reset = 1;
	  repeat (150) @(posedge i_clk) i_reset = 0;
	  repeat (5) @(posedge i_clk) i_reset =1;
	  repeat (5) @(posedge i_clk) i_reset = 0;
  endtask:reset

  //default testcase
  task default_test;
	  @(posedge i_clk) i_reset = 1;
	  repeat (2) @(posedge i_clk) i_reset = 0;
  endtask:default_test

  initial begin
    i_clk = 0;  //Initialize clock
	i_reset =0; //Initialize Reset

	//Reading test and seed values
	//if (!$value$plusargs("SEED=%d", seed))
	//	seed=1;
	//void'($urandom(seed));
	if (!$value$plusargs("TEST=%s", test))
		test = "default_test";

    $display("Running %s test with seed value: %d", test, $get_initial_random_seed());
	$monitor ("reset= %b, input stream_1 = %h , input stream_2= %h , output stream = %h , o_aligned = %b ",i_reset, i_s1,i_s2,o_stream, o_aligned);

    // Run the testcases
	case(test)
		"reset":reset();
		default:default_test();
	endcase
   end

   //input generation
   always @(posedge i_clk) begin

	i_s1<=$urandom_range(0,15);
	i_s2<=$urandom_range(0,15);
   end

   // clock generation
   always #1 i_clk = ~i_clk;
   initial #500 $finish;
endmodule


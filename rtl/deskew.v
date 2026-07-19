///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                                       //
//  File Name     : deskew.v                                                                                                             //
//  Port Details  : Inputs  - i_clk , i_s1 , i_s2                                                                                        //
//                  Outputs - o_stream , o_aligned                                                                                       //
//  Description   : This design implements the De-skew logic and stream concatenation.The fsm has 5 states. The initial state is s0.     //
//                  If the first occurance of a is in stream 1 the state changes to s1 , if it is stream2 state changes to s3 , if       //
//                  both stream1 and stream2 gets a at the same time it remains in same state and starts concatenation.Otherwise the     //
//                  state remains s0 and searching continues.In s1 if the stream2 has a ,state remains in s1 and starts concatenation,   //
//                  else state transitions to s2. In s2 if stream2 has a , state remians in s2 and starts concatenation ,else state      //
//                  transitions to s0 and restarts the process.The similar process as s1 and s2 happens in  s3 and s4.                   //
//                  O_aligned is asserted as concatenation starts.                                                                       //
//                                                                                                                                       //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


module deskew (
    input i_clk,
	input i_reset,
    input [3:0] i_s1,
    input [3:0] i_s2,
    output reg [7:0] o_stream,
    output reg o_aligned
);

  reg [2:0] state, next_state;
  reg sk1, sk2; // clock skew
  reg [3:0] q1, q2, next_q1, next_q2;  // store i/p stream values
  parameter s0 = 0, s1 = 1, s2 = 2, s3 = 3, s4 = 4;  //states

  always @(posedge i_clk) begin
	  if (i_reset) begin
		  q1<=0;
		  q2<=0;
		  state<=0;
		  sk1<=1'bx;
		  sk2<=1'bx;
	  end
	  else begin
          state <= next_state;
          q1 <= next_q1;
          q2 <= next_q2;
	  end
  end


  always @(*) begin
	if (i_reset) begin
      next_state=0;
	  o_aligned=0;
	  o_stream =0;
	  next_q1 =0;
	  next_q2= 0;
	end
	else begin
	case (state)

      /*-----------------------Searching input streams------------------------*/
      s0: begin
	    if (o_aligned) begin
	      next_state = s0;
		  o_stream = {i_s2, i_s1};
	    end
		else begin
          if (i_s1 == 4'ha) begin
            if (i_s2 == 4'ha) begin                // a in both streams at the same time
              {sk1, sk2} = 2'h0;
              o_stream   = {i_s2, i_s1};
              next_state = s0;
              o_aligned  = 1'b1;
            end else begin                         // first a occurance in Stream1
              next_state = s2;
              next_q1 = i_s1;
            end
          end else if (i_s2 == 4'ha) begin        // first a occurance in Stream2
            next_state = s3;
            next_q1 = i_s2;
          end else if ({sk1, sk2} == 2'h0) o_stream = {i_s2, i_s1}; //Stream Concatenation
          else next_state = s0;                  // a not found
	    end
      end

      /*-------------------------Stream1 leads--------------------------------*/
      s1: begin
        if (i_s2 == 4'ha || sk1 == 1) begin    // a occurs in stream2 after 1 clock skew
          sk1 = 1;
          o_stream = {i_s2, q1};               //stream concatenation
          o_aligned = 1'b1;
          next_q1 = i_s1;
          next_state = s1;                    //state remains same and concatenation continues
        end else begin                        // a not found
          next_state = s2;
          next_q2 = i_s1;
        end
      end
      /*--------------Stream1 leads by 2 clock cycles -----------------------*/
      s2: begin
        if (i_s2 == 4'ha || sk2 == 1) begin   // a occurs in stream2 after 2 clock skew
          sk2 = 1;
          o_stream = {i_s2, q1};              // stream concatenation
          o_aligned = 1'b1;
          next_q1 = q2;
          next_q2 = i_s1;
          next_state = s2;                   //state remains same and concatenation continues
        end else begin                       // a not found , state reset to s0
          next_state = s0;
        end
      end

      /*--------------------------Stream2 leads-----------------------------*/
      s3: begin
        if (i_s1 == 4'ha || sk1 == 1) begin  // a occurs in stream1 after 1 clock skew
          sk1 = 1;
          o_stream = {i_s1, q1};             // stream concatenation
          o_aligned = 1'b1;
          next_q1 = i_s2;
          next_state = s3;                  // state remains same and concatenation continues
        end else begin                      // a not found
          next_state = s4;
          next_q2 = i_s2;
        end
      end

      /*--------------Stream2 leads by 2 clock cycles-----------------------*/
      s4: begin
        if (i_s1 == 4'ha || sk2 == 1) begin  // a occurs in stream1 after 2 clock skew
          sk2 = 1;
          o_stream = {i_s1, q1};             // stream concatenation
          o_aligned = 1'b1;
          next_q1 = q2;
          next_q2 = i_s2;
          next_state = s4;                  // state remains same and concatenation continues
        end else begin                      // a not found , state reset to s0
          next_state = s0;
        end
      end

      default: next_state = s0;
    endcase
  end
  end

endmodule








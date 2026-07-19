`timescale 1ns/1ns

class transaction;
  randc bit [3:0] i_s1;
  randc bit [3:0] i_s2;
  bit [7:0] o_stream;
  bit o_aligned;

  constraint data {
    i_s1 dist {
      10 := 30,
      [0 : 9] := 5,
      [11 : 15] := 5
    };
    i_s2 dist {
      10 := 30,
      [0 : 9] := 5,
      [11 : 15] := 5
    };
  }

  function transaction copy();
    copy = new();
    copy.i_s1 = this.i_s1;
    copy.i_s2 = this.i_s2;
    copy.o_stream = this.o_stream;
    copy.o_aligned = this.o_aligned;
  endfunction

  function void display(string name);
    $display("%s -- s1 :%0d , s2:%0d , o_stream:%0h ,o_aligned:%0d", name, i_s1, i_s2, o_stream,
             o_aligned);
  endfunction
endclass

class transaction_op;
  bit [7:0] o_stream;
  bit o_aligned;
  function void display(string name);
    $display("%s --  o_stream:%0h ,o_aligned:%0d", name, o_stream, o_aligned);
  endfunction

  function compare (transaction_op t_act);
    if ((this.o_aligned == t_act.o_aligned) && (this.o_stream == t_act.o_stream))
		return 1;
	else return 0;
  endfunction

endclass


class generator;
  transaction tg;
  transaction tref;
  mailbox #(transaction) gen2drv;
  event next_input;

  function new(mailbox#(transaction) gen2drv);
    this.gen2drv = gen2drv;
    tg = new();
  endfunction

  task run();
    forever begin
	  $display("---------------------------");
      assert (tg.randomize())
      else $display("Randomization failed");
      gen2drv.put(tg.copy);
      $display("[GEN] Sending data to driver ");
      tg.display("[GEN]");
      @(next_input);
    end
  endtask

endclass

class driver;
  transaction td;
  transaction tref;
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) drv2ref;
  event next_input;
  event next_expected;

  virtual intf intf_ds;

  function new(mailbox#(transaction) gen2drv, mailbox#(transaction) drv2ref);
    this.gen2drv = gen2drv;
    this.drv2ref = drv2ref;
  endfunction

  task run();
    td = new();
    forever begin
      gen2drv.get(td);
      tref = td.copy;
	  $display("---------------------------");
      $display("[DRV] RCVD data from driver ");
      td.display("[DRV]");
      @(posedge intf_ds.i_clk);
      intf_ds.i_s1 <= td.i_s1;
      intf_ds.i_s2 <= td.i_s2;
	  drv2ref.put(tref);
      $display("[DRV] : Interface Triggered ");
      $display("[INTF] s1 :%0d , s2:%0d , o_stream:%0d ,o_aligned:%0d)", intf_ds.i_s1,
               intf_ds.i_s2, intf_ds.o_stream, intf_ds.o_aligned);
      ->next_input; ->next_expected;
    end

  endtask

endclass

interface intf;
  logic i_clk;
  logic i_reset;
  logic [3:0] i_s1;
  logic [3:0] i_s2;
  logic [7:0] o_stream;
  logic o_aligned;
endinterface

class monitor;
  transaction_op tm;
  mailbox #(transaction_op) mon2scb;
  virtual intf intf_ds;
  event done;

  function new(mailbox#(transaction_op) mon2scb);
    this.mon2scb = mon2scb;
  endfunction

  task run;
    forever begin
	  tm = new();
      @(negedge intf_ds.i_clk);
	  $display("---------------------------");
	  $display("[MON]:RCVD data at monitor");
      $display("[INTF] s1 :%0d , s2:%0d , o_stream:%0d ,o_aligned:%0d)", intf_ds.i_s1,
               intf_ds.i_s2, intf_ds.o_stream, intf_ds.o_aligned);
      tm.o_stream = intf_ds.o_stream;
      tm.o_aligned = intf_ds.o_aligned;
      mon2scb.put(tm);
      $display("[MON] : Sending data to scoreboard ");
      tm.display("[MON]");
      -> done;
    end
  endtask

endclass


class reference;
  transaction tref_ip;
  transaction_op tref_op;
  event next_expected;

  mailbox #(transaction) drv2ref;
  mailbox #(transaction_op) ref2scb;
  bit [7:0] ex_op;
  bit o_aligned;
  bit [3:0] s1[$];
  bit [3:0] s2[$];
  bit stream1, stream2;
  int skew=0;


  function new(mailbox#(transaction) drv2ref, mailbox#(transaction_op) ref2scb);
    this.drv2ref = drv2ref;
    this.ref2scb = ref2scb;
  endfunction

  task calculate();
    s1.push_front(tref_ip.i_s1);
    s2.push_front(tref_ip.i_s2);
    if (!o_aligned) begin
      if (s1[$] == 4'ha && skew < 3) begin
        if (s2[0] == 4'ha) begin
          o_aligned = 1;
          stream1   = 1;
        end else begin
          if (s2.size() != 0) s2.pop_back();
          skew++;
        end
      end else if (s2[$] == 4'ha && skew < 3) begin
        if (s1[0] == 4'ha) begin
          o_aligned = 1;
          stream2   = 1;
        end else begin
          if (s1.size() != 0) s1.pop_back();
          skew++;
        end
      end else if (skew == 0) begin
        if (s1.size() != 0) s1.pop_back();
	    if (s2.size() != 0) s2.pop_back();
	  end
    end
    if (skew == 3) begin
      if (s1.size() != 0) s1.delete();
      if (s2.size() != 0) s2.delete();
      skew = 0;
      stream1 = 0;
      stream2 = 0;
    end

    if (o_aligned) begin
      if (stream1 && s1.size()) ex_op = {s2.pop_back(), s1.pop_back()};
      else if (stream2 && s2.size()) ex_op = {s1.pop_back(), s2.pop_back()};
    end

    $display("Queue s1:%0p", s1);
    $display("QUeue s2 :%0p", s2);
    $display("ex_op:%h  %0tns", ex_op, $time);
  endtask

  task run();
    forever begin
	  tref_ip = new();
      drv2ref.get(tref_ip);
	  $display("[REF]: Calculating expected output");
      calculate();
	  tref_op = new();
      tref_op.o_stream  = ex_op;
      tref_op.o_aligned = o_aligned;
      ref2scb.put(tref_op);
	  tref_op.display("[REF]");
      $display("[reference model]: expected output: %h , %0tns", ex_op, $time);
      @(next_expected);
    end
  endtask

endclass


class scoreboard;
  transaction_op ts;
  transaction_op tref_op;
  mailbox #(transaction_op) mon2scb;
  mailbox #(transaction_op) ref2scb;
  event done;

  function new(mailbox#(transaction) mon2scb, mailbox#(transaction_op) ref2scb);
    this.mon2scb = mon2scb;
    this.ref2scb = ref2scb;
  endfunction

  task compare();
    if (tref_op.o_aligned) begin
	  $display("[SCB]:Expected output stream = %0h, actual output stream = %0h", tref_op.o_stream ,ts.o_stream);
      if (tref_op.compare(ts)) $display("----------Test passed at %0tns--------", $time);
      else $display("-------------Test failed at %0tns----------------", $time);
    end
  endtask


  task run();
    forever begin
	  @(done);
	  ts = new();
      tref_op = new();
      mon2scb.get(ts);
      ref2scb.get(tref_op);
	  $display("---------------------------");
	  $display("[SCB]:RCVD data at scoreboard");
	  ts.display("[SCB]");
      compare();
	  tref_op.display("[SCB]:expected-");
      ts.display("[SCB]");
	  $display("======================================================");
    end
  endtask

endclass

class environment;
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) drv2ref;
  mailbox #(transaction_op) mon2scb;
  mailbox #(transaction_op) ref2scb;
  virtual intf intf_ds;
  event next_input;
  event next_expected;
  event done;
  generator gen;
  driver drv;
  monitor mon;
  reference refr;
  scoreboard scb;

  function new(mailbox#(transaction) gen2drv, mailbox#(transaction_op) mon2scb);
    this.gen2drv = gen2drv;
    this.mon2scb = mon2scb;
    drv2ref = new();
    ref2scb = new();

    gen = new(this.gen2drv);
    drv = new(this.gen2drv, drv2ref);
    refr = new(drv2ref, ref2scb);
    mon = new(this.mon2scb);
    scb = new(this.mon2scb, ref2scb);
  endfunction

  task run();
    gen.next_input = next_input;
    drv.next_input = next_input;
    drv.next_expected = next_expected;
    refr.next_expected = next_expected;
	mon.done= done;
	scb.done= done;
    drv.intf_ds = intf_ds;
    mon.intf_ds = intf_ds;
    fork
      gen.run();
      drv.run();
      refr.run();
      mon.run();
      scb.run();
    join
  endtask

endclass

module deskew_tb;
  environment env;
  intf intf_ds ();
  mailbox #(transaction) gen2drv;
  mailbox #(transaction_op) mon2scb;

  deskew deskew_tb (
      .i_clk(intf_ds.i_clk),
      .i_reset(intf_ds.i_reset),
      .i_s1(intf_ds.i_s1),
      .i_s2(intf_ds.i_s2),
      .o_stream(intf_ds.o_stream),
      .o_aligned(intf_ds.o_aligned)
  );

  initial begin
    gen2drv = new();
    mon2scb = new();
    env = new(gen2drv, mon2scb);
    env.intf_ds = intf_ds;
  end

  initial begin
    intf_ds.i_clk   = 0;
    intf_ds.i_reset = 0;
   /* repeat (3) @(posedge intf_ds.i_clk);
    intf_ds.i_reset = 1;
    @(posedge intf_ds.i_clk);
    intf_ds.i_reset = 0;
    repeat (50) @(posedge intf_ds.i_clk);
    intf_ds.i_reset = 1;
    repeat (3) @(posedge intf_ds.i_clk);
    intf_ds.i_reset = 0;
    repeat (100) @(posedge intf_ds.i_clk);
    intf_ds.i_reset = 1;
    */
  end

  always #2 intf_ds.i_clk <= ~intf_ds.i_clk;

  initial begin
    fork
      env.run();
    join
  end

  initial begin
    #300 $finish;
  end

endmodule


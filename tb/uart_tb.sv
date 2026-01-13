class transaction;

  typedef enum bit {WRITE = 1'b0, READ = 1'b1} oper_t;
  randc oper_t oper;

  rand bit [7:0] dintx;
  bit  [7:0] doutrx;

  bit newd;
  bit tx;
  bit rx;

  bit donetx;
  bit donerx;

  function transaction copy();
    copy = new();
    copy.oper   = this.oper;
    copy.dintx  = this.dintx;
    copy.doutrx = this.doutrx;
    copy.newd   = this.newd;
    copy.tx     = this.tx;
    copy.rx     = this.rx;
    copy.donetx = this.donetx;
    copy.donerx = this.donerx;
  endfunction

endclass


class generator;

  transaction tr;
  mailbox #(transaction) mbx;
  event drvnext;
  event sconext;
  event done;
  int count = 0;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction

  task run();
    repeat (count) begin
      assert(tr.randomize);
      mbx.put(tr.copy());
      @(drvnext);
      @(sconext);
    end
    -> done;
  endtask

endclass


class driver;

  virtual uart_if vif;
  transaction tr;

  mailbox #(transaction) mbx;
  mailbox #(bit [7:0]) mbxds;
  event drvnext;

  bit [7:0] datarx;

  function new(mailbox #(bit [7:0]) mbxds,
               mailbox #(transaction) mbx);
    this.mbx   = mbx;
    this.mbxds = mbxds;
  endfunction

  task reset();
    vif.rst   <= 1'b1;
    vif.newd  <= 1'b0;
    vif.rx    <= 1'b1;
    vif.dintx <= 8'd0;
    repeat (5) @(posedge vif.uclktx);
    vif.rst <= 1'b0;
  endtask

  task run();
    forever begin
      mbx.get(tr);

      if (tr.oper == transaction::WRITE) begin
        @(posedge vif.uclktx);
        vif.newd  <= 1'b1;
        vif.dintx <= tr.dintx;
        @(posedge vif.uclktx);
        vif.newd <= 1'b0;
        mbxds.put(tr.dintx);
        wait (vif.donetx);
        -> drvnext;
      end

      else begin
        @(posedge vif.uclkrx);
        vif.rx <= 1'b0;
        for (int i = 0; i < 8; i++) begin
          @(posedge vif.uclkrx);
          vif.rx <= $urandom;
          datarx[i] = vif.rx;
        end
        vif.rx <= 1'b1;
        mbxds.put(datarx);
        wait (vif.donerx);
        -> drvnext;
      end

    end
  endtask

endclass


class monitor;

  virtual uart_if vif;
  mailbox #(bit [7:0]) mbx;
  bit [7:0] data;

  function new(mailbox #(bit [7:0]) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    forever begin
      @(posedge vif.uclktx);
      if (vif.newd) begin
        for (int i = 0; i < 8; i++) begin
          @(posedge vif.uclktx);
          data[i] = vif.tx;
        end
        mbx.put(data);
      end

      if (vif.donerx) begin
        data = vif.doutrx;
        mbx.put(data);
      end
    end
  endtask

endclass


class scoreboard;

  mailbox #(bit [7:0]) mbxds, mbxms;
  bit [7:0] ds, ms;
  event sconext;

  function new(mailbox #(bit [7:0]) mbxds,
               mailbox #(bit [7:0]) mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction

  task run();
    forever begin
      mbxds.get(ds);
      mbxms.get(ms);
      if (ds !== ms)
        $display("[SCO] MISMATCH : drv=%0d mon=%0d", ds, ms);
      else
        $display("[SCO] MATCH : %0d", ds);
      -> sconext;
    end
  endtask

endclass


class environment;

  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard sco;

  mailbox #(transaction) mbxgd;
  mailbox #(bit [7:0])   mbxds;
  mailbox #(bit [7:0])   mbxms;

  event drvnext;
  event sconext;

  virtual uart_if vif;

  function new(virtual uart_if vif);
    this.vif = vif;
    mbxgd = new();
    mbxds = new();
    mbxms = new();

    gen = new(mbxgd);
    drv = new(mbxds, mbxgd);
    mon = new(mbxms);
    sco = new(mbxds, mbxms);

    drv.vif = vif;
    mon.vif = vif;

    gen.drvnext = drvnext;
    drv.drvnext = drvnext;
    gen.sconext = sconext;
    sco.sconext = sconext;
  endfunction

  task run();
    drv.reset();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
    wait (gen.done.triggered);
    $finish;
  endtask

endclass


module tb;

  uart_if vif();

  uart_top #(1000000, 9600) dut (
    .clk     (vif.clk),
    .rst     (vif.rst),
    .rx      (vif.rx),
    .dintx   (vif.dintx),
    .newd    (vif.newd),
    .tx      (vif.tx),
    .doutrx  (vif.doutrx),
    .donetx  (vif.donetx),
    .donerx  (vif.donerx)
  );

  always #10 vif.clk = ~vif.clk;

  initial begin
    vif.clk = 0;
    vif.rx  = 1;
  end

  environment env;

  initial begin
    env = new(vif);
    env.gen.count = 5;
    env.run();
  end

  assign vif.uclktx = dut.utx.uclk;
  assign vif.uclkrx = dut.urx.uclk;

endmodule

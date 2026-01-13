`timescale 1ns / 1ps

module uart_top #(
  parameter clk_freq  = 1000000,
  parameter baud_rate = 9600
)(
  input  clk,
  input  rst,
  input  rx,
  input  [7:0] dintx,
  input  newd,
  output tx,
  output [7:0] doutrx,
  output donetx,
  output donerx
);

  uarttx #(clk_freq, baud_rate) utx (
    .clk (clk),
    .rst (rst),
    .newd (newd),
    .tx_data (dintx),
    .tx (tx),
    .donetx (donetx)
  );

  uartrx #(clk_freq, baud_rate) urx (
    .clk (clk),
    .rst (rst),
    .rx (rx),
    .done (donerx),
    .rxdata (doutrx)
  );

endmodule


module uarttx #(
  parameter clk_freq  = 1000000,
  parameter baud_rate = 9600
)(
  input clk,
  input rst,
  input newd,
  input [7:0] tx_data,
  output reg tx,
  output reg donetx
);

  localparam clkcount = clk_freq / baud_rate;

  integer count = 0;
  integer counts = 0;
  reg uclk = 0;
  reg [7:0] din;

  enum bit [1:0] {IDLE, START, TRANSFER, DONE} state;

  always @(posedge clk) begin
    if (count < clkcount/2)
      count <= count + 1;
    else begin
      count <= 0;
      uclk <= ~uclk;
    end
  end

  always @(posedge uclk) begin
    if (rst) begin
      state <= IDLE;
      tx <= 1'b1;
      donetx <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          counts <= 0;
          tx <= 1'b1;
          donetx <= 1'b0;
          if (newd) begin
            din <= tx_data;
            tx <= 1'b0;
            state <= TRANSFER;
          end
        end

        TRANSFER: begin
          if (counts <= 7) begin
            tx <= din[counts];
            counts <= counts + 1;
          end else begin
            tx <= 1'b1;
            donetx <= 1'b1;
            counts <= 0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule


module uartrx #(
  parameter clk_freq  = 1000000,
  parameter baud_rate = 9600
)(
  input clk,
  input rst,
  input rx,
  output reg done,
  output reg [7:0] rxdata
);

  localparam clkcount = clk_freq / baud_rate;

  integer count = 0;
  integer counts = 0;
  reg uclk = 0;

  enum bit [1:0] {IDLE, START} state;

  always @(posedge clk) begin
    if (count < clkcount/2)
      count <= count + 1;
    else begin
      count <= 0;
      uclk <= ~uclk;
    end
  end

  always @(posedge uclk) begin
    if (rst) begin
      rxdata <= 8'd0;
      counts <= 0;
      done <= 1'b0;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          counts <= 0;
          if (!rx)
            state <= START;
        end

        START: begin
          if (counts <= 7) begin
            rxdata <= {rx, rxdata[7:1]};
            counts <= counts + 1;
          end else begin
            done <= 1'b1;
            counts <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule

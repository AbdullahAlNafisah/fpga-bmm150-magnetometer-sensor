//==========================================================
// Description: FSM-based SPI Master for BMM150 magnetometer
// Author: Abdullah Alnafisah
//==========================================================
`timescale 1ns / 1ps

module spi_master_bmm150 #(
    parameter CLK_HZ  = 50_000_000,  // Input system clock frequency (Hz)
    parameter SPI_CLK = 5_000_000    // Desired SPI clock (Hz)
) (
    input logic clk,
    input logic rst_n,
    input logic enable,

    // Control Interface
    input  logic       start,     // Start SPI transaction
    input  logic       rw,        // 0=Write, 1=Read
    input  logic [6:0] reg_addr,  // Register address
    input  logic [7:0] tx_data,   // Data to send
    output logic [7:0] rx_data,   // Data received
    output logic       busy,      // Transaction in progress
    output logic       done,      // Transaction complete

    // SPI Physical Interface
    output logic sclk,
    output logic mosi,
    input  logic miso,
    output logic cs_n
);

  // Clock pulse generation
  localparam integer DIVIDER = CLK_HZ / (2 * SPI_CLK);
  localparam integer COUNTER_WIDTH = $clog2(DIVIDER);
  logic [COUNTER_WIDTH-1:0] clk_cnt;
  logic clk_pulse, sclk_b, prev_sclk_b;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_cnt <= 0;
      clk_pulse <= 1'b0;
      sclk_b <= 1'b1;
      prev_sclk_b <= 1'b1;
    end else if (enable) begin
      clk_pulse   <= 1'b0;
      prev_sclk_b <= sclk_b;
      if (start) begin
        clk_cnt <= 0;
        clk_pulse <= 1'b1;
        sclk_b <= 1'b1;
      end else if (clk_cnt == COUNTER_WIDTH'(DIVIDER - 1)) begin
        clk_cnt <= 0;
        clk_pulse <= 1'b1;
        sclk_b <= !sclk_b;
      end else begin
        clk_cnt <= clk_cnt + 1;
      end

    end else begin
      clk_cnt <= 0;
      clk_pulse <= 1'b0;
      prev_sclk_b <= 1'b1;
      sclk_b <= 1'b1;
    end
  end
  assign sclk = (state != IDLE && next_state != IDLE) ? sclk_b : 1'b1;

  // FSM States
  typedef enum logic [7:0] {
    IDLE,
    SEND_RW,
    SEND_ADDR,
    SEND_RECEIVE_DATA,
    COMPLETE
  } state_t;
  state_t state, next_state;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end


  // Internal registers
  logic mosi_b;
  logic [4:0] bits_cnt;

  // FSM combinational
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (enable && start) next_state = SEND_RW;
      SEND_RW: if (prev_sclk_b == 1'b1 && sclk_b == 1'b0) next_state = SEND_ADDR;
      SEND_ADDR:
      if (prev_sclk_b == 1'b0 && sclk_b == 1'b1 && bits_cnt == 0) next_state = SEND_RECEIVE_DATA;
      SEND_RECEIVE_DATA: if (bits_cnt == 7) next_state = COMPLETE;
      COMPLETE: if (prev_sclk_b == 1'b1 && sclk_b == 1'b0) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b1;
      mosi_b <= 1'b1;
      bits_cnt <= 0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          busy   <= 1'b0;
          done   <= 1'b0;
          mosi_b <= 1'b1;
        end
        SEND_RW: begin
          busy <= 1'b1;
          if (prev_sclk_b == 1'b1 && sclk_b == 1'b0) begin
            mosi_b   <= rw;
            bits_cnt <= 7;
          end
        end
        SEND_ADDR: begin
          if (prev_sclk_b == 1'b1 && sclk_b == 1'b0) begin
            mosi_b <= reg_addr[bits_cnt-1];
            if (bits_cnt != 0) bits_cnt <= bits_cnt - 1;
          end
        end
        SEND_RECEIVE_DATA: begin
          if (prev_sclk_b == 1'b1 && sclk_b == 1'b0) begin
            rx_data[7-bits_cnt] <= miso;
            mosi_b <= tx_data[7-bits_cnt];
            bits_cnt <= bits_cnt + 1;
          end
        end
        COMPLETE: begin
          if (prev_sclk_b == 1'b1 && sclk_b == 1'b0) begin
            rx_data[7-bits_cnt] <= miso;
            mosi_b <= tx_data[7-bits_cnt];
            done <= 1'b1;
          end
        end
        default: begin
          busy <= 1'b1;
          mosi_b <= 1'b1;
          bits_cnt <= 0;
        end
      endcase
    end
  end
  assign cs_n = (state != IDLE) ? 1'b0 : 1'b1;
  assign mosi = mosi_b;

endmodule

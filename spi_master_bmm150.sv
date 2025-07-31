//==========================================================
// File: spi_master_bmm150.sv
// Description: FSM-based SPI Master for BMM150 magnetometer
// Author: Abdullah Alnafisah
//==========================================================
`timescale 1ns / 1ps

module spi_master_bmm150 #(
    parameter CLK_DIV = 4  // Clock divider for SCLK generation
) (
    input logic clk,
    input logic rst_n,

    // Control Interface
    input  logic       start,     // Start SPI transaction
    input  logic [7:0] tx_data,   // Data to send
    input  logic [7:0] reg_addr,  // Register address
    input  logic       rw,        // 0=Write, 1=Read
    output logic [7:0] rx_data,   // Data received
    output logic       busy,      // Transaction in progress
    output logic       done,      // Transaction complete

    // SPI Physical Interface
    output logic sclk,
    output logic mosi,
    input  logic miso,
    output logic cs_n
);

  // FSM States
  typedef enum logic [2:0] {
    IDLE,
    ASSERT_CS,
    SEND_ADDR,
    SEND_DATA,
    RECEIVE_DATA,
    DEASSERT_CS,
    COMPLETE
  } state_t;

  state_t state, next_state;

  // Internal registers
  logic [7:0] shift_reg;
  logic [3:0] bit_cnt;
  logic [15:0] clk_div_cnt;
  logic sclk_int;

  // Clock divider for SCLK
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_div_cnt <= 0;
      sclk_int    <= 0;
    end else if (state != IDLE) begin
      if (clk_div_cnt == (CLK_DIV - 1)) begin
        clk_div_cnt <= 0;
        sclk_int    <= ~sclk_int;
      end else begin
        clk_div_cnt <= clk_div_cnt + 1;
      end
    end else begin
      sclk_int <= 0;
    end
  end

  assign sclk = sclk_int;

  // FSM sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM combinational
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = ASSERT_CS;
      ASSERT_CS: next_state = SEND_ADDR;
      SEND_ADDR: if (bit_cnt == 8 && !sclk_int) next_state = (rw) ? RECEIVE_DATA : SEND_DATA;
      SEND_DATA: if (bit_cnt == 8 && !sclk_int) next_state = DEASSERT_CS;
      RECEIVE_DATA: if (bit_cnt == 8 && !sclk_int) next_state = DEASSERT_CS;
      DEASSERT_CS: next_state = COMPLETE;
      COMPLETE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Output and shift register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs_n <= 1'b1;
      mosi <= 1'b0;
      bit_cnt <= 0;
      shift_reg <= 8'h00;
      rx_data <= 8'h00;
    end else begin
      case (state)
        IDLE: begin
          cs_n <= 1'b1;
          bit_cnt <= 0;
        end
        ASSERT_CS: begin
          cs_n <= 1'b0;
          shift_reg <= reg_addr;
        end
        SEND_ADDR: begin
          if (!sclk_int) begin
            mosi <= shift_reg[7];
            shift_reg <= {shift_reg[6:0], 1'b0};
            bit_cnt <= bit_cnt + 1;
          end
        end
        SEND_DATA: begin
          if (bit_cnt == 0) shift_reg <= tx_data;
          if (!sclk_int) begin
            mosi <= shift_reg[7];
            shift_reg <= {shift_reg[6:0], 1'b0};
            bit_cnt <= bit_cnt + 1;
          end
        end
        RECEIVE_DATA: begin
          if (!sclk_int) begin
            shift_reg <= {shift_reg[6:0], miso};
            bit_cnt   <= bit_cnt + 1;
          end
          if (bit_cnt == 8) rx_data <= shift_reg;
        end
        DEASSERT_CS: begin
          cs_n <= 1'b1;
        end
        default: begin
          // Safe fallback
          cs_n <= 1'b1;
          mosi <= 1'b0;
          bit_cnt <= 0;
        end
      endcase
    end
  end


  assign busy = (state != IDLE && state != COMPLETE);
  assign done = (state == COMPLETE);

endmodule

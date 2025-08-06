//==========================================================
// Description: FSM-based Controller for Field Loop Project
// Author: Abdullah Alnafisah
//==========================================================
module spi_driver #(
    parameter CLK_HZ  = 50_000_000,
    parameter SPI_CLK = 1_000_000
) (
    input logic clk,
    input logic nrst,

    // UART PC Interface
    input  logic rxd,
    output logic txd,

    // SPI Magnetometer Sensor Interface
    output logic sclk,
    output logic mosi,
    input  logic miso,
    output logic cs_n,
    input  logic drdy
);


  // SPI Instance
  logic        spi_enable;
  logic        spi_start;
  logic        spi_burst;
  logic        spi_rw;
  logic [ 6:0] spi_reg_addr;
  logic [ 7:0] spi_tx_data;
  logic [ 7:0] spi_rx_data;
  logic [63:0] spi_burst_data;
  logic        spi_busy;
  logic        spi_done;
  logic drdy_sync1, drdy_sync2;

  always_ff @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      drdy_sync1 <= 1'b1;
      drdy_sync2 <= 1'b1;
    end else begin
      drdy_sync1 <= drdy;
      drdy_sync2 <= drdy_sync1;
    end
  end

  spi_master_bmm150 #(
      .CLK_HZ (CLK_HZ),
      .SPI_CLK(SPI_CLK)
  ) spi_master_bmm150_inst (
      .clk(clk),
      .rst_n(nrst),
      .enable(spi_enable),
      .start(spi_start),
      .burst(spi_burst),
      .rw(spi_rw),
      .reg_addr(spi_reg_addr),
      .tx_data(spi_tx_data),
      .rx_data(spi_rx_data),
      .burst_data(spi_burst_data),
      .busy(spi_busy),
      .done(spi_done),
      .sclk(sclk),
      .mosi(mosi),
      .miso(miso),
      .cs_n(cs_n)
  );
  logic [7:0] spi_burst_data_array[7:0];
  logic [2:0] spi_burst_indx;
  assign spi_burst_data_array[0] = spi_burst_data[63:56];
  assign spi_burst_data_array[1] = spi_burst_data[55:48];
  assign spi_burst_data_array[2] = spi_burst_data[47:40];
  assign spi_burst_data_array[3] = spi_burst_data[39:32];
  assign spi_burst_data_array[4] = spi_burst_data[31:24];
  assign spi_burst_data_array[5] = spi_burst_data[23:16];
  assign spi_burst_data_array[6] = spi_burst_data[15:8];
  assign spi_burst_data_array[7] = spi_burst_data[7:0];

  // FSM States
  typedef enum logic [4:0] {
    IDLE,

    UART_SPI_ADDR,
    UART_SPI_DATA,
    UART_SPI_BURST,
    SPI_READ,

    UART_WRITE1,
    UART_WRITE2,
    UART_WRITE_BURST

  } state_t;
  state_t state;






  // Internal registers
  reg [7:0] tx_data_msb;
  reg [7:0] tx_data_lsb;

  // Timeout / Watchdog for FSM
  reg timer_active;
  localparam integer TIMEOUT_CYCLES = CLK_HZ;  // 1 timeout
  reg [$clog2(TIMEOUT_CYCLES)-1:0] fsm_timer;


  // Sequential logic
  always_ff @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      state          <= IDLE;
      timer_active   <= 1'b0;
      fsm_timer      <= '0;
      control        <= 16'd0;

      tx_start       <= 1'b0;
      prev_tx_busy   <= 1'b0;
      tx_data        <= 8'd0;
      tx_data_msb    <= 8'd0;
      tx_data_lsb    <= 8'd0;

      spi_enable     <= 1'b0;
      spi_start      <= 1'b0;
      spi_burst      <= 1'b0;
      spi_rw         <= 1'b0;
      spi_reg_addr   <= 7'd0;
      spi_tx_data    <= 8'd0;
      spi_burst_indx <= 0;

    end else begin
      tx_start     <= 1'b0;
      prev_tx_busy <= tx_busy;
      spi_enable   <= 1'b0;
      spi_start    <= 1'b0;

      case (state)
        IDLE: begin
          timer_active <= 1'b0;  // Stop timer in IDLE
          if (rx_ready) begin
            unique case (rx_data)

              8'hA2: begin
                state <= UART_SPI_ADDR;
                timer_active <= 1'b1;
                fsm_timer <= TIMEOUT_CYCLES;
              end

              8'hA3: begin
                state <= UART_SPI_BURST;
                timer_active <= 1'b1;
                fsm_timer <= TIMEOUT_CYCLES;
              end

              default: begin
                if (!tx_busy) begin
                  tx_data  <= rx_data;
                  tx_start <= 1'b1;
                end
              end

            endcase
          end
        end


        UART_SPI_ADDR: begin
          if (rx_ready) begin
            spi_rw <= rx_data[7];
            spi_reg_addr <= rx_data[6:0];
            if (rx_data[7]) begin
              spi_start <= 1'b1;
              spi_enable <= 1'b1;
              spi_burst <= 1'b0;
              state <= SPI_READ;
            end else begin
              state <= UART_SPI_DATA;
            end
          end
        end
        UART_SPI_DATA: begin
          if (rx_ready) begin
            spi_tx_data <= rx_data;
            spi_start <= 1'b1;
            spi_enable <= 1'b1;
            spi_burst <= 1'b0;
            state <= SPI_READ;
          end
        end
        UART_SPI_BURST: begin
          if (drdy_sync2) begin
            spi_rw <= 1'b1;
            spi_reg_addr <= 7'h42;
            spi_start <= 1'b1;
            spi_enable <= 1'b1;
            spi_burst <= 1'b1;
            spi_burst_indx <= 0;
            state <= SPI_READ;
          end
        end
        SPI_READ: begin
          timer_active <= 1'b0;
          if (spi_done) begin
            if (spi_burst) begin
              state <= UART_WRITE_BURST;
            end else begin
              tx_data_lsb <= spi_rx_data;
              state <= UART_WRITE2;
            end
          end else begin
            spi_enable <= 1'b1;
          end
        end




        UART_WRITE1: begin
          timer_active <= 1'b0;
          if (prev_tx_busy == 1'b0 && tx_busy == 1'b1) begin
            state <= UART_WRITE2;
          end else if (tx_busy == 1'b0) begin
            tx_data  <= tx_data_msb;
            tx_start <= 1'b1;
          end
        end
        UART_WRITE2: begin
          timer_active <= 1'b0;
          if (prev_tx_busy == 1'b0 && tx_busy == 1'b1) begin
            state <= IDLE;
          end else if (tx_busy == 1'b0) begin
            tx_data  <= tx_data_lsb;
            tx_start <= 1'b1;
          end
        end
        UART_WRITE_BURST: begin
          timer_active <= 1'b0;
          if (prev_tx_busy == 1'b0 && tx_busy == 1'b1) begin
            if (spi_burst_indx != 7) spi_burst_indx <= spi_burst_indx + 1;
            else state <= IDLE;
          end else if (tx_busy == 1'b0) begin
            tx_data  <= spi_burst_data_array[spi_burst_indx];
            tx_start <= 1'b1;
          end
        end


        default: begin
          state          <= IDLE;
          timer_active   <= 1'b0;
          fsm_timer      <= '0;
          control        <= 16'd0;

          tx_start       <= 1'b0;
          prev_tx_busy   <= 1'b0;
          tx_data        <= 8'd0;
          tx_data_msb    <= 8'd0;
          tx_data_lsb    <= 8'd0;

          spi_enable     <= 1'b0;
          spi_start      <= 1'b0;
          spi_burst      <= 1'b0;
          spi_rw         <= 1'b0;
          spi_reg_addr   <= 7'd0;
          spi_tx_data    <= 8'd0;
          spi_burst_indx <= 0;

        end
      endcase


      // timer
      if (timer_active) fsm_timer <= fsm_timer - 1;
      // Force return to IDLE if timeout expires
      if (timer_active && (fsm_timer == 0)) begin
        state <= IDLE;
        timer_active <= 1'b0;
      end



    end
  end


endmodule

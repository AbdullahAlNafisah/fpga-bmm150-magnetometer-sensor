# ==========================================================
# Description: Cocotb testbench for SPI Master BMM150 RTL
# Author: Abdullah Alnafisah
# ==========================================================
# logger.warning("This is a warning message")
# logger.error("This is an error message")
# logger.critical("This is a critical message")

# # Create a logger for this testbench
# logger = logging.getLogger("my_testbench")
# logger.debug("This is a debug message")
# logger.info("This is an info message")

import logging
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge
import random

CLK_PERIOD = 10  # ns


async def reset_pulse(rst_n):
    rst_n.value = 0
    await Timer(2 * CLK_PERIOD, units="ns")
    rst_n.value = 1
    await Timer(2 * CLK_PERIOD, units="ns")


@cocotb.test()
async def spi_basic_write_read_test(dut):
    """Basic test to verify SPI write and read functionality."""
    clk = dut.clk
    rst_n = dut.rst_n
    start = dut.start
    tx_data = dut.tx_data
    reg_addr = dut.reg_addr
    rw = dut.rw
    miso = dut.miso
    rx_data = dut.rx_data
    busy = dut.busy
    done = dut.done

    # run the clock "in the background"
    cocotb.start_soon(Clock(clk, CLK_PERIOD, units="ns").start())

    # Initialize inputs
    start.value = 0
    tx_data.value = 0
    reg_addr.value = 0
    rw.value = 0
    miso.value = 0

    # Reset DUT
    await reset_pulse(rst_n)

    dut._log.info("rx_data is %s", rx_data.value)
    # assert rx_data.value == 0, "rx_data is 0!"

    # # Start a write transaction
    # reg_addr.value = 0x4B  # Example register (power control)
    # tx_data.value = 0x01
    # rw.value = 0
    # start.value = 1
    # await FallingEdge(clk)
    # start.value = 0

    # # Wait for transaction completion
    # while busy.value == 1:
    #     await FallingEdge(clk)

    # assert done.value == 1, "Transaction did not complete properly"

    # # Simulate read response on MISO
    # miso.value = 1
    # reg_addr.value = 0x42
    # rw.value = 1
    # start.value = 1
    # await FallingEdge(clk)
    # start.value = 0

    # while busy.value == 1:
    #     await FallingEdge(clk)

    # read_val = int(dut.rx_data.value)
    # assert read_val in [0, 255], "Read data value unexpected"

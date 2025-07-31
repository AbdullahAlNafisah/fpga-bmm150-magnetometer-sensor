# ==========================================================
# File: test_spi_master_bmm150.py
# Description: Cocotb testbench for SPI Master BMM150 RTL
# Author: Abdullah Alnafisah
# ==========================================================
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random


CLK_PERIOD = 10  # ns


async def reset_dut(dut):
    dut.rst_n.value = 0
    await Timer(2 * CLK_PERIOD, units="ns")
    dut.rst_n.value = 1
    await Timer(2 * CLK_PERIOD, units="ns")


@cocotb.test()
async def spi_basic_write_read_test(dut):
    """Basic test to verify SPI write and read functionality."""

    # Start clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units="ns").start())

    # Initialize inputs
    dut.start.value = 0
    dut.tx_data.value = 0
    dut.reg_addr.value = 0
    dut.rw.value = 0
    dut.miso.value = 0

    # Reset DUT
    await reset_dut(dut)

    # Start a write transaction
    dut.reg_addr.value = 0x4B  # Example register (power control)
    dut.tx_data.value = 0x01
    dut.rw.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for transaction completion
    while dut.busy.value == 1:
        await RisingEdge(dut.clk)

    assert dut.done.value == 1, "Transaction did not complete properly"

    # Simulate read response on MISO
    dut.miso.value = 1
    dut.reg_addr.value = 0x42
    dut.rw.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while dut.busy.value == 1:
        await RisingEdge(dut.clk)

    read_val = int(dut.rx_data.value)
    assert read_val in [0, 255], "Read data value unexpected"

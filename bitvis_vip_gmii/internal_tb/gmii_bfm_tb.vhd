--================================================================================================================================
-- Copyright (c) 2020 by Bitvis AS.  All rights reserved.
-- You should have received a copy of the license file containing the MIT License (see LICENSE.TXT), if not,
-- contact Bitvis AS <support@bitvis.no>.
--
-- UVVM AND ANY PART THEREOF ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
-- THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
-- OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH UVVM OR THE USE OR OTHER DEALINGS IN UVVM.
--================================================================================================================================

---------------------------------------------------------------------------------------------
-- Description : See library quick reference (under 'doc') and README-file(s)
---------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_gmii;
use bitvis_vip_gmii.gmii_bfm_pkg.all;


-- Test case entity
entity gmii_bfm_tb is
  generic(
    GC_TEST : string  := "UVVM"
  );
end entity;

-- Test case architecture
architecture func of gmii_bfm_tb is
  --------------------------------------------------------------------------------
  -- Types and constants declarations
  --------------------------------------------------------------------------------
  constant C_CLK_PERIOD : time := 8 ns; -- 125 MHz

  --------------------------------------------------------------------------------
  -- Signal declarations
  --------------------------------------------------------------------------------
  signal clk         : std_logic := '0';
  signal clock_ena   : boolean   := false;

  signal gmii_tx_if  : t_gmii_tx_if;
  signal gmii_rx_if  : t_gmii_rx_if;

  signal data_array  : t_byte_array(0 to 99);

begin

  --------------------------------------------------------------------------------
  -- Clock Generator
  --------------------------------------------------------------------------------
  p_clock : clock_generator(clk, clock_ena, C_CLK_PERIOD, "GMII CLK");

  --------------------------------------------------------------------------------
  -- Instantiate test harness
  --------------------------------------------------------------------------------
  i_gmii_test_harness : entity bitvis_vip_gmii.test_harness(struct_bfm)
    generic map (
      GC_CLK_PERIOD => C_CLK_PERIOD
    )
    port map (
      clk           => clk,
      gmii_tx_if    => gmii_tx_if,
      gmii_rx_if    => gmii_rx_if
    );

  --------------------------------------------------------------------------------------------------------------------------------
  -- PROCESS: p_main
  --------------------------------------------------------------------------------------------------------------------------------
  p_main : process
    constant c_scope           : string := "Main seq.";
    variable v_gmii_bfm_config : t_gmii_bfm_config := C_GMII_BFM_CONFIG_DEFAULT;

    --------------------------------------------
    -- Overloads for this testbench
    --------------------------------------------
    procedure gmii_write (
      data_array : in t_byte_array) is
    begin
      gmii_write(data_array, "", gmii_tx_if, c_scope, shared_msg_id_panel, v_gmii_bfm_config);
    end procedure;

  begin

    -- To avoid that log files from different test cases (run in separate simulations) overwrite each other.
    set_log_file_name(GC_TEST & "_Log.txt");
    set_alert_file_name(GC_TEST & "_Alert.txt");

    -- Print the configuration to the log
    report_global_ctrl(VOID);
    report_msg_id_panel(VOID);

    -- Verbosity control
    enable_log_msg(ALL_MESSAGES);

    -- Generate random data
    for i in data_array'range loop
      data_array(i) <= random(data_array(0)'length);
    end loop;

    ------------------------------------------------------------------------------
    log(ID_LOG_HDR_LARGE, "Start Simulation of GMII");
    ------------------------------------------------------------------------------
    clock_ena <= true; -- start clock generator
    wait for 10*C_CLK_PERIOD;

    await_barrier(global_barrier, 1 us, "Synchronizing TX", error, c_scope);
    log(ID_LOG_HDR, "Testing that BFM procedures normalize data arrays");
    gmii_write(data_array(2 to 6));
    gmii_write(data_array(3 to 9));

    await_barrier(global_barrier, 1 us, "Synchronizing TX", error, c_scope);
    log(ID_LOG_HDR, "Testing explicit std_logic_vector values");
    gmii_write((x"01", x"23", x"45", x"67", x"89"));

    await_barrier(global_barrier, 1 us, "Synchronizing TX", error, c_scope);
    log(ID_LOG_HDR, "Testing data sizes");
    for i in 0 to 30 loop
      gmii_write(data_array(0 to i));
    end loop;

    await_barrier(global_barrier, 1 us, "Synchronizing TX", error, c_scope);
    log(ID_LOG_HDR, "Testing error case: read() valid data timeout");
    increment_expected_alerts_and_stop_limit(ERROR, 1);
    wait for 10*C_CLK_PERIOD; -- 10 = default max_wait_cycles

    await_barrier(global_barrier, 1 us, "Synchronizing TX", error, c_scope);
    log(ID_LOG_HDR, "Testing error case: expect() wrong data");
    increment_expected_alerts_and_stop_limit(ERROR, 1);
    gmii_write(data_array(0 to 10));

    await_barrier(global_barrier, 1 us, "Synchronizing TX", error, c_scope);
    log(ID_LOG_HDR, "Testing error case: expect() wrong size of data_array");
    increment_expected_alerts_and_stop_limit(ERROR, 1);
    gmii_write(data_array(0 to 10));

    await_barrier(global_barrier, 1 us, "Synchronizing TX", error, c_scope);
    log(ID_LOG_HDR, "Testing setup and hold times");
    v_gmii_bfm_config.bfm_sync     := SYNC_WITH_SETUP_AND_HOLD;
    v_gmii_bfm_config.clock_period := C_CLK_PERIOD;
    v_gmii_bfm_config.setup_time   := C_CLK_PERIOD/4;
    v_gmii_bfm_config.hold_time    := C_CLK_PERIOD/4;
    for i in 0 to 10 loop
      gmii_write(data_array(0 to i));
    end loop;

    ------------------------------------------------------------------------------
    -- Ending the simulation
    ------------------------------------------------------------------------------
    wait for 1000 ns;             -- Allow some time for completion
    report_alert_counters(FINAL); -- Report final counters and print conclusion (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED", c_scope);
    -- Finish the simulation
    std.env.stop;
    wait; -- to stop completely

  end process p_main;


  --------------------------------------------------------------------------------------------------------------------------------
  -- PROCESS: p_slave
  --------------------------------------------------------------------------------------------------------------------------------
  p_slave : process
    constant c_scope           : string := "Slave seq.";
    variable v_gmii_bfm_config : t_gmii_bfm_config := C_GMII_BFM_CONFIG_DEFAULT;
    variable v_rx_data_array   : t_byte_array(0 to 99);
    variable v_data_len        : natural;

    --------------------------------------------
    -- Overloads for this testbench
    --------------------------------------------
    procedure gmii_read (
      data_array : out t_byte_array;
      data_len   : out natural) is
    begin
      gmii_read(data_array, data_len, "", gmii_rx_if, c_scope, shared_msg_id_panel, v_gmii_bfm_config);
    end procedure;

    procedure gmii_expect (
      data_exp : in t_byte_array) is
    begin
      gmii_expect(data_exp, "", gmii_rx_if, error, c_scope, shared_msg_id_panel, v_gmii_bfm_config);
    end procedure;

  begin

    -- Testing that BFM procedures normalize data arrays
    await_barrier(global_barrier, 1 us, "Synchronizing RX", error, c_scope);
    gmii_read(v_rx_data_array(2 to 6), v_data_len);
    gmii_expect(data_array(3 to 9));

    -- Testing explicit std_logic_vector values
    await_barrier(global_barrier, 1 us, "Synchronizing RX", error, c_scope);
    gmii_expect((x"01", x"23", x"45", x"67", x"89"));

    -- Testing data sizes
    await_barrier(global_barrier, 1 us, "Synchronizing RX", error, c_scope);
    for i in 0 to 30 loop
      gmii_expect(data_array(0 to i));
    end loop;

    -- Testing error case: read() valid data timeout
    await_barrier(global_barrier, 1 us, "Synchronizing RX", error, c_scope);
    gmii_read(v_rx_data_array, v_data_len);

    -- Testing error case: expect() wrong data
    await_barrier(global_barrier, 1 us, "Synchronizing RX", error, c_scope);
    gmii_expect(data_array(10 to 20));

    -- Testing error case: expect() wrong size of data_array
    await_barrier(global_barrier, 1 us, "Synchronizing RX", error, c_scope);
    gmii_expect(data_array(0 to 15));

    -- Testing setup and hold times
    await_barrier(global_barrier, 1 us, "Synchronizing RX", error, c_scope);
    v_gmii_bfm_config.bfm_sync     := SYNC_WITH_SETUP_AND_HOLD;
    v_gmii_bfm_config.clock_period := C_CLK_PERIOD;
    v_gmii_bfm_config.setup_time   := C_CLK_PERIOD/4;
    v_gmii_bfm_config.hold_time    := C_CLK_PERIOD/4;
    for i in 0 to 10 loop
      gmii_expect(data_array(0 to i));
    end loop;

    wait;  -- to stop completely

  end process p_slave;

end func;
--================================================================================================================================
-- Copyright 2020 Bitvis
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and in the provided LICENSE.TXT.
--
-- Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
-- an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and limitations under the License.
--================================================================================================================================
-- Note : Any functionality not explicitly described in the documentation is subject to change at any time
----------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Description   : See library quick reference (under 'doc') and README-file(s)
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.all;

library bitvis_vip_spi;
use bitvis_vip_spi.spi_bfm_pkg.all;  

use work.P90_bfm_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_vvc_framework_common_methods_pkg.all;
use work.td_target_support_pkg.all;
use work.transaction_pkg.all;

--=================================================================================================
--=================================================================================================
--=================================================================================================
package vvc_methods_pkg is

  --===============================================================================================
  -- Types and constants for the P90 VVC
  --===============================================================================================
  constant C_VVC_NAME : string := "P90_VVC";

  signal P90_VVCT : t_vvc_target_record := set_vvc_target_defaults(C_VVC_NAME);
  alias THIS_VVCT : t_vvc_target_record is P90_VVCT;
  alias t_bfm_config is t_spi_bfm_config;

  constant C_SPI_INTER_BFM_DELAY_DEFAULT : t_inter_bfm_delay := (
    delay_type                         => NO_DELAY,
    delay_in_time                      => 0 ns,
    inter_bfm_delay_violation_severity => warning
  );

  type t_vvc_config is record
    inter_bfm_delay                       : t_inter_bfm_delay; -- Minimum delay between BFM accesses from the VVC. If parameter delay_type is set to NO_DELAY, BFM accesses will be back to back, i.e. no delay.
    cmd_queue_count_max                   : natural; -- Maximum pending number in command queue before queue is full. Adding additional commands will result in an ERROR.
    cmd_queue_count_threshold             : natural; -- An alert with severity 'cmd_queue_count_threshold_severity' will be issued if command queue exceeds this count. Used for early warning if command queue is almost full. Will be ignored if set to 0.
    cmd_queue_count_threshold_severity    : t_alert_level; -- Severity of alert to be initiated if exceeding cmd_queue_count_threshold
    result_queue_count_max                : natural; -- Maximum number of unfetched results before result_queue is full.
    result_queue_count_threshold_severity : t_alert_level; -- An alert with severity 'result_queue_count_threshold_severity' will be issued if command queue exceeds this count. Used for early warning if result queue is almost full. Will be ignored if set to 0.
    result_queue_count_threshold          : natural; -- Severity of alert to be initiated if exceeding result_queue_count_threshold
    bfm_config                            : t_spi_bfm_config; -- Configuration for the BFM. See BFM quick reference
    msg_id_panel                          : t_msg_id_panel; -- VVC dedicated message ID panel
    parent_msg_id_panel                   : t_msg_id_panel; --UVVM: temporary fix for HVVC, remove in v3.0
    feedback_sampling_clock_period        : time;
    PRESS_period                          : time;
    PRESS_high_time                       : time;
    TEMP_period                           : time;
    TEMP_high_time                        : time;
  end record;

  type t_vvc_config_array is array (natural range <>) of t_vvc_config;

  constant C_SPI_VVC_CONFIG_DEFAULT : t_vvc_config := (
    inter_bfm_delay                       => C_SPI_INTER_BFM_DELAY_DEFAULT,
    cmd_queue_count_max                   => C_CMD_QUEUE_COUNT_MAX,
    cmd_queue_count_threshold_severity    => C_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY,
    cmd_queue_count_threshold             => C_CMD_QUEUE_COUNT_THRESHOLD,
    result_queue_count_max                => C_RESULT_QUEUE_COUNT_MAX,
    result_queue_count_threshold_severity => C_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY,
    result_queue_count_threshold          => C_RESULT_QUEUE_COUNT_THRESHOLD,
    bfm_config                            => C_SPI_BFM_CONFIG_DEFAULT,
    msg_id_panel                          => C_VVC_MSG_ID_PANEL_DEFAULT,
    parent_msg_id_panel                   => C_VVC_MSG_ID_PANEL_DEFAULT,
    feedback_sampling_clock_period        => 10 ns,
    PRESS_period                          => 10 ns,
    PRESS_high_time                       => 5 ns,
    TEMP_period                          => 10 ns,
    TEMP_high_time                       => 5 ns
  );

  type t_vvc_status is record
    current_cmd_idx  : natural;
    previous_cmd_idx : natural;
    pending_cmd_cnt  : natural;
  end record;

  type t_vvc_status_array is array (natural range <>) of t_vvc_status;

  constant C_VVC_STATUS_DEFAULT : t_vvc_status := (
    current_cmd_idx  => 0,
    previous_cmd_idx => 0,
    pending_cmd_cnt  => 0
  );

  -- Transaction information for the wave view during simulation
  type t_transaction_info is record
    operation   : t_operation;
    msg         : string(1 to C_VVC_CMD_STRING_MAX_LENGTH);
    tx_data     : t_slv_array(C_VVC_CMD_MAX_WORDS - 1 downto 0)(C_VVC_CMD_DATA_MAX_LENGTH - 1 downto 0);
    rx_data     : t_slv_array(C_VVC_CMD_MAX_WORDS - 1 downto 0)(C_VVC_CMD_DATA_MAX_LENGTH - 1 downto 0);
    data_exp    : t_slv_array(C_VVC_CMD_MAX_WORDS - 1 downto 0)(C_VVC_CMD_DATA_MAX_LENGTH - 1 downto 0);
    num_words   : natural;
    word_length : natural;
  end record;

  type t_transaction_info_array is array (natural range <>) of t_transaction_info;

  constant C_TRANSACTION_INFO_DEFAULT : t_transaction_info := (
    tx_data     => (others => (others => '0')),
    rx_data     => (others => (others => '0')),
    data_exp    => (others => (others => '0')),
    num_words   => 0,
    word_length => 0,
    operation   => NO_OPERATION,
    msg         => (others => ' ')
  );
             

  shared variable shared_P90_vvc_config       : t_vvc_config_array(0 to C_MAX_VVC_INSTANCE_NUM - 1)       := (others => C_SPI_VVC_CONFIG_DEFAULT);
  shared variable shared_P90_vvc_status       : t_vvc_status_array(0 to C_MAX_VVC_INSTANCE_NUM - 1)       := (others => C_VVC_STATUS_DEFAULT);
  shared variable shared_P90_transaction_info : t_transaction_info_array(0 to C_MAX_VVC_INSTANCE_NUM - 1) := (others => C_TRANSACTION_INFO_DEFAULT);

  -- Scoreboard
  package P90_sb_pkg is new bitvis_vip_scoreboard.generic_sb_pkg
    generic map(t_element         => std_logic_vector(C_VVC_CMD_DATA_MAX_LENGTH - 1 downto 0),
                element_match     => std_match,
                to_string_element => to_string);
  use P90_sb_pkg.all;
  shared variable P90_VVC_SB : P90_sb_pkg.t_generic_sb;

  --==========================================================================================
  -- Methods dedicated to this VVC 
  -- - These procedures are called from the testbench in order for the VVC to execute
  --   BFM calls towards the given interface. The VVC interpreter will queue these calls
  --   and then the VVC executor will fetch the commands from the queue and handle the
  --   actual BFM execution.
  --   For details on how the BFM procedures work, see the QuickRef.
  --==========================================================================================

  procedure P90_start_PRESS(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

  procedure P90_stop_PRESS(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

  procedure P90_set_PRESS_period(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant PRESS_period     : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

  procedure P90_set_PRESS_high_time(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant PRESS_high_time  : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

procedure P90_start_TEMP(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

  procedure P90_stop_TEMP(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

  procedure P90_set_TEMP_period(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant TEMP_period     : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

  procedure P90_set_TEMP_high_time(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant TEMP_high_time  : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  );

  procedure P90_enable_func(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant functionality          : in t_functionality;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    );

  procedure P90_disable_func(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant functionality          : in t_functionality;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    );

  procedure P90_set_test_vectors(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant test_vectors           : in t_P90_test_vectors;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    );

  procedure P90_set_spi_seq(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant spi_cmd_seq            : in t_P90_spi_cmd_seq;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    );

  procedure P90_update_reg_map(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant reg_map                : in t_P90_reg_map;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    );

  --==============================================================================
  -- Transaction info methods
  --==============================================================================
  procedure set_global_vvc_transaction_info(
    signal   vvc_transaction_info_trigger : inout std_logic;
    variable vvc_transaction_info_group   : inout t_transaction_group;
    constant vvc_cmd                      : in t_vvc_cmd_record;
    constant vvc_config                   : in t_vvc_config;
    constant scope                        : in string := C_VVC_CMD_SCOPE_DEFAULT);

  procedure reset_vvc_transaction_info(
    variable vvc_transaction_info_group : inout t_transaction_group;
    constant vvc_cmd                    : in t_vvc_cmd_record);

  --==============================================================================
  -- VVC Activity
  --==============================================================================
  procedure update_vvc_activity_register(signal   global_trigger_vvc_activity_register : inout std_logic;
                                         variable vvc_status                           : inout t_vvc_status;
                                         constant activity                             : in t_activity;
                                         constant entry_num_in_vvc_activity_register   : in integer;
                                         constant last_cmd_idx_executed                : in natural;
                                         constant command_queue_is_empty               : in boolean;
                                         constant scope                                : in string := C_VVC_NAME);

  --==============================================================================
  -- VVC Scoreboard helper method
  --==============================================================================
  function pad_spi_sb(
    constant data : in std_logic_vector
  ) return std_logic_vector;

end package vvc_methods_pkg;

package body vvc_methods_pkg is

  --==============================================================================
  -- Methods dedicated to this VVC
  -- Notes:
  --   - shared_vvc_cmd is initialised to C_VVC_CMD_DEFAULT, and also reset to this after every command
  --==============================================================================

  procedure P90_start_PRESS(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "start_press";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, START_PRESS);
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_start_PRESS;

  procedure P90_stop_PRESS(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "stop_press";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, STOP_PRESS);
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_stop_PRESS;

  procedure P90_set_PRESS_period(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant press_period     : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "set_press_period";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ", " & to_string(press_period) & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, SET_PRESS_PERIOD);
    shared_vvc_cmd.press_period := press_period;
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_set_PRESS_period;

  procedure P90_set_PRESS_high_time(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant press_high_time  : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "set_press_high_time";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ", " & to_string(press_high_time) & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, SET_PRESS_HIGH_TIME);
    shared_vvc_cmd.press_high_time := press_high_time;
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_set_PRESS_high_time;

   procedure P90_start_TEMP(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "start_TEMP";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, START_TEMP);
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_start_TEMP;

  procedure P90_stop_TEMP(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "stop_TEMP";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, STOP_TEMP);
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_stop_TEMP;

  procedure P90_set_TEMP_period(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant TEMP_period     : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "set_TEMP_period";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ", " & to_string(TEMP_period) & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, SET_TEMP_PERIOD);
    shared_vvc_cmd.TEMP_period := TEMP_period;
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_set_TEMP_period;

  procedure P90_set_TEMP_high_time(
    signal   VVCT             : inout t_vvc_target_record;
    constant vvc_instance_idx : in integer;
    constant TEMP_high_time  : in time;
    constant msg              : in string;
    constant scope            : in string := C_VVC_CMD_SCOPE_DEFAULT
  ) is
    constant proc_name : string := "set_TEMP_high_time";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx) -- First part common for all
                                   & ", " & to_string(TEMP_high_time) & ")";
  begin
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, SET_TEMP_HIGH_TIME);
    shared_vvc_cmd.TEMP_high_time := TEMP_high_time;
    send_command_to_vvc(VVCT, scope => scope);
  end procedure P90_set_TEMP_high_time;


  procedure P90_enable_func(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant functionality          : in t_functionality;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    ) is
    constant proc_name             : string                                                                                := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call             : string                                                                                := proc_name & "(" & to_string(VVCT, vvc_instance_idx) & ")";
  
  begin
    shared_vvc_cmd                        := C_VVC_CMD_DEFAULT;

    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, ENABLE_FUNC);

    shared_vvc_cmd.functionality := functionality;

    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, C_UNUSED_MSG_ID_PANEL);
  end procedure;

  procedure P90_disable_func(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant functionality          : in t_functionality;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    ) is
    constant proc_name             : string                                                                                := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call             : string                                                                                := proc_name & "(" & to_string(VVCT, vvc_instance_idx) & ")";
  
  begin
    shared_vvc_cmd                        := C_VVC_CMD_DEFAULT;

    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, DISABLE_FUNC);

    shared_vvc_cmd.functionality := functionality;

    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, C_UNUSED_MSG_ID_PANEL);
  end procedure;

  procedure P90_set_test_vectors(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant test_vectors           : in t_P90_test_vectors;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    ) is
    constant proc_name             : string  := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call             : string  := proc_name & "(" & to_string(VVCT, vvc_instance_idx) & ")";
    variable v_num_words           : natural := test_vectors'length;
  begin
    shared_vvc_cmd                        := C_VVC_CMD_DEFAULT;

    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, SET_TEST_VECTOR);

    shared_vvc_cmd.test_vectors(0 to v_num_words-1) := test_vectors;
    shared_vvc_cmd.test_vectors(v_num_words to C_VVC_CMD_MAX_TEST_VECTOR_LENGTH-1) := (others => C_P90_test_vector_element_def);
    shared_vvc_cmd.test_vectors_len := v_num_words;

    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, C_UNUSED_MSG_ID_PANEL);
  end procedure;

  procedure P90_set_spi_seq(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant spi_cmd_seq            : in t_P90_spi_cmd_seq;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    ) is
    constant proc_name             : string  := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call             : string  := proc_name & "(" & to_string(VVCT, vvc_instance_idx) & ")";
    variable v_num_words           : natural := spi_cmd_seq'length;
  begin
    shared_vvc_cmd                        := C_VVC_CMD_DEFAULT;

    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, SET_SPI_SEQ);

    shared_vvc_cmd.spi_cmd_seq(0 to v_num_words-1) := spi_cmd_seq;    
    shared_vvc_cmd.spi_cmd_seq(v_num_words to C_VVC_CMD_MAX_SPI_CMD_SEQ_LENGTH-1) := (others => C_P90_spi_cmd_def);
    shared_vvc_cmd.spi_cmd_seq_len := v_num_words;

    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, C_UNUSED_MSG_ID_PANEL);
  end procedure;

  procedure P90_update_reg_map(
    signal   VVCT                   : inout t_vvc_target_record;
    constant vvc_instance_idx       : in integer;
    constant reg_map                : in t_P90_reg_map;
    constant msg                    : in string;
    constant scope                  : in string                   := C_VVC_CMD_SCOPE_DEFAULT
    ) is
    constant proc_name             : string  := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call             : string  := proc_name & "(" & to_string(VVCT, vvc_instance_idx) & ")";
  begin
    shared_vvc_cmd                        := C_VVC_CMD_DEFAULT;

    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, UPDATE_REG_MAP);

    shared_vvc_cmd.reg_map := reg_map;    
    
    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, C_UNUSED_MSG_ID_PANEL);
  end procedure;

  

  --==============================================================================
  -- Transaction info methods
  --==============================================================================
  procedure set_global_vvc_transaction_info(
    signal   vvc_transaction_info_trigger : inout std_logic;
    variable vvc_transaction_info_group   : inout t_transaction_group;
    constant vvc_cmd                      : in t_vvc_cmd_record;
    constant vvc_config                   : in t_vvc_config;
    constant scope                        : in string := C_VVC_CMD_SCOPE_DEFAULT) is
  begin
    case vvc_cmd.operation is
      when ENABLE_FUNC | DISABLE_FUNC | UPDATE_REG_MAP | SET_TEST_VECTOR | SET_SPI_SEQ =>
        vvc_transaction_info_group.bt.operation                             := vvc_cmd.operation;
        vvc_transaction_info_group.bt.data                                  := vvc_cmd.data;
        vvc_transaction_info_group.bt.data_exp                              := vvc_cmd.data_exp;
        vvc_transaction_info_group.bt.num_words                             := vvc_cmd.num_words;
        vvc_transaction_info_group.bt.word_length                           := vvc_cmd.word_length;
        vvc_transaction_info_group.bt.when_to_start_transfer                := vvc_cmd.when_to_start_transfer;
        vvc_transaction_info_group.bt.action_when_transfer_is_done          := vvc_cmd.action_when_transfer_is_done;
        vvc_transaction_info_group.bt.action_between_words                  := vvc_cmd.action_between_words;
        vvc_transaction_info_group.bt.functionality                         := vvc_cmd.functionality;
        vvc_transaction_info_group.bt.reg_map                               := vvc_cmd.reg_map;
        vvc_transaction_info_group.bt.test_vectors                          := vvc_cmd.test_vectors;
        vvc_transaction_info_group.bt.test_vectors_len                      := vvc_cmd.test_vectors_len;
        vvc_transaction_info_group.bt.spi_cmd_seq                           := vvc_cmd.spi_cmd_seq;
        vvc_transaction_info_group.bt.vvc_meta.msg(1 to vvc_cmd.msg'length) := vvc_cmd.msg;
        vvc_transaction_info_group.bt.vvc_meta.cmd_idx                      := vvc_cmd.cmd_idx;
        vvc_transaction_info_group.bt.transaction_status                    := IN_PROGRESS;
        gen_pulse(vvc_transaction_info_trigger, 0 ns, "pulsing global vvc transaction info trigger", scope, ID_NEVER);
      when others =>
        alert(TB_ERROR, "VVC operation not recognized");
    end case;

    wait for 0 ns;
  end procedure set_global_vvc_transaction_info;

  procedure reset_vvc_transaction_info(
    variable vvc_transaction_info_group : inout t_transaction_group;
    constant vvc_cmd                    : in t_vvc_cmd_record) is
  begin
    case vvc_cmd.operation is
      when ENABLE_FUNC | DISABLE_FUNC | UPDATE_REG_MAP | SET_TEST_VECTOR | SET_SPI_SEQ =>
        vvc_transaction_info_group.bt := C_BASE_TRANSACTION_SET_DEFAULT;
      when others =>
        null;
    end case;

    wait for 0 ns;
  end procedure reset_vvc_transaction_info;

  --==============================================================================
  -- VVC Activity
  --==============================================================================
  procedure update_vvc_activity_register(signal   global_trigger_vvc_activity_register : inout std_logic;
                                         variable vvc_status                           : inout t_vvc_status;
                                         constant activity                             : in t_activity;
                                         constant entry_num_in_vvc_activity_register   : in integer;
                                         constant last_cmd_idx_executed                : in natural;
                                         constant command_queue_is_empty               : in boolean;
                                         constant scope                                : in string := C_VVC_NAME) is
    variable v_activity : t_activity := activity;
  begin
    -- Update vvc_status after a command has finished (during same delta cycle the activity register is updated)
    if activity = INACTIVE then
      vvc_status.previous_cmd_idx := last_cmd_idx_executed;
      vvc_status.current_cmd_idx  := 0;
    end if;

    if v_activity = INACTIVE and not (command_queue_is_empty) then
      v_activity := ACTIVE;
    end if;
    shared_vvc_activity_register.priv_report_vvc_activity(vvc_idx               => entry_num_in_vvc_activity_register,
                                                          activity              => v_activity,
                                                          last_cmd_idx_executed => last_cmd_idx_executed);
    if global_trigger_vvc_activity_register /= 'L' then
      wait until global_trigger_vvc_activity_register = 'L';
    end if;
    gen_pulse(global_trigger_vvc_activity_register, 0 ns, "pulsing global trigger for vvc activity register", scope, ID_NEVER);
  end procedure;

  --==============================================================================
  -- VVC Scoreboard helper method
  --==============================================================================

  function pad_spi_sb(
    constant data : in std_logic_vector
  ) return std_logic_vector is
  begin
    return pad_sb_slv(data, C_VVC_CMD_DATA_MAX_LENGTH);
  end function pad_spi_sb;

end package body vvc_methods_pkg;


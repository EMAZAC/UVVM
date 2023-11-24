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

library cns_vip_P90;
use cns_vip_P90.P90_bfm_pkg.all;

--=================================================================================================
--=================================================================================================
--=================================================================================================
package transaction_pkg is

  --===============================================================================================
  -- t_operation
  -- - Bitvis defined BFM operations
  --===============================================================================================
  type t_operation is (
    -- UVVM common
    NO_OPERATION,
    AWAIT_COMPLETION,
    AWAIT_ANY_COMPLETION,
    ENABLE_LOG_MSG,
    DISABLE_LOG_MSG,
    FLUSH_COMMAND_QUEUE,
    FETCH_RESULT,
    INSERT_DELAY,
    TERMINATE_CURRENT_COMMAND,
    -- VVC local																										  
    ENABLE_FUNC, DISABLE_FUNC, UPDATE_REG_MAP, SET_TEST_VECTOR, SET_SPI_SEQ,
    START_PRESS,
    STOP_PRESS,
    SET_PRESS_PERIOD,
    SET_PRESS_HIGH_TIME,
    START_TEMP,
    STOP_TEMP,
    SET_TEMP_PERIOD,
    SET_TEMP_HIGH_TIME);

  constant C_VVC_CMD_STRING_MAX_LENGTH        : natural := 300;
  constant C_VVC_CMD_DATA_MAX_LENGTH          : natural := 32;
  constant C_VVC_CMD_MAX_WORDS                : natural := C_SPI_VVC_DATA_ARRAY_WIDTH;
  constant C_VVC_CMD_MAX_TEST_VECTOR_LENGTH   : natural := 1024;
  constant C_VVC_CMD_MAX_SPI_CMD_SEQ_LENGTH   : natural := 1024;

  type e_P90_VCC_functionality is (
            NO_FUNC,              
            SPI_MNG, 
            SPI_SEQUENCE_CHECK,
            SPI_TIMING_CHECK
            );  
  --==========================================================================================
  --
  -- Transaction info types, constants and global signal
  --
  --==========================================================================================

  -- Transaction status
  type t_transaction_status is (INACTIVE, IN_PROGRESS, FAILED, SUCCEEDED);

  constant C_TRANSACTION_STATUS_DEFAULT : t_transaction_status := INACTIVE;

  -- VVC Meta
  type t_vvc_meta is record
    msg     : string(1 to C_VVC_CMD_STRING_MAX_LENGTH);
    cmd_idx : integer;
  end record;

  constant C_VVC_META_DEFAULT : t_vvc_meta := (
    msg     => (others => ' '),
    cmd_idx => -1
  );

  -- Base transaction
  type t_base_transaction is record
    operation                    : t_operation;
    data                         : t_slv_array(C_VVC_CMD_MAX_WORDS - 1 downto 0)(C_VVC_CMD_DATA_MAX_LENGTH - 1 downto 0);
    data_exp                     : t_slv_array(C_VVC_CMD_MAX_WORDS - 1 downto 0)(C_VVC_CMD_DATA_MAX_LENGTH - 1 downto 0);
    num_words                    : natural;
    word_length                  : natural;
    when_to_start_transfer       : t_when_to_start_transfer;
    action_when_transfer_is_done : t_action_when_transfer_is_done;
    action_between_words         : t_action_between_words;
    functionality                : e_P90_VCC_functionality;
    reg_map                      : t_P90_reg_map;
    test_vectors                 : t_P90_test_vectors(0 to C_VVC_CMD_MAX_TEST_VECTOR_LENGTH-1);
    test_vectors_len             : natural;
    spi_cmd_seq                  : t_P90_spi_cmd_seq(0 to C_VVC_CMD_MAX_SPI_CMD_SEQ_LENGTH-1);
    spi_cmd_seq_len              : natural;
    vvc_meta                     : t_vvc_meta;
    transaction_status           : t_transaction_status;
  end record;

  constant C_BASE_TRANSACTION_SET_DEFAULT : t_base_transaction := (
    operation                    => NO_OPERATION,
    data                         => (others => (others => '0')),
    data_exp                     => (others => (others => '0')),
    num_words                    => 0,
    word_length                  => 0,
    when_to_start_transfer       => START_TRANSFER_IMMEDIATE,
    action_when_transfer_is_done => RELEASE_LINE_AFTER_TRANSFER,
    action_between_words         => HOLD_LINE_BETWEEN_WORDS,
    functionality                => NO_FUNC,
    reg_map                      => C_P90_reg_map,
    test_vectors                 => (others => C_P90_test_vector_element_def),
    test_vectors_len             => 0,
    spi_cmd_seq                  => (others => C_P90_spi_cmd_def),
    spi_cmd_seq_len              => 0,
    vvc_meta                     => C_VVC_META_DEFAULT,
    transaction_status           => C_TRANSACTION_STATUS_DEFAULT
  );

  -- Transaction group
  type t_transaction_group is record
    bt : t_base_transaction;
  end record;

  constant C_TRANSACTION_GROUP_DEFAULT : t_transaction_group := (
    bt => C_BASE_TRANSACTION_SET_DEFAULT
  );

  -- Global transaction info trigger signal
  type t_P90_transaction_trigger_array is array (natural range <>) of std_logic;
  signal global_P90_vvc_transaction_trigger : t_P90_transaction_trigger_array(0 to C_MAX_VVC_INSTANCE_NUM - 1) := (others => '0');

  -- Type is defined as array to coincide with channel based VVCs
  type t_P90_transaction_group_array is array (natural range <>) of t_transaction_group;
  -- Shared transaction info variable
  shared variable shared_P90_vvc_transaction_info : t_P90_transaction_group_array(0 to C_MAX_VVC_INSTANCE_NUM - 1) := (others => C_TRANSACTION_GROUP_DEFAULT);

end package transaction_pkg;

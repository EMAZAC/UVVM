--to do
-- timing error
-- SPI_TIMING_CHECK
-- UPDATE_REG_MAP

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
use uvvm_util.data_fifo_pkg.all;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.C_SB_CONFIG_DEFAULT;

library bitvis_vip_spi;
use bitvis_vip_spi.spi_bfm_pkg.all; 

use work.ASM330_bfm_pkg.all;
use work.vvc_methods_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_vvc_framework_common_methods_pkg.all;
use work.td_target_support_pkg.all;
use work.td_vvc_entity_support_pkg.all;
use work.td_cmd_queue_pkg.all;
use work.td_result_queue_pkg.all;
use work.transaction_pkg.all;

--=================================================================================================
entity ASM330_vvc is
    generic(
        GC_DATA_WIDTH                            : natural          := 8;
        GC_DATA_ARRAY_WIDTH                      : natural          := C_SPI_VVC_DATA_ARRAY_WIDTH;
        GC_INSTANCE_IDX                          : natural          := 1;                        -- Instance index for this SPI_VVCT instance
        GC_SPI_CONFIG                            : t_spi_bfm_config := C_SPI_BFM_CONFIG_DEFAULT; -- Behavior specification for BFM
        GC_CMD_QUEUE_COUNT_MAX                   : natural          := 1000;
        GC_CMD_QUEUE_COUNT_THRESHOLD             : natural          := 950;
        GC_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY    : t_alert_level    := warning;
        GC_RESULT_QUEUE_COUNT_MAX                : natural          := 1000;
        GC_RESULT_QUEUE_COUNT_THRESHOLD          : natural          := 950;
        GC_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY : t_alert_level    := warning
    );
    port(
        spi_vvc_if : inout t_spi_if := init_spi_if_signals(GC_SPI_CONFIG, false);
        int1       : inout std_logic :='0';
        int2       : inout std_logic :='0'
    );
end entity ASM330_vvc;

--=================================================================================================
--=================================================================================================

architecture behave of ASM330_vvc is

    constant C_SCOPE      : string       := C_VVC_NAME & "," & to_string(GC_INSTANCE_IDX);
    constant C_VVC_LABELS : t_vvc_labels := assign_vvc_labels(C_SCOPE, C_VVC_NAME, GC_INSTANCE_IDX, NA);

    constant C_GYRO_DRDY_BLOCK_FLAG   : string(1 to C_BLOCK_FLAG_NAME_SIZE+2) := C_BLOCK_FLAG_0 & " " & to_string(GC_INSTANCE_IDX);
    constant C_ACC_DRDY_BLOCK_FLAG    : string(1 to C_BLOCK_FLAG_NAME_SIZE+2) := C_BLOCK_FLAG_1 & " " & to_string(GC_INSTANCE_IDX);
    constant C_TEMP_DRDY_BLOCK_FLAG   : string(1 to C_BLOCK_FLAG_NAME_SIZE+2) := C_BLOCK_FLAG_2 & " " & to_string(GC_INSTANCE_IDX);
    constant C_FIFO_STATUS_BLOCK_FLAG : string(1 to C_BLOCK_FLAG_NAME_SIZE+2) := C_BLOCK_FLAG_3 & " " & to_string(GC_INSTANCE_IDX);

    signal executor_is_busy      : boolean := false;
    signal queue_is_increasing   : boolean := false;
    signal last_cmd_idx_executed : natural := 0;
    signal terminate_current_cmd : t_flag_record;

    -- Instantiation of the element dedicated Queue
    shared variable command_queue : work.td_cmd_queue_pkg.t_generic_queue;
    shared variable result_queue  : work.td_result_queue_pkg.t_generic_queue;


    alias vvc_config       : t_vvc_config is shared_ASM330_vvc_config(GC_INSTANCE_IDX);
    alias vvc_status       : t_vvc_status is shared_ASM330_vvc_status(GC_INSTANCE_IDX);
    alias transaction_info : t_transaction_info is shared_ASM330_transaction_info(GC_INSTANCE_IDX);
    -- Transaction info
    alias vvc_transaction_info_trigger : std_logic is global_ASM330_vvc_transaction_trigger(GC_INSTANCE_IDX);
    alias vvc_transaction_info         : t_transaction_group is shared_ASM330_vvc_transaction_info(GC_INSTANCE_IDX);
    -- VVC Activity 
    signal entry_num_in_vvc_activity_register : integer;

    --UVVM: temporary fix for HVVC, remove function below in v3.0
    function get_msg_id_panel(
            constant command    : in t_vvc_cmd_record;
            constant vvc_config : in t_vvc_config
        ) return t_msg_id_panel is
    begin
        -- If the parent_msg_id_panel is set then use it,
        -- otherwise use the VVCs msg_id_panel from its config.
        if command.msg(1 to 5) = "HVVC:" then
            return vvc_config.parent_msg_id_panel;
        else
            return vvc_config.msg_id_panel;
        end if;
    end function;

    signal s_internal_clk           : std_logic;
    signal s_gyro_internal_drdy          : std_logic;
    signal s_acc_internal_drdy          : std_logic;
    signal s_temp_internal_drdy          : std_logic;
    signal s_internal_int1 : std_logic;
    signal s_internal_int2 : std_logic;
    signal s_DRDY_ena               : boolean           := false;
    signal s_SPI_ena                : boolean           := false;
    signal s_boot_in_progress       : boolean           := true;
    signal s_TEST_mode_ena          : boolean           := false;
    signal s_SPI_SEQUENCE_CHECK_ena  : boolean           := false;
    signal s_CONFIGURATION_CHECK_ena : boolean           := false;
    signal s_SPI_TIMING_CHECK_ena    : boolean           := false;
    shared variable  v_reg_map                : t_ASM330_reg_map := C_ASM330_reg_map;
    signal s_reg_map_expected                 : t_ASM330_reg_map := C_ASM330_reg_map;
    signal s_spi_cmd_seq_expect               : t_ASM330_spi_cmd_seq(0 to C_VVC_CMD_MAX_SPI_CMD_SEQ_LENGTH-1);
    signal s_reg                    : e_ASM330_RegisterNames;
    signal s_readed_reg             : boolean := false;
    signal s_wrote_reg              : boolean := false;  
    signal s_GYRO_power_down_en  : boolean := false;
    signal s_ACC_power_down_en   : boolean := false;
    signal s_test_vector            : t_ASM330_test_vectors(0 to C_VVC_CMD_MAX_TEST_VECTOR_LENGTH-1);
    signal s_test_vector_size       : integer :=0;
    signal s_spi_cmd_seq_len        : integer :=0;
    signal s_BDR_cnt                : integer :=0;
    shared variable v_fifo_write_en : boolean := false;
    
    shared variable v_gyro_test_vector_idx : integer:=0;
    shared variable v_temp_test_vector_idx : integer:=0;
    shared variable v_acc_test_vector_idx : integer:=0;
    shared variable s_seq_idx : integer:=0;

    signal s_fifo_idx : natural := 0;


begin

    --===============================================================================================
    -- Constructor
    -- - Set up the defaults and show constructor if enabled
    --===============================================================================================
    work.td_vvc_entity_support_pkg.vvc_constructor(C_SCOPE, GC_INSTANCE_IDX, vvc_config, command_queue, result_queue, GC_SPI_CONFIG,
        GC_CMD_QUEUE_COUNT_MAX, GC_CMD_QUEUE_COUNT_THRESHOLD, GC_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY,
        GC_RESULT_QUEUE_COUNT_MAX, GC_RESULT_QUEUE_COUNT_THRESHOLD, GC_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY);
    --===============================================================================================

    --===============================================================================================
    -- Command interpreter
    -- - Interpret, decode and acknowledge commands from the central sequencer
    --===============================================================================================
    cmd_interpreter : process
        variable v_cmd_has_been_acked : boolean; -- Indicates if acknowledge_cmd() has been called for the current shared_vvc_cmd
        variable v_local_vvc_cmd      : t_vvc_cmd_record := C_VVC_CMD_DEFAULT;
        variable v_msg_id_panel       : t_msg_id_panel;
        variable v_temp_msg_id_panel  : t_msg_id_panel; --UVVM: temporary fix for HVVC, remove in v3.0
    begin
        -- 0. Initialize the process prior to first command
        work.td_vvc_entity_support_pkg.initialize_interpreter(terminate_current_cmd, global_awaiting_completion);

        -- initialise shared_vvc_last_received_cmd_idx for channel and instance
        shared_vvc_last_received_cmd_idx(NA, GC_INSTANCE_IDX) := 0;
        -- Register VVC in vvc activity register
        entry_num_in_vvc_activity_register <= shared_vvc_activity_register.priv_register_vvc(name => C_VVC_NAME,
                instance => GC_INSTANCE_IDX);
        -- Set initial value of v_msg_id_panel to msg_id_panel in config
        v_msg_id_panel := vvc_config.msg_id_panel;

        s_fifo_idx <= uvvm_fifo_init(C_FIFO_BYTE_SIZE); --3KByte

        -- Then for every single command from the sequencer
        loop -- basically as long as new commands are received

            -- 1. wait until command targeted at this VVC. Must match VVC name, instance and channel (if applicable)
            --    releases global semaphore
            -------------------------------------------------------------------------
            work.td_vvc_entity_support_pkg.await_cmd_from_sequencer(C_VVC_LABELS, vvc_config, THIS_VVCT, VVC_BROADCAST, global_vvc_busy, global_vvc_ack, v_local_vvc_cmd);
            v_cmd_has_been_acked := false; -- Clear flag

            -- update shared_vvc_last_received_cmd_idx with received command index
            shared_vvc_last_received_cmd_idx(NA, GC_INSTANCE_IDX) := v_local_vvc_cmd.cmd_idx;

            -- Select between a provided msg_id_panel via the vvc_cmd_record from a VVC with a higher hierarchy or the
            -- msg_id_panel in this VVC's config. This is to correctly handle the logging when using Hierarchical-VVCs.
            v_msg_id_panel := get_msg_id_panel(v_local_vvc_cmd, vvc_config);

            -- 2a. Put command on the queue if intended for the executor
            -------------------------------------------------------------------------
            if v_local_vvc_cmd.command_type = QUEUED then
                work.td_vvc_entity_support_pkg.put_command_on_queue(v_local_vvc_cmd, command_queue, vvc_status, queue_is_increasing);

            -- 2b. Otherwise command is intended for immediate response
            -------------------------------------------------------------------------
            elsif v_local_vvc_cmd.command_type = IMMEDIATE then

                --UVVM: temporary fix for HVVC, remove two lines below in v3.0
                if v_local_vvc_cmd.operation /= DISABLE_LOG_MSG and v_local_vvc_cmd.operation /= ENABLE_LOG_MSG then
                    v_temp_msg_id_panel     := vvc_config.msg_id_panel;
                    vvc_config.msg_id_panel := v_msg_id_panel;
                end if;

                case v_local_vvc_cmd.operation is

                    when AWAIT_COMPLETION =>
                        work.td_vvc_entity_support_pkg.interpreter_await_completion(v_local_vvc_cmd, command_queue, vvc_config, executor_is_busy, C_VVC_LABELS, last_cmd_idx_executed);

                    when AWAIT_ANY_COMPLETION =>
                        if not v_local_vvc_cmd.gen_boolean then
                            -- Called with lastness = NOT_LAST: Acknowledge immediately to let the sequencer continue
                            work.td_target_support_pkg.acknowledge_cmd(global_vvc_ack, v_local_vvc_cmd.cmd_idx);
                            v_cmd_has_been_acked := true;
                        end if;
                        work.td_vvc_entity_support_pkg.interpreter_await_any_completion(v_local_vvc_cmd, command_queue, vvc_config, executor_is_busy, C_VVC_LABELS, last_cmd_idx_executed, global_awaiting_completion);

                    when DISABLE_LOG_MSG =>
                        uvvm_util.methods_pkg.disable_log_msg(v_local_vvc_cmd.msg_id, vvc_config.msg_id_panel, to_string(v_local_vvc_cmd.msg) & format_command_idx(v_local_vvc_cmd), C_SCOPE);

                    when ENABLE_LOG_MSG =>
                        uvvm_util.methods_pkg.enable_log_msg(v_local_vvc_cmd.msg_id, vvc_config.msg_id_panel, to_string(v_local_vvc_cmd.msg) & format_command_idx(v_local_vvc_cmd), C_SCOPE);

                    when FLUSH_COMMAND_QUEUE =>
                        work.td_vvc_entity_support_pkg.interpreter_flush_command_queue(v_local_vvc_cmd, command_queue, vvc_config, vvc_status, C_VVC_LABELS);

                    when TERMINATE_CURRENT_COMMAND =>
                        work.td_vvc_entity_support_pkg.interpreter_terminate_current_command(v_local_vvc_cmd, vvc_config, C_VVC_LABELS, terminate_current_cmd);

                    when FETCH_RESULT =>
                        work.td_vvc_entity_support_pkg.interpreter_fetch_result(result_queue, v_local_vvc_cmd, vvc_config, C_VVC_LABELS, last_cmd_idx_executed, shared_vvc_response);

                    when others =>
                        tb_error("Unsupported command received for IMMEDIATE execution: '" & to_string(v_local_vvc_cmd.operation) & "'", C_SCOPE);

                end case;

                --UVVM: temporary fix for HVVC, remove line below in v3.0
                if v_local_vvc_cmd.operation /= DISABLE_LOG_MSG and v_local_vvc_cmd.operation /= ENABLE_LOG_MSG then
                    vvc_config.msg_id_panel := v_temp_msg_id_panel;
                end if;

            else
                tb_error("command_type is not IMMEDIATE or QUEUED", C_SCOPE);
            end if;

            -- 3. Acknowledge command after runing or queuing the command
            -------------------------------------------------------------------------
            if not v_cmd_has_been_acked then
                --uvvm_vvc_framework.ti_vvc_framework_support_pkg.acknowledge_cmd(global_vvc_ack);
                work.td_target_support_pkg.acknowledge_cmd(global_vvc_ack, v_local_vvc_cmd.cmd_idx);
            end if;

        end loop;
    end process;
    --===============================================================================================

    --===============================================================================================
    -- Command executor
    -- - Fetch and execute the commands
    --===============================================================================================
    cmd_executor : process
        variable v_cmd                                   : t_vvc_cmd_record;
        variable v_result                                : t_slv_array(C_VVC_CMD_MAX_WORDS - 1 downto 0)(C_VVC_CMD_DATA_MAX_LENGTH - 1 downto 0);
        variable v_msg_id_panel                          : t_msg_id_panel;
        -- bus size
        variable v_num_words : natural := 0;
        -- normalized data to bus width
        variable v_normalized_data     : t_slv_array(GC_DATA_ARRAY_WIDTH - 1 downto 0)(GC_DATA_WIDTH - 1 downto 0) := (others => (others => '0'));
        variable v_normalized_data_exp : t_slv_array(GC_DATA_ARRAY_WIDTH - 1 downto 0)(GC_DATA_WIDTH - 1 downto 0) := (others => (others => '0'));
        variable v_data_receive        : t_slv_array(GC_DATA_ARRAY_WIDTH - 1 downto 0)(GC_DATA_WIDTH - 1 downto 0) := (others => (others => '0'));

    begin
        -- 0. Initialize the process prior to first command
        -------------------------------------------------------------------------
        work.td_vvc_entity_support_pkg.initialize_executor(terminate_current_cmd);
        -- Set initial value of v_msg_id_panel to msg_id_panel in config
        v_msg_id_panel := vvc_config.msg_id_panel;

        -- Setup SPI scoreboard
        ASM330_VVC_SB.set_scope("ASM330_VVC_SB");
        ASM330_VVC_SB.enable(GC_INSTANCE_IDX, "ASM330 VVC SB Enabled");
        ASM330_VVC_SB.config(GC_INSTANCE_IDX, C_SB_CONFIG_DEFAULT);
        ASM330_VVC_SB.enable_log_msg(GC_INSTANCE_IDX, ID_DATA);

        loop

            -- update vvc activity
            update_vvc_activity_register(global_trigger_vvc_activity_register, vvc_status, INACTIVE, entry_num_in_vvc_activity_register, last_cmd_idx_executed, command_queue.is_empty(VOID), C_SCOPE);

            -- 1. Set defaults, fetch command and log
            -------------------------------------------------------------------------
            work.td_vvc_entity_support_pkg.fetch_command_and_prepare_executor(v_cmd, command_queue, vvc_config, vvc_status, queue_is_increasing, executor_is_busy, C_VVC_LABELS);

            -- update vvc activity
            update_vvc_activity_register(global_trigger_vvc_activity_register, vvc_status, ACTIVE, entry_num_in_vvc_activity_register, last_cmd_idx_executed, command_queue.is_empty(VOID), C_SCOPE);

            -- Set the transaction info for waveview
            transaction_info           := C_TRANSACTION_INFO_DEFAULT;
            transaction_info.operation := v_cmd.operation;
            transaction_info.msg       := pad_string(to_string(v_cmd.msg), ' ', transaction_info.msg'length);

            -- Select between a provided msg_id_panel via the vvc_cmd_record from a VVC with a higher hierarchy or the
            -- msg_id_panel in this VVC's config. This is to correctly handle the logging when using Hierarchical-VVCs.
            v_msg_id_panel := get_msg_id_panel(v_cmd, vvc_config);

            -- 2. Execute the fetched command
            -------------------------------------------------------------------------
            v_num_words                  := v_cmd.num_words;
            transaction_info.num_words   := v_cmd.num_words;
            transaction_info.word_length := GC_DATA_WIDTH;

            case v_cmd.operation is -- Only operations in the dedicated record are relevant

                when ENABLE_FUNC =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    case v_cmd.functionality is
                        when NO_FUNC =>
                            null;
                        when TEST_MODE =>
                            if s_TEST_mode_ena then
                                tb_error("ASM330 Test mode already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_TEST_mode_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 Test mode started", C_SCOPE);
                            end if;

                        when SPI_MNG =>
                            if s_SPI_ena then
                                tb_error("ASM330 SPI mng already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 SPI mng started", C_SCOPE);
                            end if;
                        when DRDY_MNG =>
                            if s_DRDY_ena then
                                tb_error("ASM330 DRDY mng already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_DRDY_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 DRDY mng started", C_SCOPE);
                            end if;

                        when SPI_SEQUENCE_CHECK =>
                            if s_SPI_SEQUENCE_CHECK_ena then
                                tb_error("ASM330 SPI SEQ CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_SEQUENCE_CHECK_ena <= true;
                                s_seq_idx := 0;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 SPI SEQ CHECK started", C_SCOPE);
                            end if;

                        when CONFIGURATION_CHECK =>
                            if s_CONFIGURATION_CHECK_ena then
                                tb_error("ASM330 Configuration CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_CONFIGURATION_CHECK_ena <= true;
                                s_reg_map_expected <= v_cmd.reg_map;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 Configuration CHECK started", C_SCOPE);
                            end if;

                        when SPI_TIMING_CHECK =>
                            if s_SPI_TIMING_CHECK_ena then
                                tb_error("ASM330 SPI timing CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_TIMING_CHECK_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 SPI timing CHECK started", C_SCOPE);
                            end if;

                        when OTHERS =>
                            tb_error("ASM330 Enable functionality error, code error " & format_msg(v_cmd), C_SCOPE);
                    end case;

                when DISABLE_FUNC =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    case v_cmd.functionality is
                        when NO_FUNC =>
                            null;
                        when TEST_MODE =>
                            if not s_TEST_mode_ena then
                                tb_error("ASM330 Test mode already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_TEST_mode_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 Test mode disabled", C_SCOPE);
                            end if;
                        when SPI_MNG =>
                            if not s_SPI_ena then
                                tb_error("ASM330 SPI mng already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 SPI mng disabled", C_SCOPE);
                            end if;
                        when DRDY_MNG =>
                            if not s_DRDY_ena then
                                tb_error("ASM330 DRDY mng already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_DRDY_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 DRDY mng disabled", C_SCOPE);
                            end if;

                        when SPI_SEQUENCE_CHECK =>
                            if not s_SPI_SEQUENCE_CHECK_ena then
                                tb_error("ASM330 SPI SEQ CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_SEQUENCE_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 SPI SEQ CHECK disabled", C_SCOPE);
                            end if;

                        when CONFIGURATION_CHECK =>
                            if not s_CONFIGURATION_CHECK_ena then
                                tb_error("ASM330 Configuration CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_CONFIGURATION_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 Configuration CHECK disabled", C_SCOPE);
                            end if;

                        when SPI_TIMING_CHECK =>
                            if not s_SPI_TIMING_CHECK_ena then
                                tb_error("ASM330 SPI timing CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_TIMING_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ASM330 SPI timing CHECK disabled", C_SCOPE);
                            end if;
                        when OTHERS =>
                            tb_error("ASM330 Disable functionality error, code error " & format_msg(v_cmd), C_SCOPE);
                    end case;

                when SET_TEST_VECTOR =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    s_test_vector <= v_cmd.test_vectors;
                    s_test_vector_size <= v_cmd.test_vectors_len-1;  
                    v_gyro_test_vector_idx := 0;     
                    v_temp_test_vector_idx := 0;     
                    v_acc_test_vector_idx := 0;     
                    log(ID_BFM, "ASM330 test vector updated", C_SCOPE);  

                when SET_SPI_SEQ =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    s_spi_cmd_seq_expect  <= v_cmd.spi_cmd_seq;
                    s_spi_cmd_seq_len <= v_cmd.spi_cmd_seq_len;
                    s_seq_idx := 0;    
                    log(ID_BFM, "ASM330 test vector updated", C_SCOPE);
                               
                when UPDATE_REG_MAP =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    v_reg_map  := v_cmd.reg_map;
                    log(ID_BFM, "ASM330 register map updated", C_SCOPE);
                               

                -- UVVM common operations
                --===================================
                when INSERT_DELAY =>
                    log(ID_INSERTED_DELAY, "Running: " & to_string(v_cmd.proc_call) & " " & format_command_idx(v_cmd), C_SCOPE, v_msg_id_panel);
                    if v_cmd.gen_integer_array(0) = -1 then
                        -- Delay specified using time
                        wait until terminate_current_cmd.is_active = '1' for v_cmd.delay;
                    else
                        -- Delay specified using integer
                        wait until terminate_current_cmd.is_active = '1' for v_cmd.gen_integer_array(0) * vvc_config.bfm_config.spi_bit_time;
                    end if;
                when others =>
                    tb_error("Unsupported local command received for execution: '" & to_string(v_cmd.operation) & "'", C_SCOPE);
            end case;


            -- Reset terminate flag if any occurred
            if (terminate_current_cmd.is_active = '1') then
                log(ID_CMD_EXECUTOR, "Termination request received", C_SCOPE, v_msg_id_panel);
                uvvm_vvc_framework.ti_vvc_framework_support_pkg.reset_flag(terminate_current_cmd);
            end if;

            last_cmd_idx_executed <= v_cmd.cmd_idx;
            -- Reset the transaction info for waveview
            transaction_info := C_TRANSACTION_INFO_DEFAULT;
            -- Set VVC Transaction Info back to default values
            reset_vvc_transaction_info(vvc_transaction_info, v_cmd);
        end loop;
    end process;
    --========================================================================================================================

    --===============================================================================================
    -- Command termination handler
    -- - Handles the termination request record (sets and resets terminate flag on request)
    --===============================================================================================
    cmd_terminator : uvvm_vvc_framework.ti_vvc_framework_support_pkg.flag_handler(terminate_current_cmd); -- flag: is_active, set, reset
    --===============================================================================================

    --========================================================================================================================
    -- SPI management process
    -- - Process that generates the clock internal signal
    --========================================================================================================================
    spi_mng : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            if not s_SPI_ena and s_boot_in_progress then
                wait until s_SPI_ena and not s_boot_in_progress;
            end if;

            ASM330_SPI_mng(spi_vvc_if,true,v_reg_map,s_reg, s_readed_reg, s_wrote_reg,vvc_config.bfm_config);

            wait for 0 ns;
        end loop;
    end process;

    reg_map_app : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_GYRO_power_down_en <= true;
        s_ACC_power_down_en <= true;
        loop
            if not s_SPI_ena then
                wait until s_SPI_ena;
            end if;

            wait until ((s_wrote_reg'event and s_wrote_reg = true));

            s_GYRO_power_down_en <= true when (v_reg_map(f_idx2int(REG_CTRL2_G)).value(7 downto 4)="0000" or 
                                                v_reg_map(f_idx2int(REG_CTRL4_C)).value(6)='1') else false;
            s_ACC_power_down_en <= true when (v_reg_map(f_idx2int(REG_CTRL1_XL)).value(7 downto 4)="0000") else false;

        end loop;
    end process;
    --========================================================================================================================
    -- INTERRUPT
    --========================================================================================================================

    int1_mng : process
        variable v_gyro_event : boolean := false;
        variable v_acc_event : boolean := false;
        variable v_temp_event : boolean := false;
        
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_internal_int1 <= '0';

        loop
            wait until ((s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') or 
                        (s_acc_internal_drdy'event and s_acc_internal_drdy='1') or 
                        (s_temp_internal_drdy'event and s_temp_internal_drdy='1') or
                        (s_readed_reg'event and s_readed_reg = true and s_reg=REG_FIFO_DATA_OUT_Z_H)) for 75 us;

            v_gyro_event := false;
            v_acc_event  := false;
            v_temp_event := false;

            s_internal_int1 <= '0';

            if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                v_gyro_event := true;
                await_unblock_flag(C_GYRO_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_GYRO_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;
    
            if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
                v_acc_event := true;
                await_unblock_flag(C_ACC_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_ACC_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;
    
            if (s_temp_internal_drdy'event and s_temp_internal_drdy='1') then
                v_temp_event := true;
                await_unblock_flag(C_TEMP_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_TEMP_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;

            if ((s_readed_reg'event and s_readed_reg = true and s_reg=REG_FIFO_DATA_OUT_Z_H)) then
                await_unblock_flag(C_FIFO_STATUS_BLOCK_FLAG, 0 ns, "waiting for " & C_FIFO_STATUS_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(0)='1') then
                if (v_acc_event) then
                    s_internal_int1 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(1)='1') then
                if (v_gyro_event) then
                    s_internal_int1 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(2)='1') then
                s_internal_int1 <= '1';
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(3)='1') then                
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(7)='1') then
                    s_internal_int1 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(4)='1') then
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(5)='1') then
                    s_internal_int1 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(5)='1') then
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(6)='1') then
                    s_internal_int1 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(6)='1') then
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(3)='1') then
                    s_internal_int1 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT1_CTRL)).value(7)='1') then
                if (v_gyro_event or 
                        v_acc_event or 
                        v_temp_event) then
                    s_internal_int1 <= '1'; 
                end if;                             
            end if;            
            
        end loop;
    end process;

    int2_mng : process
        variable v_gyro_event : boolean := false;
        variable v_acc_event : boolean := false;
        variable v_temp_event : boolean := false;
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_internal_int2 <= '0';
        loop
            wait until ((s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') or 
                        (s_acc_internal_drdy'event and s_acc_internal_drdy='1') or 
                        (s_temp_internal_drdy'event and s_temp_internal_drdy='1') or
                        (s_readed_reg'event and s_readed_reg = true and s_reg=REG_FIFO_DATA_OUT_Z_H)) for 75 us;

            v_gyro_event := false;
            v_acc_event  := false;
            v_temp_event := false;

            s_internal_int2 <= '0';

            if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                v_gyro_event := true;
                await_unblock_flag(C_GYRO_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_GYRO_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;
    
            if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
                v_acc_event := true;
                await_unblock_flag(C_ACC_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_ACC_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;
    
            if (s_temp_internal_drdy'event and s_temp_internal_drdy='1') then
                v_temp_event := true;
                await_unblock_flag(C_TEMP_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_TEMP_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;

            if ((s_readed_reg'event and s_readed_reg = true and s_reg=REG_FIFO_DATA_OUT_Z_H)) then
                await_unblock_flag(C_FIFO_STATUS_BLOCK_FLAG, 0 ns, "waiting for " & C_FIFO_STATUS_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
            end if;

            if (v_reg_map(f_idx2int(REG_INT2_CTRL)).value(0)='1') then
                if (v_acc_event) then
                    s_internal_int2 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT2_CTRL)).value(1)='1') then
                if (v_gyro_event) then
                    s_internal_int2 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT2_CTRL)).value(2)='1') then
                s_internal_int2 <= '1';
            end if;

            if (v_reg_map(f_idx2int(REG_INT2_CTRL)).value(3)='1') then                
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(7)='1') then
                    s_internal_int2 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT2_CTRL)).value(4)='1') then
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(5)='1') then
                    s_internal_int2 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT2_CTRL)).value(5)='1') then
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(6)='1') then
                    s_internal_int2 <= '1';
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_INT2_CTRL)).value(6)='1') then
                if (v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(3)='1') then
                    s_internal_int2 <= '1';
                end if;
            end if;            
            
        end loop;
    end process;

    int_out : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        int1 <= '0';
        int2 <= '0';
        loop
            wait until ((s_internal_int1'event) or 
                        (s_internal_int2'event) );
        
            if (v_reg_map(f_idx2int(REG_CTRL4_C)).value(5)='1') then
                int1 <= s_internal_int1 or s_internal_int2;
            else
                int1 <= s_internal_int1;
            end if; 
    
            int2 <= s_internal_int2;   

        end loop;
    end process;

    -- --========================================================================================================================
    -- -- DRDY Generator process
    -- -- - Process that generates the DRDY signal
    -- --========================================================================================================================

    GYRO_DRDY_generator : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_gyro_internal_drdy <= '0';
        loop

            if not s_DRDY_ena or s_GYRO_power_down_en then -- enable
                s_gyro_internal_drdy <= '0';
                wait until s_DRDY_ena and (not s_GYRO_power_down_en);
            end if;

            if (v_reg_map(f_idx2int(REG_CTRL2_G)).value(7 downto 4)="0000") then
                wait until v_reg_map(f_idx2int(REG_CTRL2_G)).value(7 downto 4)/="0000";
            end if;
            if (s_TEST_mode_ena) then
                wait for (C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL2_G)).value(7 downto 4))) - 
                          C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL2_G)).value(7 downto 4)))*
                          to_integer(signed(v_reg_map(f_idx2int(REG_INTERNAL_FREQ_FINE)).value))*150/100000 )/C_TEST_MODE_DRDY_SCALE_FACTOR * 1 ns;
            else
                wait for (C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL2_G)).value(7 downto 4))) - 
                          C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL2_G)).value(7 downto 4)))*
                          to_integer(signed(v_reg_map(f_idx2int(REG_INTERNAL_FREQ_FINE)).value))*150/100000 )* 1 ns;
            end if;
             
            
            if (s_DRDY_ena and (not s_GYRO_power_down_en)) then
                block_flag(C_GYRO_DRDY_BLOCK_FLAG, "blocking " & C_GYRO_DRDY_BLOCK_FLAG, WARNING, "ASM330 process GYRO_DRDY_generator");
                gen_pulse(s_gyro_internal_drdy, '1', 1 ns, NON_BLOCKING, "Pulsing s_temp_internal_drdy for 1 ns");
            end if;            

        end loop;
    end process;

    ACC_DRDY_generator : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_acc_internal_drdy <= '0';
        loop

            if not s_DRDY_ena or s_ACC_power_down_en then -- enable
                s_acc_internal_drdy <= '0';
                wait until s_DRDY_ena and (not s_ACC_power_down_en);
            end if;

            if (v_reg_map(f_idx2int(REG_CTRL1_XL)).value(7 downto 4)="0000") then
                wait until v_reg_map(f_idx2int(REG_CTRL1_XL)).value(7 downto 4)/="0000";
            end if;

            if (s_TEST_mode_ena) then
                wait for (C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL1_XL)).value(7 downto 4))) - 
                          C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL1_XL)).value(7 downto 4)))*
                          to_integer(signed(v_reg_map(f_idx2int(REG_INTERNAL_FREQ_FINE)).value))*150/100000 )/C_TEST_MODE_DRDY_SCALE_FACTOR * 1 ns; 
            else
                wait for (C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL1_XL)).value(7 downto 4))) - 
                          C_ORD_TIME_nS(to_integer(v_reg_map(f_idx2int(REG_CTRL1_XL)).value(7 downto 4))) *
                          to_integer(signed(v_reg_map(f_idx2int(REG_INTERNAL_FREQ_FINE)).value))*150/100000 ) * 1 ns; 
            end if;
            
            if (s_DRDY_ena and (not s_ACC_power_down_en)) then
                block_flag(C_ACC_DRDY_BLOCK_FLAG, "blocking " & C_ACC_DRDY_BLOCK_FLAG, WARNING, "ASM330 process ACC_DRDY_generator");
                gen_pulse(s_acc_internal_drdy, '1', 1 ns, NON_BLOCKING, "Pulsing s_temp_internal_drdy for 1 ns");
            end if;            

        end loop;
    end process;

    TEMP_DRDY_generator : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_temp_internal_drdy <= '0';
        wait for 0 ns; -- wait for clock_ena to be set
        loop

            if not (s_DRDY_ena and ((not s_ACC_power_down_en) or (not s_GYRO_power_down_en))) then -- enable
                s_temp_internal_drdy <= '0';
                wait until (s_DRDY_ena and ((not s_ACC_power_down_en) or (not s_GYRO_power_down_en)));
            end if;

            if (s_TEST_mode_ena) then
                wait for C_TEMP_TIME_nS/C_TEST_MODE_TEMP_DRDY_SCALE_FACTOR * 1 ns; 
            else
                wait for C_TEMP_TIME_nS* 1 ns;
            end if;
            
            if (s_DRDY_ena and ((not s_ACC_power_down_en) or (not s_GYRO_power_down_en))) then
                block_flag(C_TEMP_DRDY_BLOCK_FLAG, "blocking " & C_TEMP_DRDY_BLOCK_FLAG, WARNING, "ASM330 process TEMP_DRDY_generator");
                gen_pulse(s_temp_internal_drdy, '1', 1 ns, NON_BLOCKING, "Pulsing s_temp_internal_drdy for 1 ns");
            end if;            

        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- test vector mng
    --========================================================================================================================
    test_vector_mng : process 
        variable v_gyro_x_value_temp : signed(15 downto 0);
        variable v_gyro_y_value_temp : signed(15 downto 0);
        variable v_gyro_z_value_temp : signed(15 downto 0);
        variable v_acc_x_value_temp : signed(15 downto 0);
        variable v_acc_y_value_temp : signed(15 downto 0);
        variable v_acc_z_value_temp : signed(15 downto 0);
        variable v_fifo_byte_cnt : natural;
        variable v_fifo_WTM : unsigned(8 downto 0);
        variable v_temp_drdy_cnt : integer := 0;
        variable v_gyro_drdy_cnt : integer := 0;
        variable v_acc_drdy_cnt : integer := 0;
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        v_fifo_write_en := false;
        loop

            wait until ((s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') or 
                        (s_acc_internal_drdy'event and s_acc_internal_drdy='1') or 
                        (s_temp_internal_drdy'event and s_temp_internal_drdy='1'));

            v_fifo_byte_cnt :=  uvvm_fifo_get_count(s_fifo_idx)/8;

            v_fifo_WTM := v_reg_map(f_idx2int(REG_FIFO_CTRL_2)).value(0) & v_reg_map(f_idx2int(REG_FIFO_CTRL_1)).value;

            v_fifo_write_en := false;

            if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
                if (C_ORD_COUNT(to_integer(v_reg_map(f_idx2int(REG_FIFO_CTRL_3)).value(3 downto 0)))>0) then
                    if (v_acc_drdy_cnt=C_ORD_COUNT(to_integer(v_reg_map(f_idx2int(REG_FIFO_CTRL_3)).value(3 downto 0)))-1) then
                        v_fifo_write_en := true;
                        v_acc_drdy_cnt     := 0;
                    else
                        v_acc_drdy_cnt := v_acc_drdy_cnt+1;
                    end if;
                else
                    v_fifo_write_en := false;
                end if;                
            end if;

            if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                if (C_ORD_COUNT(to_integer(v_reg_map(f_idx2int(REG_FIFO_CTRL_3)).value(7 downto 4)))>0) then                
                    if (v_gyro_drdy_cnt=C_ORD_COUNT(to_integer(v_reg_map(f_idx2int(REG_FIFO_CTRL_3)).value(7 downto 4)))-1) then
                        v_fifo_write_en := true;
                        v_gyro_drdy_cnt     := 0;
                    else
                        v_gyro_drdy_cnt := v_gyro_drdy_cnt+1;
                    end if;
                else
                    v_fifo_write_en := false;
                end if;
            end if;
            
            if (s_temp_internal_drdy'event and s_temp_internal_drdy='1') then
                if (C_TEMP_ORD_COUNT(to_integer(v_reg_map(f_idx2int(REG_FIFO_CTRL_4)).value(5 downto 4)))>0) then
                    if (v_temp_drdy_cnt=C_TEMP_ORD_COUNT(to_integer(v_reg_map(f_idx2int(REG_FIFO_CTRL_4)).value(5 downto 4)))-1) then
                        v_fifo_write_en := true;
                        v_temp_drdy_cnt     := 0;
                    else
                        v_temp_drdy_cnt := v_temp_drdy_cnt+1;
                    end if;
                else
                    v_fifo_write_en := false;
                end if;                
            end if;

            if (v_reg_map(f_idx2int(REG_FIFO_CTRL_4)).value(2 downto 0)="000") then -- fifo disabled
                v_fifo_write_en := false;
            elsif (v_reg_map(f_idx2int(REG_FIFO_CTRL_4)).value(2 downto 0)="001") then -- fifo mode
                if (v_fifo_byte_cnt>=C_FIFO_BYTE_SIZE) then
                    v_fifo_write_en := false;
                end if;
            elsif (v_reg_map(f_idx2int(REG_FIFO_CTRL_4)).value(2 downto 0)="110") then -- fifo continuous mode
                if (v_reg_map(f_idx2int(REG_FIFO_CTRL_2)).value(7)='1') then
                    if (v_fifo_byte_cnt/7>=v_fifo_WTM) then
                        v_fifo_write_en := false;
                    end if;
                end if;
            else
                v_fifo_write_en := false;
            end if;
            

            if (s_temp_internal_drdy'event and s_temp_internal_drdy='1') then
                v_reg_map(f_idx2int(REG_OUT_TEMP_H)).value  := s_test_vector(v_temp_test_vector_idx).temp_value(15 downto 8);
                v_reg_map(f_idx2int(REG_OUT_TEMP_L)).value  := s_test_vector(v_temp_test_vector_idx).temp_value(7 downto 0);

                if (v_fifo_write_en) then
                    uvvm_fifo_put(s_fifo_idx, C_FIFO_TAG_SENSOR_TEMP);
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(s_test_vector(v_temp_test_vector_idx).temp_value(15 downto 8)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(s_test_vector(v_temp_test_vector_idx).temp_value(7 downto 0)));
                    uvvm_fifo_put(s_fifo_idx, x"00");
                    uvvm_fifo_put(s_fifo_idx, x"00");
                    uvvm_fifo_put(s_fifo_idx, x"00");
                    uvvm_fifo_put(s_fifo_idx, x"00");
                end if;                

                if (v_temp_test_vector_idx=s_test_vector_size) then
                    v_temp_test_vector_idx := 0;
                else
                    v_temp_test_vector_idx := v_temp_test_vector_idx+1;
                end if;

                asm330_update_fifo_status(v_reg_map, s_BDR_cnt, s_fifo_idx);

                unblock_flag(C_TEMP_DRDY_BLOCK_FLAG, "unblocking " & C_TEMP_DRDY_BLOCK_FLAG, global_trigger, "ASM330 process test_vector_mng");
            end if;

            if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                v_gyro_x_value_temp :=  signed(s_test_vector(v_gyro_test_vector_idx).gyro_x_value); 
                v_gyro_y_value_temp :=  signed(s_test_vector(v_gyro_test_vector_idx).gyro_y_value); 
                v_gyro_z_value_temp :=  signed(s_test_vector(v_gyro_test_vector_idx).gyro_z_value);

                v_reg_map(f_idx2int(REG_OUTX_H_G)).value := unsigned(v_gyro_x_value_temp(15 downto 8));
                v_reg_map(f_idx2int(REG_OUTX_L_G)).value := unsigned(v_gyro_x_value_temp(7 downto 0));
                v_reg_map(f_idx2int(REG_OUTY_H_G)).value := unsigned(v_gyro_y_value_temp(15 downto 8));
                v_reg_map(f_idx2int(REG_OUTY_L_G)).value := unsigned(v_gyro_y_value_temp(7 downto 0));
                v_reg_map(f_idx2int(REG_OUTZ_H_G)).value := unsigned(v_gyro_z_value_temp(15 downto 8));
                v_reg_map(f_idx2int(REG_OUTZ_L_G)).value := unsigned(v_gyro_z_value_temp(7 downto 0));

                if (v_fifo_write_en) then                
                    uvvm_fifo_put(s_fifo_idx, C_FIFO_TAG_SENSOR_GYRO);
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_gyro_x_value_temp(15 downto 8)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_gyro_x_value_temp(7 downto 0)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_gyro_y_value_temp(15 downto 8)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_gyro_y_value_temp(7 downto 0)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_gyro_z_value_temp(15 downto 8)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_gyro_z_value_temp(7 downto 0)));
                end if;

                if (v_gyro_test_vector_idx=s_test_vector_size) then
                    v_gyro_test_vector_idx := 0;
                else
                    v_gyro_test_vector_idx := v_gyro_test_vector_idx+1;
                end if;

                asm330_update_fifo_status(v_reg_map, s_BDR_cnt, s_fifo_idx);

                unblock_flag(C_GYRO_DRDY_BLOCK_FLAG, "unblocking " & C_GYRO_DRDY_BLOCK_FLAG, global_trigger, "ASM330 process test_vector_mng");
            end if;

            if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then 
                if (v_reg_map(f_idx2int(REG_CTRL7_G)).value(2)='1') then
                    v_acc_x_value_temp :=  signed(s_test_vector(v_acc_test_vector_idx).acc_x_value) + (signed(v_reg_map(f_idx2int(REG_X_OFS_USR)).value) ); 
                    v_acc_y_value_temp :=  signed(s_test_vector(v_acc_test_vector_idx).acc_y_value) + (signed(v_reg_map(f_idx2int(REG_Y_OFS_USR)).value) ); 
                    v_acc_z_value_temp :=  signed(s_test_vector(v_acc_test_vector_idx).acc_z_value) + (signed(v_reg_map(f_idx2int(REG_Z_OFS_USR)).value) ); 
                else
                    v_acc_x_value_temp :=  signed(s_test_vector(v_acc_test_vector_idx).acc_x_value); 
                    v_acc_y_value_temp :=  signed(s_test_vector(v_acc_test_vector_idx).acc_y_value); 
                    v_acc_z_value_temp :=  signed(s_test_vector(v_acc_test_vector_idx).acc_z_value); 
                end if;                               
    
                v_reg_map(f_idx2int(REG_OUTX_H_A)).value := unsigned(v_acc_x_value_temp(15 downto 8));
                v_reg_map(f_idx2int(REG_OUTX_L_A)).value := unsigned(v_acc_x_value_temp(7 downto 0));
                v_reg_map(f_idx2int(REG_OUTY_H_A)).value := unsigned(v_acc_y_value_temp(15 downto 8));
                v_reg_map(f_idx2int(REG_OUTY_L_A)).value := unsigned(v_acc_y_value_temp(7 downto 0));
                v_reg_map(f_idx2int(REG_OUTZ_H_A)).value := unsigned(v_acc_z_value_temp(15 downto 8));
                v_reg_map(f_idx2int(REG_OUTZ_L_A)).value := unsigned(v_acc_z_value_temp(7 downto 0));

                if (v_fifo_write_en) then
                    uvvm_fifo_put(s_fifo_idx, C_FIFO_TAG_SENSOR_ACC);
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_acc_x_value_temp(15 downto 8)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_acc_x_value_temp(7 downto 0)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_acc_y_value_temp(15 downto 8)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_acc_y_value_temp(7 downto 0)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_acc_z_value_temp(15 downto 8)));
                    uvvm_fifo_put(s_fifo_idx, std_logic_vector(v_acc_z_value_temp(7 downto 0)));
                end if;

                if (v_acc_test_vector_idx=s_test_vector_size) then
                    v_acc_test_vector_idx := 0;
                else
                    v_acc_test_vector_idx := v_acc_test_vector_idx+1;
                end if;

                asm330_update_fifo_status(v_reg_map, s_BDR_cnt, s_fifo_idx);

                unblock_flag(C_ACC_DRDY_BLOCK_FLAG, "unblocking " & C_ACC_DRDY_BLOCK_FLAG, global_trigger, "ASM330 process test_vector_mng");
            end if;



        end loop;
    end process;

    fifo_out_mng : process  
        variable v_fifo_byte_cnt : natural; 
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        v_reg_map(f_idx2int(REG_FIFO_STATUS1)).value := (others => '0');
        v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value := (others => '0');

        wait until ((s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') or 
                        (s_acc_internal_drdy'event and s_acc_internal_drdy='1') or 
                        (s_temp_internal_drdy'event and s_temp_internal_drdy='1'));

        if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
            await_unblock_flag(C_GYRO_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_GYRO_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
        end if;

        if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
            await_unblock_flag(C_ACC_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_ACC_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
        end if;

        if (s_temp_internal_drdy'event and s_temp_internal_drdy='1') then
            await_unblock_flag(C_TEMP_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_TEMP_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
        end if;

        if (v_fifo_write_en) then        
            asm330_update_fifo_status(v_reg_map, s_BDR_cnt, s_fifo_idx);
    
            v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_TAG)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
            v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_X_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
            v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_X_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
            v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Y_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
            v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Y_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
            v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Z_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
            v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Z_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));    
    
            loop
                wait until ((s_readed_reg'event and s_readed_reg = true and s_reg=REG_FIFO_DATA_OUT_Z_H));
                v_fifo_byte_cnt :=  uvvm_fifo_get_count(s_fifo_idx);
                
                block_flag(C_FIFO_STATUS_BLOCK_FLAG, "unblocking " & C_FIFO_STATUS_BLOCK_FLAG, WARNING, "ASM330 process fifo_out_mng");

                asm330_update_fifo_status(v_reg_map, s_BDR_cnt, s_fifo_idx);
                
                unblock_flag(C_FIFO_STATUS_BLOCK_FLAG, "unblocking " & C_FIFO_STATUS_BLOCK_FLAG, global_trigger, "ASM330 process fifo_out_mng");

                if (v_fifo_byte_cnt>=7*8) then                    
                    
                    v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_TAG)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                    v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_X_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                    v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_X_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                    v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Y_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                    v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Y_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                    v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Z_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                    v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Z_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));     
                else
                    wait until ((s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') or 
                            (s_acc_internal_drdy'event and s_acc_internal_drdy='1') or 
                            (s_temp_internal_drdy'event and s_temp_internal_drdy='1')); 
    
                    if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                        await_unblock_flag(C_GYRO_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_GYRO_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
                    end if;
            
                    if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
                        await_unblock_flag(C_ACC_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_ACC_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
                    end if;
            
                    if (s_temp_internal_drdy'event and s_temp_internal_drdy='1') then
                        await_unblock_flag(C_TEMP_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_TEMP_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_out_mng");
                    end if;
    
                    if (v_fifo_write_en) then
                        asm330_update_fifo_status(v_reg_map, s_BDR_cnt, s_fifo_idx);
        
                        v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_TAG)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                        v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_X_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                        v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_X_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                        v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Y_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                        v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Y_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                        v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Z_H)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));
                        v_reg_map(f_idx2int(REG_FIFO_DATA_OUT_Z_L)).value := unsigned(uvvm_fifo_get(s_fifo_idx,8));  
                    end if;                         
                end if;           
            end loop;
        end if;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- SW reset - REBOOT
    --========================================================================================================================
    sw_reset : process 
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_boot_in_progress  <= true;
        wait for 1 ns; -- wait for clock_ena to be set
        if (s_TEST_mode_ena) then
            wait for 10 us;
        else 
            wait for 10 ms;
        end if;
        s_boot_in_progress  <= false;
        loop
            wait until (s_wrote_reg'event and s_wrote_reg = true and s_reg=REG_CTRL3_C); 

            if (v_reg_map(f_idx2int(REG_CTRL3_C)).value(0)='1') then
                wait for 50 us;
                v_reg_map := C_ASM330_reg_map;
                wait for 100 us;
                v_reg_map(f_idx2int(REG_CTRL3_C)).value(0):='0';
            end if;

            if (v_reg_map(f_idx2int(REG_CTRL3_C)).value(7)='1') then
                s_boot_in_progress <= true;
                if (s_TEST_mode_ena) then
                    wait for 10 us;
                else 
                    wait for 10 ms;
                end if;
                
                s_boot_in_progress <= false;
                wait for 100 us;
                v_reg_map(f_idx2int(REG_CTRL3_C)).value(7):='0';
            end if;
            
        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- time stamp mng
    --========================================================================================================================
    time_stamp_int_mng : process 
        variable s_time_stamp : unsigned(31 downto 0);
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        v_reg_map(f_idx2int(REG_TIMESTAMP0_REG)).value := (others => '0');
        v_reg_map(f_idx2int(REG_TIMESTAMP1_REG)).value := (others => '0');
        v_reg_map(f_idx2int(REG_TIMESTAMP2_REG)).value := (others => '0');
        v_reg_map(f_idx2int(REG_TIMESTAMP3_REG)).value := (others => '0');
        loop
            wait until (s_wrote_reg'event and s_wrote_reg = true and v_reg_map(f_idx2int(REG_CTRL10_C)).value(5)='0') for 25 us; 

            if (v_reg_map(f_idx2int(REG_CTRL10_C)).value(5)='0') then
                s_time_stamp := (others => '0');
                v_reg_map(f_idx2int(REG_TIMESTAMP0_REG)).value := (others => '0');
                v_reg_map(f_idx2int(REG_TIMESTAMP1_REG)).value := (others => '0');
                v_reg_map(f_idx2int(REG_TIMESTAMP2_REG)).value := (others => '0');
                v_reg_map(f_idx2int(REG_TIMESTAMP3_REG)).value := (others => '0');
            else
                s_time_stamp := s_time_stamp +1;
                v_reg_map(f_idx2int(REG_TIMESTAMP0_REG)).value := s_time_stamp(7 downto 0);
                v_reg_map(f_idx2int(REG_TIMESTAMP1_REG)).value := s_time_stamp(15 downto 8);
                v_reg_map(f_idx2int(REG_TIMESTAMP2_REG)).value := s_time_stamp(23 downto 16);
                v_reg_map(f_idx2int(REG_TIMESTAMP3_REG)).value := s_time_stamp(31 downto 24);
            end if;
            
        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- status/fifo staus reg
    --========================================================================================================================
    status_reg : process 
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        v_reg_map(f_idx2int(REG_STATUS_REG)).value := (others => '0');
        loop
            wait until ((s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') or 
                        (s_acc_internal_drdy'event and s_acc_internal_drdy='1') or 
                        (s_temp_internal_drdy'event and s_temp_internal_drdy='1') or 
                        (s_readed_reg'event and s_readed_reg = true and s_reg=REG_FIFO_STATUS2) or
                        (s_readed_reg'event and s_readed_reg = true and s_reg=REG_OUT_TEMP_H) or
                        (s_readed_reg'event and s_readed_reg = true and s_reg=REG_OUTX_H_G) or
                        (s_readed_reg'event and s_readed_reg = true and s_reg=REG_OUTX_H_A) );

            if (s_temp_internal_drdy'event and s_temp_internal_drdy='1') then
                v_reg_map(f_idx2int(REG_STATUS_REG)).value(2) := '1';
            end if;

            if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                v_reg_map(f_idx2int(REG_STATUS_REG)).value(1) := '1';
            end if;

            if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
                v_reg_map(f_idx2int(REG_STATUS_REG)).value(0) := '1';
            end if;
            
            if (s_readed_reg'event and s_readed_reg = true and s_reg=REG_OUT_TEMP_H) then
                v_reg_map(f_idx2int(REG_STATUS_REG)).value(2) := '0';
            end if;

            if (s_readed_reg'event and s_readed_reg = true and s_reg=REG_OUTX_H_G) then
                v_reg_map(f_idx2int(REG_STATUS_REG)).value(1) := '0';
            end if;

            if (s_readed_reg'event and s_readed_reg = true and s_reg=REG_OUTX_H_A) then
                v_reg_map(f_idx2int(REG_STATUS_REG)).value(0) := '0';
            end if;

            if ((s_readed_reg'event and s_readed_reg = true and s_reg=REG_FIFO_STATUS2)) then
                v_reg_map(f_idx2int(REG_FIFO_STATUS2)).value(4) := '0';
            end if;  
            
        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- batching count
    --========================================================================================================================
    BDR_cnt : process 
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        s_BDR_cnt <= 0;
        loop
            wait until ((s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') or 
                        (s_acc_internal_drdy'event and s_acc_internal_drdy='1') or 
                        (s_wrote_reg'event and s_wrote_reg = true and s_reg=REG_COUNTER_BDR_REG1));

            if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                await_unblock_flag(C_GYRO_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_GYRO_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_status_reg");
            end if;

            if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
                await_unblock_flag(C_ACC_DRDY_BLOCK_FLAG, 0 ns, "waiting for " & C_ACC_DRDY_BLOCK_FLAG & " to be unblocked", KEEP_UNBLOCKED, WARNING, "ASM330 process fifo_status_reg");
            end if;

            if (v_reg_map(f_idx2int(REG_COUNTER_BDR_REG1)).value(5)='0') then
                if (s_acc_internal_drdy'event and s_acc_internal_drdy='1') then
                    s_BDR_cnt <= s_BDR_cnt+1;
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_COUNTER_BDR_REG1)).value(5)='1') then
                if (s_gyro_internal_drdy'event and s_gyro_internal_drdy='1') then
                    s_BDR_cnt <= s_BDR_cnt+1;
                end if;
            end if;

            if (v_reg_map(f_idx2int(REG_COUNTER_BDR_REG1)).value(6)='1') then                
                s_BDR_cnt <= 0;
                v_reg_map(f_idx2int(REG_COUNTER_BDR_REG1)).value(6) := '0';
            end if;
            
        end loop;
    end process;
    --========================================================================================================================


    --========================================================================================================================
    -- configuration check mng
    --========================================================================================================================
    configuration_check : process        
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            if not s_CONFIGURATION_CHECK_ena then -- enable
                wait until s_CONFIGURATION_CHECK_ena;
            end if;

            wait until ((s_wrote_reg'event and s_wrote_reg = true));

            if (s_GYRO_power_down_en) then
                for i in 0 to C_ASM330_REG_N-1 loop
                    if (v_reg_map(i).write) then 
                        if (s_reg_map_expected(i).value/=v_reg_map(i).value) then
                            error("ASM330 Error Configuration check detects a wrong register configuration", C_SCOPE);
                        end if;
                    end if;
                end loop;
            end if;
        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- spi_sequence check mng
    --========================================================================================================================
    spi_sequence_check : process        
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            if not s_SPI_SEQUENCE_CHECK_ena then -- enable
                wait until s_SPI_SEQUENCE_CHECK_ena;
            end if;

            wait until ((s_wrote_reg'event and s_wrote_reg = true) or (s_readed_reg'event and s_readed_reg = true) );

            if ((s_readed_reg'event and s_readed_reg = true)) then
                if (s_spi_cmd_seq_expect(s_seq_idx).reg=s_reg and
                    s_spi_cmd_seq_expect(s_seq_idx).read and
                    not s_spi_cmd_seq_expect(s_seq_idx).write) then

                    log(ID_BFM, "ASM330 SPI command sequence check step pass", C_SCOPE);
                else
                    error("ASM330 Error SPI sequence check", C_SCOPE);
                end if;
            end if;

            if ((s_wrote_reg'event and s_wrote_reg = true)) then
                if (s_spi_cmd_seq_expect(s_seq_idx).reg=s_reg and
                    s_spi_cmd_seq_expect(s_seq_idx).write and
                    not s_spi_cmd_seq_expect(s_seq_idx).read and
                    s_spi_cmd_seq_expect(s_seq_idx).value=v_reg_map(f_idx2int(s_reg)).value ) then
                    log(ID_BFM, "ASM330 SPI command sequence check step pass", C_SCOPE);                 
                else
                    error("ASM330 Error SPI sequence check", C_SCOPE);
                end if;
            end if;

            if (s_spi_cmd_seq_expect(s_seq_idx).next_cmd_seq_n<s_spi_cmd_seq_len) then
                s_seq_idx := s_spi_cmd_seq_expect(s_seq_idx).next_cmd_seq_n;
            else
                tb_error("ASM330 Command sequence check wrong expected sequence", C_SCOPE);
            end if;
            
        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- unsupported function
    --========================================================================================================================
    unsupported_function : process        
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            
            wait until ((s_wrote_reg'event and s_wrote_reg = true) );
			
            if  (s_wrote_reg'event and s_wrote_reg = true) then
                if (v_reg_map(f_idx2int(REG_MD2_CFG)).value/=C_ASM330_reg_map(f_idx2int(REG_MD2_CFG)).value  or
                    v_reg_map(f_idx2int(REG_MD1_CFG)).value/=C_ASM330_reg_map(f_idx2int(REG_MD1_CFG)).value  or
                    v_reg_map(f_idx2int(REG_FREE_FALL)).value/=C_ASM330_reg_map(f_idx2int(REG_FREE_FALL)).value or   
                    v_reg_map(f_idx2int(REG_WAKE_UP_DUR)).value/=C_ASM330_reg_map(f_idx2int(REG_WAKE_UP_DUR)).value or             
                    v_reg_map(f_idx2int(REG_WAKE_UP_THS)).value/=C_ASM330_reg_map(f_idx2int(REG_WAKE_UP_THS)).value or             
                    v_reg_map(f_idx2int(REG_THS_6D)).value/=C_ASM330_reg_map(f_idx2int(REG_THS_6D)).value or             
                    v_reg_map(f_idx2int(REG_INT_CFG1)).value/=C_ASM330_reg_map(f_idx2int(REG_INT_CFG1)).value or             
                    v_reg_map(f_idx2int(REG_INT_CFG0)).value/=C_ASM330_reg_map(f_idx2int(REG_INT_CFG0)).value or             
                    v_reg_map(f_idx2int(REG_D6D_SRC)).value/=C_ASM330_reg_map(f_idx2int(REG_D6D_SRC)).value or             
                    v_reg_map(f_idx2int(REG_WAKE_UP_SRC)).value/=C_ASM330_reg_map(f_idx2int(REG_WAKE_UP_SRC)).value or             
                    v_reg_map(f_idx2int(REG_ALL_INT_SRC)).value/=C_ASM330_reg_map(f_idx2int(REG_ALL_INT_SRC)).value or             
                    v_reg_map(f_idx2int(REG_CTRL3_C)).value(6 downto 1)/=C_ASM330_reg_map(f_idx2int(REG_CTRL3_C)).value(6 downto 1) or             
                    v_reg_map(f_idx2int(REG_CTRL5_C)).value/=C_ASM330_reg_map(f_idx2int(REG_CTRL5_C)).value          
                    ) then            
                    tb_error("ASM330 VCC unsupported function ", C_SCOPE);
                end if;
            end if;


            
        end loop;
    end process;
    --========================================================================================================================

end behave;
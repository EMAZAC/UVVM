--to do
-- timing error
-- SPI_TIMING_CHECK
-- UPDATE_REG_MAP

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.C_SB_CONFIG_DEFAULT;

use work.spi_bfm_pkg.all;
use work.gpio_bfm_pkg.all;
use work.adxl357_bfm_pkg.all;
use work.vvc_methods_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_vvc_framework_common_methods_pkg.all;
use work.td_target_support_pkg.all;
use work.td_vvc_entity_support_pkg.all;
use work.td_cmd_queue_pkg.all;
use work.td_result_queue_pkg.all;
use work.transaction_pkg.all;

--=================================================================================================
entity adxl357_vvc is
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
        DRDY       : inout std_logic;
        int1       : inout std_logic;
        int2       : inout std_logic
    );
end entity adxl357_vvc;

--=================================================================================================
--=================================================================================================

architecture behave of adxl357_vvc is

    constant C_SCOPE      : string       := C_VVC_NAME & "," & to_string(GC_INSTANCE_IDX);
    constant C_VVC_LABELS : t_vvc_labels := assign_vvc_labels(C_SCOPE, C_VVC_NAME, GC_INSTANCE_IDX, NA);

    signal executor_is_busy      : boolean := false;
    signal queue_is_increasing   : boolean := false;
    signal last_cmd_idx_executed : natural := 0;
    signal terminate_current_cmd : t_flag_record;

    -- Instantiation of the element dedicated Queue
    shared variable command_queue : work.td_cmd_queue_pkg.t_generic_queue;
    shared variable result_queue  : work.td_result_queue_pkg.t_generic_queue;


    alias vvc_config       : t_vvc_config is shared_adxl357_vvc_config(GC_INSTANCE_IDX);
    alias vvc_status       : t_vvc_status is shared_adxl357_vvc_status(GC_INSTANCE_IDX);
    alias transaction_info : t_transaction_info is shared_adxl357_transaction_info(GC_INSTANCE_IDX);
    -- Transaction info
    alias vvc_transaction_info_trigger : std_logic is global_adxl357_vvc_transaction_trigger(GC_INSTANCE_IDX);
    alias vvc_transaction_info         : t_transaction_group is shared_adxl357_vvc_transaction_info(GC_INSTANCE_IDX);
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
    signal s_internal_drdy          : std_logic;
    shared variable v_internal_int2 : std_logic;
    shared variable v_sync          : std_logic;
    signal s_DRDY_ena               : boolean           := false;
    signal s_SPI_ena                : boolean           := false;
    signal s_SPI_SEQUENCE_CHECK_ena  : boolean           := false;
    signal s_CONFIGURATION_CHECK_ena : boolean           := false;
    signal s_SPI_TIMING_CHECK_ena    : boolean           := false;
    shared variable  v_reg_map                : t_ADXL357_reg_map := C_ADXL357_reg_map;
    signal s_reg_map_expected                 : t_ADXL357_reg_map := C_ADXL357_reg_map;
    signal s_spi_cmd_seq_expect               : t_ADXL357_spi_cmd_seq(0 to C_VVC_CMD_MAX_SPI_CMD_SEQ_LENGTH-1);
    

    signal s_reg                    : e_ADXL357_RegisterNames;
    signal s_readed_reg             : boolean := false;
    signal s_wrote_reg              : boolean := false;  
    signal s_adxl357_power_down_en  : boolean := false;
    signal s_test_vector            : t_ADXL357_test_vectors(0 to C_VVC_CMD_MAX_TEST_VECTOR_LENGTH-1);
    signal s_test_vector_size       : integer :=0;
    signal s_spi_cmd_seq_len       : integer :=0;

    signal s_ext_clock_en           : boolean := false;
    signal s_int2_input_en          : boolean := false;
    signal s_int2_drdy_en           : boolean := false;
    signal s_DRDY_int_en            : boolean := false;

    signal s_clock_sel : std_logic;

    shared variable v_test_vector_idx : integer:=0;
    shared variable s_seq_idx : integer:=0;


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
        variable v_timestamp_start_of_current_bfm_access : time    := 0 ns;
        variable v_timestamp_start_of_last_bfm_access    : time    := 0 ns;
        variable v_timestamp_end_of_last_bfm_access      : time    := 0 ns;
        variable v_command_is_bfm_access                 : boolean := false;
        variable v_prev_command_was_bfm_access           : boolean := false;
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
        adxl357_VVC_SB.set_scope("ADXL357_VVC_SB");
        adxl357_VVC_SB.enable(GC_INSTANCE_IDX, "ADXL357 VVC SB Enabled");
        adxl357_VVC_SB.config(GC_INSTANCE_IDX, C_SB_CONFIG_DEFAULT);
        adxl357_VVC_SB.enable_log_msg(GC_INSTANCE_IDX, ID_DATA);

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

            -- Check if command is a BFM access
            v_prev_command_was_bfm_access := v_command_is_bfm_access; -- save for inter_bfm_delay
            if v_cmd.operation = SLAVE_TRANSMIT_AND_RECEIVE or v_cmd.operation = SLAVE_TRANSMIT_AND_CHECK or v_cmd.operation = SLAVE_TRANSMIT_ONLY or v_cmd.operation = SLAVE_RECEIVE_ONLY or v_cmd.operation = SLAVE_CHECK_ONLY then
                v_command_is_bfm_access := true;
            else
                v_command_is_bfm_access := false;
            end if;

            -- Insert delay if needed
            work.td_vvc_entity_support_pkg.insert_inter_bfm_delay_if_requested(vvc_config => vvc_config,
                command_is_bfm_access              => v_prev_command_was_bfm_access,
                timestamp_start_of_last_bfm_access => v_timestamp_start_of_last_bfm_access,
                timestamp_end_of_last_bfm_access   => v_timestamp_end_of_last_bfm_access,
                msg_id_panel                       => v_msg_id_panel,
                scope                              => C_SCOPE);
            if v_command_is_bfm_access then
                v_timestamp_start_of_current_bfm_access := now;
            end if;

            -- 2. Execute the fetched command
            -------------------------------------------------------------------------
            v_num_words                  := v_cmd.num_words;
            transaction_info.num_words   := v_cmd.num_words;
            transaction_info.word_length := GC_DATA_WIDTH;

            case v_cmd.operation is -- Only operations in the dedicated record are relevant

                -- VVC dedicated operations
                --===================================
                when SLAVE_TRANSMIT_AND_CHECK =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);

                    -- Call the corresponding procedure in the BFM package.
                    if v_num_words = 1 then
                        spi_slave_transmit_and_check(tx_data => v_cmd.data(0)(GC_DATA_WIDTH - 1 downto 0),
                            data_exp               => v_cmd.data_exp(0)(GC_DATA_WIDTH - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            alert_level            => v_cmd.alert_level,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                    else
                        -- normalize
                        v_normalized_data     := normalize_and_check(v_cmd.data, v_normalized_data, ALLOW_WIDER_NARROWER, "v_cmd.data", "v_normalized_data", "normalizing data to BFM");
                        v_normalized_data_exp := normalize_and_check(v_cmd.data_exp, v_normalized_data_exp, ALLOW_WIDER_NARROWER, "v_cmd.data_exp", "v_normalized_data_exp", "normalizing data_exp to BFM");

                        spi_slave_transmit_and_check(tx_data => v_normalized_data(v_num_words - 1 downto 0),
                            data_exp               => v_normalized_data_exp(v_num_words - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            alert_level            => v_cmd.alert_level,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                    end if;


                when SLAVE_TRANSMIT_ONLY =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);

                    -- Call the corresponding procedure in the BFM package.
                    if v_num_words = 1 then
                        spi_slave_transmit(tx_data => v_cmd.data(0)(GC_DATA_WIDTH - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                    else
                        -- normalize
                        v_normalized_data := normalize_and_check(v_cmd.data, v_normalized_data, ALLOW_WIDER_NARROWER, "v_cmd.data", "v_normalized_data", "normalizing data to BFM");

                        spi_slave_transmit(tx_data => v_normalized_data(v_num_words - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                    end if;

                when SLAVE_RECEIVE_ONLY =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);

                    -- Call the corresponding procedure in the BFM package.
                    if v_num_words = 1 then
                        spi_slave_receive(rx_data => v_result(0)(GC_DATA_WIDTH - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                    else
                        spi_slave_receive(rx_data => v_data_receive(v_num_words - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                        v_result := normalize_and_check(v_data_receive, v_result, ALLOW_WIDER_NARROWER, "v_data_receive", "v_result", "normalizing data to result");
                    end if;
                    -- Store the result
                    for i in 0 to v_num_words - 1 loop
                        -- Request SB check result
                        if v_cmd.data_routing = TO_SB then
                            -- call SB check_received
                            ADXL357_VVC_SB.check_received(GC_INSTANCE_IDX, pad_spi_sb(v_result(i)(GC_DATA_WIDTH - 1 downto 0)));
                        else
                            work.td_vvc_entity_support_pkg.store_result(result_queue => result_queue,
                                cmd_idx => v_cmd.cmd_idx,
                                result  => v_result(i));
                        end if;
                    end loop;


                when SLAVE_CHECK_ONLY =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);

                    -- Call the corresponding procedure in the BFM package.
                    if v_num_words = 1 then
                        spi_slave_check(data_exp => v_cmd.data_exp(0)(GC_DATA_WIDTH - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            alert_level            => v_cmd.alert_level,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                    else
                        -- normalize
                        v_normalized_data_exp := normalize_and_check(v_cmd.data_exp, v_normalized_data_exp, ALLOW_WIDER_NARROWER, "v_cmd.data_exp", "v_normalized_data_exp", "normalizing data_exp to BFM");

                        spi_slave_check(data_exp => v_normalized_data_exp(v_num_words - 1 downto 0),
                            msg                    => format_msg(v_cmd),
                            spi_if                 => spi_vvc_if,
                            alert_level            => v_cmd.alert_level,
                            when_to_start_transfer => v_cmd.when_to_start_transfer,
                            scope                  => C_SCOPE,
                            msg_id_panel           => v_msg_id_panel,
                            config                 => vvc_config.bfm_config);
                    end if;

                when ENABLE_FUNC =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    case v_cmd.functionality is
                        when NO_FUNC =>
                            null;
                        when SPI_MNG =>
                            if s_SPI_ena then
                                tb_error("ADXL357 SPI mng already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 SPI mng started", C_SCOPE);
                            end if;
                        when DRDY_MNG =>
                            if s_DRDY_ena then
                                tb_error("ADXL357 DRDY mng already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_DRDY_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 DRDY mng started", C_SCOPE);
                            end if;

                        when SPI_SEQUENCE_CHECK =>
                            if s_SPI_SEQUENCE_CHECK_ena then
                                tb_error("ADXL357 SPI SEQ CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_SEQUENCE_CHECK_ena <= true;
                                s_seq_idx := 0;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 SPI SEQ CHECK started", C_SCOPE);
                            end if;

                        when CONFIGURATION_CHECK =>
                            if s_CONFIGURATION_CHECK_ena then
                                tb_error("ADXL357 Configuration CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_CONFIGURATION_CHECK_ena <= true;
                                s_reg_map_expected <= v_cmd.reg_map;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 Configuration CHECK started", C_SCOPE);
                            end if;

                        when SPI_TIMING_CHECK =>
                            if s_SPI_TIMING_CHECK_ena then
                                tb_error("ADXL357 SPI timing CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_TIMING_CHECK_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 SPI timing CHECK started", C_SCOPE);
                            end if;

                        when OTHERS =>
                            tb_error("ADXL357 Enable functionality error, code error " & format_msg(v_cmd), C_SCOPE);
                    end case;

                when DISABLE_FUNC =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    case v_cmd.functionality is
                        when NO_FUNC =>
                            null;
                        when SPI_MNG =>
                            if not s_SPI_ena then
                                tb_error("ADXL357 SPI mng already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 SPI mng disabled", C_SCOPE);
                            end if;
                        when DRDY_MNG =>
                            if not s_DRDY_ena then
                                tb_error("ADXL357 DRDY mng already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_DRDY_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 DRDY mng disabled", C_SCOPE);
                            end if;

                        when SPI_SEQUENCE_CHECK =>
                            if not s_SPI_SEQUENCE_CHECK_ena then
                                tb_error("ADXL357 SPI SEQ CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_SEQUENCE_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 SPI SEQ CHECK disabled", C_SCOPE);
                            end if;

                        when CONFIGURATION_CHECK =>
                            if not s_CONFIGURATION_CHECK_ena then
                                tb_error("ADXL357 Configuration CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_CONFIGURATION_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 Configuration CHECK disabled", C_SCOPE);
                            end if;

                        when SPI_TIMING_CHECK =>
                            if not s_SPI_TIMING_CHECK_ena then
                                tb_error("ADXL357 SPI timing CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_TIMING_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "ADXL357 SPI timing CHECK disabled", C_SCOPE);
                            end if;
                        when OTHERS =>
                            tb_error("ADXL357 Disable functionality error, code error " & format_msg(v_cmd), C_SCOPE);
                    end case;

                when SET_TEST_VECTOR =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    s_test_vector <= v_cmd.test_vectors;
                    s_test_vector_size <= v_cmd.test_vectors_len-1;  
                    v_test_vector_idx := 0;     
                    log(ID_BFM, "ADXL357 test vector updated", C_SCOPE);  

                when SET_SPI_SEQ =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    s_spi_cmd_seq_expect  <= v_cmd.spi_cmd_seq;
                    s_spi_cmd_seq_len <= v_cmd.spi_cmd_seq_len;
                    s_seq_idx := 0;    
                    log(ID_BFM, "ADXL357 test vector updated", C_SCOPE);
                               
                when UPDATE_REG_MAP =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    v_reg_map  := v_cmd.reg_map;
                    if (v_reg_map(f_idx2int(REG_ACT_EN)).value/=C_ADXL357_reg_map(f_idx2int(REG_ACT_EN)).value  or
                        v_reg_map(f_idx2int(REG_INT_MAP)).value/=C_ADXL357_reg_map(f_idx2int(REG_INT_MAP)).value  or
                        v_reg_map(f_idx2int(REG_SELF_TEST)).value/=C_ADXL357_reg_map(f_idx2int(REG_SELF_TEST)).value                
                        ) then            
                        tb_error("ADXL357 VCC unsupported function ", C_SCOPE);
                    end if;
                    log(ID_BFM, "ADXL357 register map updated", C_SCOPE);
                               

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

            if v_command_is_bfm_access then
                v_timestamp_end_of_last_bfm_access   := now;
                v_timestamp_start_of_last_bfm_access := v_timestamp_start_of_current_bfm_access;
                if ((vvc_config.inter_bfm_delay.delay_type = TIME_START2START) and ((now - v_timestamp_start_of_current_bfm_access) > vvc_config.inter_bfm_delay.delay_in_time)) then
                    alert(vvc_config.inter_bfm_delay.inter_bfm_delay_violation_severity, "BFM access exceeded specified start-to-start inter-bfm delay, " & to_string(vvc_config.inter_bfm_delay.delay_in_time) & ".", C_SCOPE);
                end if;
            end if;

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
    -- Clock Generator process
    -- - Process that generates the clock internal signal
    --========================================================================================================================
    clock_generator : process
        variable v_clock_period    : time := 976.5625 ns;      -- 1.024 MHz
        variable v_clock_high_time : time := v_clock_period/2; -- 50% duty
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            s_internal_clk <= '1';
            wait for v_clock_high_time;
            s_internal_clk <= '0';
            wait for (v_clock_period - v_clock_high_time);
        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- SPI management process
    -- - Process that generates the clock internal signal
    --========================================================================================================================
    spi_mng : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            if not s_SPI_ena then
                wait until s_SPI_ena;
            end if;

            ADXL357_SPI_mng(spi_vvc_if,true,v_reg_map,s_reg, s_readed_reg, s_wrote_reg,vvc_config.bfm_config);


        end loop;
    end process;

    reg_map_app : process
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            if not s_SPI_ena then
                wait until s_SPI_ena;
            end if;

            wait until ((s_wrote_reg'event and s_wrote_reg = true));

            s_adxl357_power_down_en <= true when (v_reg_map(f_idx2int(REG_POWER_CTL)).value(2)='1' or v_reg_map(f_idx2int(REG_POWER_CTL)).value(0)='1') else false;
            if (v_reg_map(f_idx2int(REG_SYNC)).value(2)='1') then
                s_ext_clock_en <= true;
            else
                s_ext_clock_en <= false;
            end if;
            if (v_reg_map(f_idx2int(REG_SYNC)).value(2)='1') then
                s_int2_input_en <= true;
            elsif (v_reg_map(f_idx2int(REG_SYNC)).value(2)='0' and (v_reg_map(f_idx2int(REG_SYNC)).value(1 downto 0)="01" or v_reg_map(f_idx2int(REG_SYNC)).value(1 downto 0)="11") and v_reg_map(f_idx2int(REG_INT_MAP)).value(7 downto 4)="0000") then
                s_int2_drdy_en <= true;
            else
                s_int2_input_en <= false;
                s_int2_drdy_en <= false;
            end if;
            if (v_reg_map(f_idx2int(REG_SYNC)).value(1 downto 0)="00") then
                s_DRDY_int_en <= true;
            else
                s_DRDY_int_en <= false;
            end if;

        end loop;
    end process;
    --========================================================================================================================

    
    s_clock_sel <= int2 when (s_ext_clock_en) else s_internal_clk;

    int2 <= 'Z' when (s_int2_input_en) else
        s_internal_drdy when (s_int2_drdy_en) else
        v_internal_int2;

    DRDY <= s_internal_drdy when s_DRDY_int_en else 'Z';

    --========================================================================================================================
    -- DRDY Generator process
    -- - Process that generates the DRDY signal
    --========================================================================================================================
    DRDY_generator : process
        constant C_clock_div : integer := 256;
        variable v_clock_cnt : integer := 0;
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop

            if not s_DRDY_ena or s_adxl357_power_down_en then -- enable
                s_internal_drdy <= '0';
                wait until s_DRDY_ena and not s_adxl357_power_down_en;
            end if;

            wait until ((s_clock_sel'event and s_clock_sel = '1') or (s_readed_reg'event and s_readed_reg = true));

            if (s_clock_sel'event and s_clock_sel = '1') then
                case (v_reg_map(f_idx2int(REG_SYNC)).value(1 downto 0)) is
                    when "00" => --internal sync              
                        v_clock_cnt := v_clock_cnt+1;
                        if (v_clock_cnt=C_clock_div*(to_integer(v_reg_map(f_idx2int(REG_FILTER)).value(3 downto 0))+1)-1) then
                            s_internal_drdy <= '1';
                            v_clock_cnt     := 0;
                        end if;

                    when "01" => --external sync interpolation
                        if (DRDY = '1') then
                            v_clock_cnt := 0;
                        end if;
                        if (v_clock_cnt<C_SYNC_2_DRDY(to_integer(v_reg_map(f_idx2int(REG_FILTER)).value(3 downto 0)))) then
                            v_clock_cnt := v_clock_cnt+1;
                        end if;
                        if (v_clock_cnt=C_SYNC_2_DRDY(to_integer(v_reg_map(f_idx2int(REG_FILTER)).value(3 downto 0)))) then
                            s_internal_drdy <= '1';
                        end if;

                    when "10" => --external sync no interpolation
                        if (DRDY = '1') then
                            v_clock_cnt := 0;
                        end if;
                        v_clock_cnt := v_clock_cnt+1;
                        if (v_clock_cnt=C_clock_div*(to_integer(v_reg_map(f_idx2int(REG_FILTER)).value(3 downto 0))+1)-1) then
                            s_internal_drdy <= '1';
                            v_clock_cnt     := 0;
                        end if;

                    when others =>
                        error("ADXL357 Error DataReady management detects a wrong register configuration", C_SCOPE);
                end case;

                if (v_clock_cnt=C_clock_div*(to_integer(v_reg_map(f_idx2int(REG_FILTER)).value(3 downto 0))+1)/2-1 ) then
                    if (s_internal_drdy='1' ) then
                        s_internal_drdy <= '0';
                    end if;
                end if;
            end if;

            if (s_readed_reg'event and s_readed_reg = true) then
                if (s_reg=REG_XDATA3 or s_reg=REG_XDATA2 or s_reg=REG_XDATA1 or s_reg=REG_YDATA3 or s_reg=REG_YDATA2 or s_reg=REG_YDATA1 or s_reg=REG_ZDATA3 or s_reg=REG_ZDATA2 or s_reg=REG_ZDATA1 or s_reg=REG_FIFO_DATA) then
                    if (s_internal_drdy='1' ) then
                        s_internal_drdy <= '0';
                    end if;
                end if;
            end if;

        end loop;
    end process;
    --========================================================================================================================

    --========================================================================================================================
    -- test vector mng
    --========================================================================================================================
    test_vector_mng : process 
        variable v_x_value_temp : signed(23 downto 0);
        variable v_y_value_temp : signed(23 downto 0);
        variable v_z_value_temp : signed(23 downto 0);
    begin
        wait for 0 ns; -- wait for clock_ena to be set
        loop
            wait until (s_internal_drdy'event and s_internal_drdy='1');

            if (v_reg_map(f_idx2int(REG_POWER_CTL)).value(1)='0') then
                v_reg_map(f_idx2int(REG_TEMP2)).value  := s_test_vector(v_test_vector_idx).temp_value(15 downto 8);
                v_reg_map(f_idx2int(REG_TEMP1)).value  := s_test_vector(v_test_vector_idx).temp_value(7 downto 0);
            else
                v_reg_map(f_idx2int(REG_TEMP2)).value  := x"00";
                v_reg_map(f_idx2int(REG_TEMP1)).value  := x"00";
            end if;

            --v_x_value_temp := signed(s_test_vector(v_test_vector_idx).x_value) + signed(v_reg_map(f_idx2int(REG_OFFSET_X_H)).value & v_reg_map(f_idx2int(REG_OFFSET_X_L)).value & "0000"); 
            --v_y_value_temp := signed(s_test_vector(v_test_vector_idx).y_value) + signed(v_reg_map(f_idx2int(REG_OFFSET_Y_H)).value & v_reg_map(f_idx2int(REG_OFFSET_Y_L)).value & "0000"); 
            --v_z_value_temp := signed(s_test_vector(v_test_vector_idx).z_value) + signed(v_reg_map(f_idx2int(REG_OFFSET_Z_H)).value & v_reg_map(f_idx2int(REG_OFFSET_Z_L)).value & "0000"); 
            v_x_value_temp :=  signed(s_test_vector(v_test_vector_idx).x_value) + (signed(v_reg_map(f_idx2int(REG_OFFSET_X_H)).value) & signed(v_reg_map(f_idx2int(REG_OFFSET_X_L)).value) & "0000"); 
            v_y_value_temp :=  signed(s_test_vector(v_test_vector_idx).y_value) + (signed(v_reg_map(f_idx2int(REG_OFFSET_Y_H)).value) & signed(v_reg_map(f_idx2int(REG_OFFSET_Y_L)).value) & "0000"); 
            v_z_value_temp :=  signed(s_test_vector(v_test_vector_idx).z_value) + (signed(v_reg_map(f_idx2int(REG_OFFSET_Z_H)).value) & signed(v_reg_map(f_idx2int(REG_OFFSET_Z_L)).value) & "0000"); 
            
            v_reg_map(f_idx2int(REG_XDATA3)).value := unsigned(v_x_value_temp(23 downto 16));
            v_reg_map(f_idx2int(REG_XDATA2)).value := unsigned(v_x_value_temp(15 downto 8));
            v_reg_map(f_idx2int(REG_XDATA1)).value := unsigned(v_x_value_temp(7 downto 0));
            v_reg_map(f_idx2int(REG_YDATA3)).value := unsigned(v_y_value_temp(23 downto 16));
            v_reg_map(f_idx2int(REG_YDATA2)).value := unsigned(v_y_value_temp(15 downto 8));
            v_reg_map(f_idx2int(REG_YDATA1)).value := unsigned(v_y_value_temp(7 downto 0));
            v_reg_map(f_idx2int(REG_ZDATA3)).value := unsigned(v_z_value_temp(23 downto 16));
            v_reg_map(f_idx2int(REG_ZDATA2)).value := unsigned(v_z_value_temp(15 downto 8));
            v_reg_map(f_idx2int(REG_ZDATA1)).value := unsigned(v_z_value_temp(7 downto 0));

            if (v_test_vector_idx=s_test_vector_size) then
                v_test_vector_idx := 0;
            else
                v_test_vector_idx := v_test_vector_idx+1;
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

            if (s_adxl357_power_down_en) then
                for i in 0 to C_ADXL357_REG_N-1 loop
                    if (v_reg_map(i).write) then 
                        if (s_reg_map_expected(i).value/=v_reg_map(i).value) then
                            error("ADXL357 Error Configuration check detects a wrong register configuration", C_SCOPE);
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

                    log(ID_BFM, "ADXL357 SPI command sequence check step pass", C_SCOPE);
                else
                    error("ADXL357 Error SPI sequence check", C_SCOPE);
                end if;
            end if;

            if ((s_wrote_reg'event and s_wrote_reg = true)) then
                if (s_spi_cmd_seq_expect(s_seq_idx).reg=s_reg and
                    s_spi_cmd_seq_expect(s_seq_idx).write and
                    not s_spi_cmd_seq_expect(s_seq_idx).read and
                    s_spi_cmd_seq_expect(s_seq_idx).value=v_reg_map(f_idx2int(s_reg)).value ) then
                    log(ID_BFM, "ADXL357 SPI command sequence check step pass", C_SCOPE);                 
                else
                    error("ADXL357 Error SPI sequence check", C_SCOPE);
                end if;
            end if;

            if (s_spi_cmd_seq_expect(s_seq_idx).next_cmd_seq_n<s_spi_cmd_seq_len) then
                s_seq_idx := s_spi_cmd_seq_expect(s_seq_idx).next_cmd_seq_n;
            else
                tb_error("ADXL357 Command sequence check wrong expected sequence", C_SCOPE);
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
            
            wait until ((s_adxl357_power_down_en'event and s_adxl357_power_down_en = true) or (s_wrote_reg'event and s_wrote_reg = true) or 
                (s_readed_reg'event and s_readed_reg = true) );
			
            if ((s_adxl357_power_down_en'event and s_adxl357_power_down_en = true) or (s_wrote_reg'event and s_wrote_reg = true) )then
                if (v_reg_map(f_idx2int(REG_ACT_EN)).value/=C_ADXL357_reg_map(f_idx2int(REG_ACT_EN)).value  or
                    v_reg_map(f_idx2int(REG_INT_MAP)).value/=C_ADXL357_reg_map(f_idx2int(REG_INT_MAP)).value  or
                    v_reg_map(f_idx2int(REG_SELF_TEST)).value/=C_ADXL357_reg_map(f_idx2int(REG_SELF_TEST)).value                
                    ) then            
                    tb_error("ADXL357 VCC unsupported function ", C_SCOPE);
                end if;
            end if;

            if ((s_readed_reg'event and s_readed_reg = true)) then
                if (s_reg=REG_FIFO_DATA) then
                    tb_error("ADXL357 VCC unsupported function ", C_SCOPE);
                end if;
            end if;
            
        end loop;
    end process;
    --========================================================================================================================

end behave;
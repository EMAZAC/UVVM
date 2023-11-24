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

library bitvis_vip_spi;
use bitvis_vip_spi.spi_bfm_pkg.all; 

use work.P90_bfm_pkg.all;
use work.vvc_methods_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_vvc_framework_common_methods_pkg.all;
use work.td_target_support_pkg.all;
use work.td_vvc_entity_support_pkg.all;
use work.td_cmd_queue_pkg.all;
use work.td_result_queue_pkg.all;
use work.transaction_pkg.all;

--=================================================================================================
entity P90_vvc is
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
        PRESS      : out std_logic :='0';
        TEMP       : out std_logic :='0'
    );
end entity P90_vvc;

--=================================================================================================
--=================================================================================================

architecture behave of P90_vvc is

    constant C_SCOPE      : string       := C_VVC_NAME & "," & to_string(GC_INSTANCE_IDX);
    constant C_VVC_LABELS : t_vvc_labels := assign_vvc_labels(C_SCOPE, C_VVC_NAME, GC_INSTANCE_IDX, NA);


    signal executor_is_busy      : boolean := false;
    signal queue_is_increasing   : boolean := false;
    signal last_cmd_idx_executed : natural := 0;
    signal terminate_current_cmd : t_flag_record;

    -- Instantiation of the element dedicated Queue
    shared variable command_queue : work.td_cmd_queue_pkg.t_generic_queue;
    shared variable result_queue  : work.td_result_queue_pkg.t_generic_queue;


    alias vvc_config       : t_vvc_config is shared_P90_vvc_config(GC_INSTANCE_IDX);
    alias vvc_status       : t_vvc_status is shared_P90_vvc_status(GC_INSTANCE_IDX);
    alias transaction_info : t_transaction_info is shared_P90_transaction_info(GC_INSTANCE_IDX);
    -- Transaction info
    alias vvc_transaction_info_trigger : std_logic is global_P90_vvc_transaction_trigger(GC_INSTANCE_IDX);
    alias vvc_transaction_info         : t_transaction_group is shared_P90_vvc_transaction_info(GC_INSTANCE_IDX);
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


    signal s_SPI_ena                : boolean           := false;
    signal s_TEST_mode_ena          : boolean           := false;
    signal s_SPI_SEQUENCE_CHECK_ena : boolean           := false;
    signal s_SPI_TIMING_CHECK_ena   : boolean           := false;
    shared variable  v_reg_map      : t_P90_reg_map := C_P90_reg_map;
    signal s_spi_cmd_seq_expect     : t_P90_spi_cmd_seq(0 to C_VVC_CMD_MAX_SPI_CMD_SEQ_LENGTH-1);
    signal s_reg                    : e_P90_RegisterNames;
    signal s_readed_reg             : boolean := false;
    signal s_wrote_reg              : boolean := false;  
    signal s_test_vector            : t_P90_test_vectors(0 to C_VVC_CMD_MAX_TEST_VECTOR_LENGTH-1);
    signal s_test_vector_size       : integer :=0;
    signal s_spi_cmd_seq_len        : integer :=0;
    shared variable s_seq_idx       : integer:=0;
    signal PRESS_ena                : boolean := false;
    signal TEMP_ena                 : boolean := false;

    constant press_name      : string := "PRESS";
    alias press_period       : time is vvc_config.press_period;
    alias press_high_time    : time is vvc_config.press_high_time;
    constant TEMP_name      : string := "TEMP";
    alias TEMP_period       : time is vvc_config.TEMP_period;
    alias TEMP_high_time    : time is vvc_config.TEMP_high_time;


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
        P90_VVC_SB.set_scope("P90_VVC_SB");
        P90_VVC_SB.enable(GC_INSTANCE_IDX, "P90 VVC SB Enabled");
        P90_VVC_SB.config(GC_INSTANCE_IDX, C_SB_CONFIG_DEFAULT);
        P90_VVC_SB.enable_log_msg(GC_INSTANCE_IDX, ID_DATA);

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

                when START_PRESS =>
                    if PRESS_ena then
                      tb_error("Signal " & PRESS_name & " already running. " & format_msg(v_cmd), C_SCOPE);
                    else
                      PRESS_ena <= true;
                      wait for 0 ns;
                      log(ID_CLOCK_GEN, "Signal '" & PRESS_name & "' started", C_SCOPE);
                    end if;
        
                when STOP_PRESS =>
                    if not PRESS_ena then
                      tb_error("Signal '" & PRESS_name & "' already stopped. " & format_msg(v_cmd), C_SCOPE);
                    else
                      PRESS_ena <= false;
                      if PRESS then
                        wait until not PRESS;
                      end if;
                      log(ID_CLOCK_GEN, "Signal '" & PRESS_name & "' stopped", C_SCOPE);
                    end if;
        
                when SET_PRESS_PERIOD =>
                    PRESS_period := v_cmd.PRESS_period;
                    log(ID_CLOCK_GEN, "Signal '" & PRESS_name & "' period set to " & to_string(PRESS_period), C_SCOPE);
        
                when SET_PRESS_HIGH_TIME =>
                    PRESS_high_time := v_cmd.PRESS_high_time;
                    log(ID_CLOCK_GEN, "Signal '" & PRESS_name & "' high time set to " & to_string(PRESS_high_time), C_SCOPE);

                when START_TEMP =>
                    if TEMP_ena then
                      tb_error("Signal " & TEMP_name & " already running. " & format_msg(v_cmd), C_SCOPE);
                    else
                      TEMP_ena <= true;
                      wait for 0 ns;
                      log(ID_CLOCK_GEN, "Signal '" & TEMP_name & "' started", C_SCOPE);
                    end if;
        
                when STOP_TEMP =>
                    if not TEMP_ena then
                      tb_error("Signal '" & TEMP_name & "' already stopped. " & format_msg(v_cmd), C_SCOPE);
                    else
                      TEMP_ena <= false;
                      if TEMP then
                        wait until not TEMP;
                      end if;
                      log(ID_CLOCK_GEN, "Signal '" & TEMP_name & "' stopped", C_SCOPE);
                    end if;
        
                when SET_TEMP_PERIOD =>
                    TEMP_period := v_cmd.TEMP_period;
                    log(ID_CLOCK_GEN, "Signal '" & TEMP_name & "' period set to " & to_string(TEMP_period), C_SCOPE);
        
                when SET_TEMP_HIGH_TIME =>
                    TEMP_high_time := v_cmd.TEMP_high_time;
                    log(ID_CLOCK_GEN, "Signal '" & TEMP_name & "' high time set to " & to_string(TEMP_high_time), C_SCOPE);

                when ENABLE_FUNC =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    case v_cmd.functionality is
                        when NO_FUNC =>
                            null;

                        when SPI_MNG =>
                            if s_SPI_ena then
                                tb_error("P90 SPI mng already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "P90 SPI mng started", C_SCOPE);
                            end if;

                        when SPI_SEQUENCE_CHECK =>
                            if s_SPI_SEQUENCE_CHECK_ena then
                                tb_error("P90 SPI SEQ CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_SEQUENCE_CHECK_ena <= true;
                                s_seq_idx := 0;
                                wait for 0 ns;
                                log(ID_BFM, "P90 SPI SEQ CHECK started", C_SCOPE);
                            end if;

                        when SPI_TIMING_CHECK =>
                            if s_SPI_TIMING_CHECK_ena then
                                tb_error("P90 SPI timing CHECK already running. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_TIMING_CHECK_ena <= true;
                                wait for 0 ns;
                                log(ID_BFM, "P90 SPI timing CHECK started", C_SCOPE);
                            end if;

                        when OTHERS =>
                            tb_error("P90 Enable functionality error, code error " & format_msg(v_cmd), C_SCOPE);
                    end case;

                when DISABLE_FUNC =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    case v_cmd.functionality is
                        when NO_FUNC =>
                            null;

                        when SPI_MNG =>
                            if not s_SPI_ena then
                                tb_error("P90 SPI mng already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "P90 SPI mng disabled", C_SCOPE);
                            end if;

                        when SPI_SEQUENCE_CHECK =>
                            if not s_SPI_SEQUENCE_CHECK_ena then
                                tb_error("P90 SPI SEQ CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_SEQUENCE_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "P90 SPI SEQ CHECK disabled", C_SCOPE);
                            end if;

                        when SPI_TIMING_CHECK =>
                            if not s_SPI_TIMING_CHECK_ena then
                                tb_error("P90 SPI timing CHECK already disabled. " & format_msg(v_cmd), C_SCOPE);
                            else
                                s_SPI_TIMING_CHECK_ena <= false;
                                wait for 0 ns;
                                log(ID_BFM, "P90 SPI timing CHECK disabled", C_SCOPE);
                            end if;

                        when OTHERS =>
                            tb_error("P90 Disable functionality error, code error " & format_msg(v_cmd), C_SCOPE);
                    end case;

                when SET_TEST_VECTOR =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    s_test_vector <= v_cmd.test_vectors;
                    s_test_vector_size <= v_cmd.test_vectors_len-1;    
                    log(ID_BFM, "P90 test vector updated", C_SCOPE);  

                when SET_SPI_SEQ =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    s_spi_cmd_seq_expect  <= v_cmd.spi_cmd_seq;
                    s_spi_cmd_seq_len <= v_cmd.spi_cmd_seq_len;
                    s_seq_idx := 0;    
                    log(ID_BFM, "P90 test vector updated", C_SCOPE);
                               
                when UPDATE_REG_MAP =>
                    -- Set vvc transaction info
                    set_global_vvc_transaction_info(vvc_transaction_info_trigger, vvc_transaction_info, v_cmd, vvc_config);
                    v_reg_map  := v_cmd.reg_map;
                    log(ID_BFM, "P90 register map updated", C_SCOPE);
                               

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
            if not s_SPI_ena then
                wait until s_SPI_ena;
            end if;

            P90_SPI_mng(spi_vvc_if,true,v_reg_map,s_reg, s_readed_reg, s_wrote_reg,vvc_config.bfm_config);

        end loop;
    end process;


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
            error("P90 Error unsupported functionality", C_SCOPE);

            wait until ((s_wrote_reg'event and s_wrote_reg = true) or (s_readed_reg'event and s_readed_reg = true) );

            if ((s_readed_reg'event and s_readed_reg = true)) then
                if (s_spi_cmd_seq_expect(s_seq_idx).reg=s_reg and
                    s_spi_cmd_seq_expect(s_seq_idx).read and
                    not s_spi_cmd_seq_expect(s_seq_idx).write) then

                    log(ID_BFM, "P90 SPI command sequence check step pass", C_SCOPE);
                else
                    error("P90 Error SPI sequence check", C_SCOPE);
                end if;
            end if;

            if ((s_wrote_reg'event and s_wrote_reg = true)) then
                if (s_spi_cmd_seq_expect(s_seq_idx).reg=s_reg and
                    s_spi_cmd_seq_expect(s_seq_idx).write and
                    not s_spi_cmd_seq_expect(s_seq_idx).read and
                    s_spi_cmd_seq_expect(s_seq_idx).value=v_reg_map(f_idx2int(s_reg)).value ) then
                    log(ID_BFM, "P90 SPI command sequence check step pass", C_SCOPE);                 
                else
                    error("P90 Error SPI sequence check", C_SCOPE);
                end if;
            end if;

            if (s_spi_cmd_seq_expect(s_seq_idx).next_cmd_seq_n<s_spi_cmd_seq_len) then
                s_seq_idx := s_spi_cmd_seq_expect(s_seq_idx).next_cmd_seq_n;
            else
                tb_error("P90 Command sequence check wrong expected sequence", C_SCOPE);
            end if;
            
        end loop;
    end process;
    --========================================================================================================================


  --========================================================================================================================
  -- PRESS Generator process
  -- - Process that generates the clock signal
  --========================================================================================================================
  PRESS_generator : process
    variable v_press_period    : time;
    variable v_press_high_time : time;
  begin
    wait for 0 ns;                      -- wait for PRESS_ena to be set
    loop

      if not PRESS_ena then
        PRESS <= '0';
        wait until PRESS_ena;
      end if;

      -- PRESS period is sampled so it won't change during a clock cycle and potentialy introduce negative time in
      -- last wait statement
      v_press_period    := press_period;
      v_press_high_time := press_high_time;

      if v_press_high_time >= v_press_period then
        tb_error(press_name & ": press period must be larger than press high time; clock period: " & to_string(v_press_period) & ", press high time: " & to_string(press_high_time), C_SCOPE);
      end if;

      PRESS <= '1';
      wait for v_press_high_time;
      PRESS <= '0';
      wait for (v_press_period - v_press_high_time);
    end loop;
  end process;
  --========================================================================================================================

  --========================================================================================================================
  -- TEMP Generator process
  -- - Process that generates the clock signal
  --========================================================================================================================
  TEMP_generator : process
    variable v_TEMP_period    : time;
    variable v_TEMP_high_time : time;
  begin
    wait for 0 ns;                      -- wait for TEMP_ena to be set
    loop

      if not TEMP_ena then
        TEMP <= '0';
        wait until TEMP_ena;
      end if;

      -- TEMP period is sampled so it won't change during a clock cycle and potentialy introduce negative time in
      -- last wait statement
      v_TEMP_period    := TEMP_period;
      v_TEMP_high_time := TEMP_high_time;

      if v_TEMP_high_time >= v_TEMP_period then
        tb_error(TEMP_name & ": TEMP period must be larger than TEMP high time; clock period: " & to_string(v_TEMP_period) & ", TEMP high time: " & to_string(TEMP_high_time), C_SCOPE);
      end if;

      TEMP <= '1';
      wait for v_TEMP_high_time;
      TEMP <= '0';
      wait for (v_TEMP_period - v_TEMP_high_time);
    end loop;
  end process;
  --========================================================================================================================


end behave;
--==========================================================================================
-- This VVC was generated with Bitvis VVC Generator
--==========================================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library cns_vip_adxl357;
use cns_vip_adxl357.spi_bfm_pkg.all;
use cns_vip_adxl357.gpio_bfm_pkg.all;

--==========================================================================================
--==========================================================================================
package adxl357_bfm_pkg is

    --==========================================================================================
    -- Types and constants for ADXL357 BFM 
    --==========================================================================================
    constant C_BFM_SCOPE : string := "ADXL357 BFM";

    CONSTANT C_ADXL357_INSTANCE_NUMBER : positive := 8;

    type t_adxl357_if is record
        spi_if : t_spi_if;
        int1   : std_logic;
        int2   : std_logic;
        drdy   : std_logic;
    end record;

    type e_ADXL357_RegisterNames is (
            REG_DEVID_AD,        --0 offset 0x0       
            REG_DEVID_MST,       --1 offset 0x1      
            REG_PARTID,          --2 offset 0x2         
            REG_REVID,           --3 offset 0x3          
            REG_STATUS,          --4 offset 0x4         
            REG_FIFO_ENTRIES,    --5 offset 0x5   
            REG_TEMP2,           --6 offset 0x6          
            REG_TEMP1,           --7 offset 0x7          
            REG_XDATA3,          --8 offset 0x8         
            REG_XDATA2,          --9 offset 0x9         
            REG_XDATA1,          --10 offset 0xa         
            REG_YDATA3,          --11 offset 0xb         
            REG_YDATA2,          --12 offset 0xc         
            REG_YDATA1,          --13 offset 0xd         
            REG_ZDATA3,          --14 offset 0xe         
            REG_ZDATA2,          --15 offset 0xf         
            REG_ZDATA1,          --16 offset 0x10         
            REG_FIFO_DATA,       --17 offset 0x11      
            REG_RESERVED0,       --18 offset 0x12      
            REG_RESERVED1,       --19 offset 0x13      
            REG_RESERVED2,       --20 offset 0x14      
            REG_RESERVED3,       --21 offset 0x15      
            REG_RESERVED4,       --22 offset 0x16      
            REG_RESERVED5,       --23 offset 0x17      
            REG_RESERVED6,       --24 offset 0x18      
            REG_RESERVED7,       --25 offset 0x19      
            REG_RESERVED8,       --26 offset 0x1a      
            REG_RESERVED9,       --27 offset 0x1b      
            REG_RESERVED10,      --28 offset 0x1c      
            REG_RESERVED11,      --29 offset 0x1d      
            REG_OFFSET_X_H,      --30 offset 0x1e     
            REG_OFFSET_X_L,      --31 offset 0x1f     
            REG_OFFSET_Y_H,      --32 offset 0x20     
            REG_OFFSET_Y_L,      --33 offset 0x21     
            REG_OFFSET_Z_H,      --34 offset 0x22     
            REG_OFFSET_Z_L,      --35 offset 0x23     
            REG_ACT_EN,          --36 offset 0x24         
            REG_ACT_THRESHOLD_H, --37 offset 0x25
            REG_ACT_THRESHOLD_L, --38 offset 0x26
            REG_ACT_COUNT,       --39 offset 0x27         
            REG_FILTER,          --40 offset 0x28         
            REG_FIFO_SAMPLES,    --41 offset 0x29   
            REG_INT_MAP,         --42 offset 0x2a        
            REG_SYNC,            --43 offset 0x2b           
            REG_RANGE,           --44 offset 0x2c          
            REG_POWER_CTL,       --45 offset 0x2d      
            REG_SELF_TEST,       --46 offset 0x2e      
            REG_RESET,           --47 offset 0x2f
            RegN);               -- DO NOT MODIFY THE LAST REG ADD/REMOVE REGS BEFORE

    CONSTANT C_ADXL357_REG_N : INTEGER := e_ADXL357_RegisterNames'POS(RegN);

    type t_ADXL357_reg is record
        reset_value : std_logic_vector(7 downto 0);
        value       : unsigned(7 downto 0);
        read        : boolean;
        write       : boolean;
    end record t_ADXL357_reg;

    type t_ADXL357_reg_map is array (0 to C_ADXL357_REG_N-1) of t_ADXL357_reg;
    type t_ADXL357_reg_map_arr is array (0 to C_ADXL357_INSTANCE_NUMBER-1) of t_ADXL357_reg_map;

    constant C_ADXL357_reg_map : t_ADXL357_reg_map := (
            e_ADXL357_RegisterNames'POS(REG_DEVID_AD)        => (reset_value => x"AD", value => x"AD", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_DEVID_MST)       => (reset_value => x"1D", value => x"1D", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_PARTID)          => (reset_value => x"ED", value => x"ED", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_REVID)           => (reset_value => x"01", value => x"01", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_STATUS)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_FIFO_ENTRIES)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_TEMP2)           => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_TEMP1)           => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_XDATA3)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_XDATA2)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_XDATA1)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_YDATA3)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_YDATA2)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_YDATA1)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_ZDATA3)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_ZDATA2)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_ZDATA1)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_FIFO_DATA)       => (reset_value => x"00", value => x"00", read => true, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED0)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED1)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED2)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED3)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED4)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED5)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED6)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED7)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED8)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED9)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED10)      => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_RESERVED11)      => (reset_value => x"00", value => x"00", read => false, write => false),
            e_ADXL357_RegisterNames'POS(REG_OFFSET_X_H)      => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_OFFSET_X_L)      => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_OFFSET_Y_H)      => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_OFFSET_Y_L)      => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_OFFSET_Z_H)      => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_OFFSET_Z_L)      => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_ACT_EN)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_ACT_THRESHOLD_H) => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_ACT_THRESHOLD_L) => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_ACT_COUNT)       => (reset_value => x"01", value => x"01", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_FILTER)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_FIFO_SAMPLES)    => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_INT_MAP)         => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_SYNC)            => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_RANGE)           => (reset_value => x"81", value => x"81", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_POWER_CTL)       => (reset_value => x"01", value => x"01", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_SELF_TEST)       => (reset_value => x"00", value => x"00", read => true, write => true),
            e_ADXL357_RegisterNames'POS(REG_RESET)           => (reset_value => x"00", value => x"00", read => false, write => true));

    type t_ADXL357_spi_cmd is record
        reg             : e_ADXL357_RegisterNames;
        value           : unsigned(7 downto 0);
        read            : boolean;
        write           : boolean;
        next_cmd_seq_n  : integer;
    end record t_ADXL357_spi_cmd;

    constant C_ADXL357_spi_cmd_def  : t_ADXL357_spi_cmd := ( reg => REG_DEVID_AD, value => x"XX", read => false, write => false, next_cmd_seq_n => 0);

    type t_ADXL357_spi_cmd_seq is array (integer range <>) of t_ADXL357_spi_cmd;

    type t_ADXL357_test_vector_element is record
        x_value     : unsigned(23 downto 0);
        y_value     : unsigned(23 downto 0);
        z_value     : unsigned(23 downto 0);
        temp_value  : unsigned(15 downto 0);
    end record t_ADXL357_test_vector_element;

    type t_ADXL357_test_vectors is array (integer range <>) of t_ADXL357_test_vector_element;

    constant C_ADXL357_test_vector_element_def  : t_ADXL357_test_vector_element := ( others => (others => '0') );



    constant C_ADXL357_SPI_BFM_CONFIG : t_spi_bfm_config := (
            CPOL             => '0',
            CPHA             => '0',
            spi_bit_time     => 10 ns, -- Make sure we notice if we forget to set bit time.
            ss_n_to_sclk     => 20 ns,
            sclk_to_ss_n     => 20 ns,
            inter_word_delay => 40 ns,
            match_strictness => MATCH_EXACT,
            id_for_bfm       => ID_BFM,
            id_for_bfm_wait  => ID_BFM_WAIT,
            id_for_bfm_poll  => ID_BFM_POLL
        );

    constant C_SPI_propagation_delay : time := 30 ns;

    -- Configuration record to be assigned in the test harness.
    type t_adxl357_bfm_config is
        record
        reg_map               : t_ADXL357_reg_map;
        SPI_BFM_CONFIG        : t_spi_bfm_config ;
        SPI_propagation_delay : time;
    end record;


    -- Define the default value for the BFM config
    constant C_ADXL357_BFM_CONFIG_DEFAULT : t_adxl357_bfm_config := (
            reg_map               => C_ADXL357_reg_map,
            SPI_BFM_CONFIG        => C_ADXL357_SPI_BFM_CONFIG,
            SPI_propagation_delay => C_SPI_propagation_delay
        );

    constant C_SYNC_2_DRDY : t_integer_array(0 to 10) :=(
            0 => 8,
            1 => 10,
            2 => 14,
            3 => 22,
            4 => 38,
            5 => 70,
            6 => 134,
            7 => 262,
            8 => 1031,
            9 => 2054,
            10 => 4102);

    --==========================================================================================
    -- BFM procedures 
    --==========================================================================================

    function init_adxl357_if_signals return t_adxl357_if;

    procedure ADXL357_SPI_mng(
            signal spi_if     : inout t_spi_if;
            constant enable   : in    boolean := false;
            reg_map           : inout t_ADXL357_reg_map;
            signal reg        : inout   e_ADXL357_RegisterNames;
            signal readed_reg : inout   boolean;
            signal wrote_reg  : inout   boolean;
            constant config   : in t_spi_bfm_config         := C_SPI_BFM_CONFIG_DEFAULT
        );

    --procedure ADXL357_SPI_timing_check(
    --            signal spi_if    : inout t_spi_if;
    --            constant test_en : in    boolean := false
    --        );

    --procedure ADXL357_clock_period_check(
    --            signal VVCT                  : inout bitvis_vip_gpio.td_target_support_pkg.t_vvc_target_record;
    --            constant vvc_instance_idx    : in    integer;
    --            constant IMUREADY_period     : in    time;
    --            constant IMUREADY_tollerance : in    time;
    --            constant IMUREADY_value      : in    std_logic := '1';
    --            signal IMUREADY_assertion    : out   boolean   := false;
    --            constant test_en             : in    boolean   := false
    --        );
    --
    --
    --    procedure ADXL357_irq_mng(
    --            --signal spi_if   : inout t_spi_if;
    --            --constant enable : in    boolean := false;
    --            --signal reg_map  : inout t_ADXL357_reg_map
    --        );
    --
    --    procedure ADXL357_update_reg_map(
    --            --signal spi_if   : inout t_spi_if;
    --            --constant enable : in    boolean := false;
    --            --signal reg_map  : inout t_ADXL357_reg_map
    --        );
    --
    --    procedure ADXL357_set_test_vector(
    --            --signal spi_if   : inout t_spi_if;
    --            --constant enable : in    boolean := false;
    --            --signal reg_map  : inout t_ADXL357_reg_map
    --        );

    function f_idx2int( index : e_ADXL357_RegisterNames) return integer;

end package adxl357_bfm_pkg;



package body adxl357_bfm_pkg is

    function init_adxl357_if_signals return t_adxl357_if is
        variable result : t_adxl357_if;
    begin

        result.spi_if.ss_n := 'Z';
        result.spi_if.sclk := 'Z';
        result.spi_if.mosi := 'Z';
        result.spi_if.miso := 'Z';
        result.int1        := 'Z';
        result.int2        := 'Z';
        result.drdy        := '0';

        return result;
    end function;

    function f_idx2int( index : e_ADXL357_RegisterNames) return integer is
    begin
        return e_ADXL357_RegisterNames'POS(index);
    end function;



    procedure ADXL357_SPI_mng(
            signal spi_if     : inout t_spi_if;
            constant enable   : in    boolean := false;
            reg_map    : inout t_ADXL357_reg_map;
            signal reg        : inout   e_ADXL357_RegisterNames;
            signal readed_reg : inout   boolean;
            signal wrote_reg  : inout   boolean;
            constant config   : in t_spi_bfm_config         := C_SPI_BFM_CONFIG_DEFAULT
        ) is
        variable v_data : std_logic_vector(7 downto 0); -- Result from read 1;
        variable v_addr : unsigned(6 downto 0);
        variable v_rnw  : std_logic;
    begin

        if(enable) then
            
            spi_slave_receive( v_data, "Receiving from DUT", spi_if, START_TRANSFER_ON_NEXT_SS, C_SCOPE, shared_msg_id_panel, config);
            v_addr := unsigned(v_data(7 downto 1));
            v_rnw  := v_data(0);
            reg <= e_ADXL357_RegisterNames'VAL(to_integer(v_addr));
            if (v_rnw='1') then --read
                while (spi_if.ss_n = '0') loop
                    if (reg_map(to_integer(v_addr)).read=true) then
                        spi_slave_transmit (std_logic_vector(reg_map(to_integer(v_addr)).value), "Reading from ADXL",spi_if,START_TRANSFER_IMMEDIATE, C_SCOPE, shared_msg_id_panel, config);
                        gen_pulse(readed_reg, true, 1 ns, NON_BLOCKING, "Pulsing readed_reg for 1 ns");
                    else --error
                        error("ADXL357 Error read Request for a write only register", C_SCOPE);
                    end if;
                    v_addr := v_addr +1;
                    wait until (spi_if.sclk = not config.CPOL) or spi_if.ss_n = '1';
                end loop;
            else --write
                while (spi_if.ss_n = '0') loop
                    if (reg_map(to_integer(v_addr)).write=true) then
                        spi_slave_receive( v_data, "Receiving from DUT", spi_if, START_TRANSFER_IMMEDIATE, C_SCOPE, shared_msg_id_panel, config);
                        reg_map(to_integer(v_addr)).value := unsigned(v_data(7 downto 0));
                        gen_pulse(wrote_reg, true, 1 ns, NON_BLOCKING, "Pulsing wrote_reg for 1 ns");
                    else --error
                        error("ADXL357 Error write Request for a read only register", C_SCOPE);
                    end if;
                    v_addr := v_addr +1; 
                    wait until (spi_if.sclk = not config.CPOL) or spi_if.ss_n = '1';
                end loop;
            end if;
        end if;

    end procedure ADXL357_SPI_mng;


end package body adxl357_bfm_pkg;
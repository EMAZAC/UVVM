--==========================================================================================
-- This VVC was generated with Bitvis VVC Generator
--==========================================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
use uvvm_util.data_fifo_pkg.all;

library bitvis_vip_spi;
use bitvis_vip_spi.spi_bfm_pkg.all;

--==========================================================================================
--==========================================================================================
package P90_bfm_pkg is

    --==========================================================================================
    -- Types and constants for P90 BFM 
    --==========================================================================================
    constant C_BFM_SCOPE : string := "P90 BFM";

    CONSTANT C_P90_INSTANCE_NUMBER : positive := 8;

    --type t_P90_if is record
    --    spi_if : t_spi_if;
    --    int1   : std_logic;
    --    int2   : std_logic;
    --end record;

    type e_P90_RegisterNames is (
            REG_SN,              --0 offset 0x0       
            REG_PN,              --1 offset 0x4      
            REG_CALIB_M_Y,       --2 offset 0x8         
            REG_Kp,              --3 offset 0xC          
            REG_ki,              --4 offset 0x10         
            REG_RESERVED_x_5,    --5 offset 0x14   
            REG_RESERVED_x_6,    --6 offset 0x18          
            REG_RESERVED_x_7,    --7 offset 0x1C          
            REG_A0,              --8 offset 0x20         
            REG_A2,              --9 offset 0x24         
            REG_A5,              --10 offset 0x28         
            REG_A9,              --11 offset 0x2C         
            REG_A14,             --12 offset 0x30         
            REG_A20,             --13 offset 0x34         
            REG_A1,              --14 offset 0x38         
            REG_A4,              --15 offset 0x3C         
            REG_A8,              --16 offset 0x40         
            REG_A13,             --17 offset 0x44      
            REG_A19,             --18 offset 0x48      
            REG_A3,              --19 offset 0x4C      
            REG_A7,              --20 offset 0x50      
            REG_A12,             --21 offset 0x54      
            REG_A18,             --22 offset 0x58      
            REG_A6,              --23 offset 0x5C      
            REG_A11,             --24 offset 0x60      
            REG_A17,             --25 offset 0x64      
            REG_A10,             --26 offset 0x68      
            REG_A16,             --27 offset 0x6C      
            REG_A15,             --28 offset 0x70      
            REG_RESERVED_x_1D,   --29 offset 0x74      
            REG_RESERVED_x_1E,   --30 offset 0x78     
            REG_RESERVED_x_1F,   --31 offset 0x7C     
            REG_RESERVED_x_20,   --32 offset 0x80     
            REG_RESERVED_x_21,   --33 offset 0x84     
            REG_RESERVED_x_22,   --34 offset 0x88     
            REG_RESERVED_x_23,   --35 offset 0x8C     
            REG_CRC,             --36 offset 0x90         
            RegN);               -- DO NOT MODIFY THE LAST REG ADD/REMOVE REGS BEFORE

    CONSTANT C_P90_REG_N : INTEGER := e_P90_RegisterNames'POS(RegN);

    type t_P90_reg is record
        reset_value : std_logic_vector(31 downto 0);
        value       : unsigned(31 downto 0);
        read        : boolean;
        write       : boolean;
    end record t_P90_reg;

    type t_P90_reg_map is array (0 to C_P90_REG_N-1) of t_P90_reg;
    type t_P90_reg_map_arr is array (0 to C_P90_INSTANCE_NUMBER-1) of t_P90_reg_map;

    constant C_P90_reg_map : t_P90_reg_map := (
            e_P90_RegisterNames'POS(REG_SN)                   => (reset_value => x"01180005", value => x"01180005", read => true, write => false),
            e_P90_RegisterNames'POS(REG_PN)                   => (reset_value => x"20aae363", value => x"20aae363", read => true, write => false),
            e_P90_RegisterNames'POS(REG_CALIB_M_Y)            => (reset_value => x"20140010", value => x"20140010", read => true, write => false),
            e_P90_RegisterNames'POS(REG_Kp)                   => (reset_value => x"02060000", value => x"02060000", read => true, write => false),
            e_P90_RegisterNames'POS(REG_ki)                   => (reset_value => x"26006666", value => x"26006666", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_5)         => (reset_value => x"02000200", value => x"02000200", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_6)         => (reset_value => x"03000300", value => x"03000300", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_7)         => (reset_value => x"04000400", value => x"04000400", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A0)                   => (reset_value => x"3909669B", value => x"3909669B", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A2)                   => (reset_value => x"BA05BC95", value => x"BA05BC95", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A5)                   => (reset_value => x"E104EA76", value => x"E104EA76", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A9)                   => (reset_value => x"3305969A", value => x"3305969A", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A14)                  => (reset_value => x"D10524E8", value => x"D10524E8", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A20)                  => (reset_value => x"1104048E", value => x"1104048E", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A1)                   => (reset_value => x"1607DBD1", value => x"1607DBD1", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A4)                   => (reset_value => x"BBFFB2DF", value => x"BBFFB2DF", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A8)                   => (reset_value => x"08FF16DF", value => x"08FF16DF", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A13)                  => (reset_value => x"CAFF405C", value => x"CAFF405C", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A19)                  => (reset_value => x"58FE28D3", value => x"58FE28D3", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A3)                   => (reset_value => x"7A0041D4", value => x"7A0041D4", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A7)                   => (reset_value => x"EFFBC7FA", value => x"EFFBC7FA", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A12)                  => (reset_value => x"FDFA251C", value => x"FDFA251C", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A18)                  => (reset_value => x"2FF80EE0", value => x"2FF80EE0", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A6)                   => (reset_value => x"0AFBA4B1", value => x"0AFBA4B1", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A11)                  => (reset_value => x"95F65870", value => x"95F65870", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A17)                  => (reset_value => x"00F7AF91", value => x"00F7AF91", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A10)                  => (reset_value => x"27F3A13A", value => x"27F3A13A", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A16)                  => (reset_value => x"0BF35BC5", value => x"0BF35BC5", read => true, write => false),
            e_P90_RegisterNames'POS(REG_A15)                  => (reset_value => x"4DECEA51", value => x"4DECEA51", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_1D)        => (reset_value => x"26002600", value => x"26002600", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_1E)        => (reset_value => x"27002700", value => x"27002700", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_1F)        => (reset_value => x"28002800", value => x"28002800", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_20)        => (reset_value => x"29002900", value => x"29002900", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_21)        => (reset_value => x"30003000", value => x"30003000", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_22)        => (reset_value => x"31003100", value => x"31003100", read => true, write => false),
            e_P90_RegisterNames'POS(REG_RESERVED_x_23)        => (reset_value => x"32003200", value => x"32003200", read => true, write => false),
            e_P90_RegisterNames'POS(REG_CRC)                  => (reset_value => x"FFFFC5D2", value => x"FFFFC5D2", read => true, write => false));



    type t_P90_spi_cmd is record
        reg             : e_P90_RegisterNames;
        value           : unsigned(31 downto 0);
        read            : boolean;
        write           : boolean;
        next_cmd_seq_n  : integer;
    end record t_P90_spi_cmd;

    constant C_P90_SPI_CMD_DEF  : t_P90_spi_cmd := ( reg => REG_SN, value => x"XXXXXXXX", read => false, write => false, next_cmd_seq_n => 0);

    type t_P90_spi_cmd_seq is array (integer range <>) of t_P90_spi_cmd;

    type t_P90_test_vector_element is record
        gyro_x_value     : unsigned(15 downto 0);
        gyro_y_value     : unsigned(15 downto 0);
        gyro_z_value     : unsigned(15 downto 0);
        acc_x_value      : unsigned(15 downto 0);
        acc_y_value      : unsigned(15 downto 0);
        acc_z_value      : unsigned(15 downto 0);
        temp_value       : unsigned(15 downto 0);
    end record t_P90_test_vector_element;

    type t_P90_test_vectors is array (integer range <>) of t_P90_test_vector_element;

    constant C_P90_TEST_VECTOR_ELEMENT_DEF  : t_P90_test_vector_element := ( others => (others => '0') );

    constant C_P90_SPI_BFM_CONFIG : t_spi_bfm_config := (
            CPOL             => '0',
            CPHA             => '0',
            spi_bit_time     => 10 ns, -- Make sure we notice if we forget to set bit time.
            ss_n_to_sclk     => 20 ns,
            sclk_to_ss_n     => 20 ns,
            inter_word_delay => 40 ns,
            general_error_severity => error,
            match_strictness => MATCH_EXACT,
            id_for_bfm       => ID_BFM,
            id_for_bfm_wait  => ID_BFM_WAIT,
            id_for_bfm_poll  => ID_BFM_POLL
        );

    constant C_SPI_propagation_delay : time := 30 ns;

    -- Configuration record to be assigned in the test harness.
    type t_P90_bfm_config is
        record
        reg_map               : t_P90_reg_map;
        SPI_BFM_CONFIG        : t_spi_bfm_config ;
        SPI_propagation_delay : time;
    end record;


    -- Define the default value for the BFM config
    constant C_P90_BFM_CONFIG_DEFAULT : t_P90_bfm_config := (
            reg_map               => C_P90_reg_map,
            SPI_BFM_CONFIG        => C_P90_SPI_BFM_CONFIG,
            SPI_propagation_delay => C_SPI_propagation_delay
        );

    constant C_SPI_READ_CMD : std_logic_vector(7 downto 0) := "00000011";


    --==========================================================================================
    -- BFM procedures 
    --==========================================================================================

    --function init_P90_if_signals return t_P90_if;

    procedure P90_SPI_mng(
            signal spi_if     : inout t_spi_if;
            constant enable   : in    boolean := false;
            reg_map           : inout t_P90_reg_map;
            signal reg        : inout   e_P90_RegisterNames;
            signal readed_reg : inout   boolean;
            signal wrote_reg  : inout   boolean;
            constant config   : in t_spi_bfm_config         := C_SPI_BFM_CONFIG_DEFAULT
        );

    function f_idx2int( index : e_P90_RegisterNames) return integer;

end package P90_bfm_pkg;



package body P90_bfm_pkg is

    --function init_P90_if_signals return t_P90_if is
    --    variable result : t_P90_if;
    --begin
    --    result.spi_if.ss_n := 'Z';
    --    result.spi_if.sclk := 'Z';
    --    result.spi_if.mosi := 'Z';
    --    result.spi_if.miso := 'Z';
    --    result.int1        := 'Z';
    --    result.int2        := 'Z';
    --    return result;
    --end function;

    function f_idx2int( index : e_P90_RegisterNames) return integer is
    begin
        return e_P90_RegisterNames'POS(index);
    end function;

    procedure P90_SPI_mng(
            signal spi_if     : inout t_spi_if;
            constant enable   : in    boolean := false;
            reg_map    : inout t_P90_reg_map;
            signal reg        : inout   e_P90_RegisterNames;
            signal readed_reg : inout   boolean;
            signal wrote_reg  : inout   boolean;
            constant config   : in t_spi_bfm_config         := C_SPI_BFM_CONFIG_DEFAULT
        ) is
        variable v_data : std_logic_vector(7 downto 0); -- Result from read 1;
        variable v_addr : std_logic_vector(15 downto 0);
        variable v_rnw  : std_logic;
        variable v_byte : integer;
    begin

        if(enable) then
            
            spi_slave_receive( v_data, "Receiving from DUT", spi_if, START_TRANSFER_ON_NEXT_SS, C_SCOPE, shared_msg_id_panel, config);
            if (v_data/=C_SPI_READ_CMD) then
                error("P90 Error write command received", C_SCOPE);
            end if;
            v_rnw := '1';
            spi_slave_receive( v_addr, "Receiving from DUT", spi_if, START_TRANSFER_IMMEDIATE, C_SCOPE, shared_msg_id_panel, config);

            reg <= e_P90_RegisterNames'VAL(to_integer(unsigned(v_addr(15 downto 2))));
            if (v_rnw='1') then --read
                while (spi_if.ss_n = '0') loop
                    if (reg_map(to_integer(unsigned(v_addr(15 downto 2)))).read=true) then
                        v_byte := to_integer(unsigned(v_addr(1 downto 0)));
                        v_data := std_logic_vector(reg_map(to_integer(unsigned(v_addr(15 downto 2)))).value((8*(4-v_byte))-1 downto (8*(4-(v_byte+1)))));                
                        spi_slave_transmit (v_data, "Reading from P90",spi_if,START_TRANSFER_IMMEDIATE, C_SCOPE, shared_msg_id_panel, config); 
                        reg <= e_P90_RegisterNames'VAL(to_integer(unsigned(v_addr(15 downto 2))));
                        gen_pulse(readed_reg, true, 1 ns, NON_BLOCKING, "Pulsing readed_reg for 1 ns");                 
                    else --error
                        error("P90 Error read Request for a write only register", C_SCOPE);
                    end if;                    
                    v_addr := std_logic_vector(unsigned(v_addr) +1);
                    wait until (spi_if.sclk = not config.CPOL) or spi_if.ss_n = '1';
                end loop;
            else --write
                --while (spi_if.ss_n = '0') loop
                --    if (reg_map(to_integer(v_addr)).write=true) then
                --        spi_slave_receive( v_data, "Receiving from DUT", spi_if, START_TRANSFER_IMMEDIATE, C_SCOPE, shared_msg_id_panel, config);
                --        reg_map(to_integer(v_addr)).value := unsigned(v_data(7 downto 0));
                --        reg <= e_P90_RegisterNames'VAL(to_integer(v_addr));
                --        gen_pulse(wrote_reg, true, 1 ns, NON_BLOCKING, "Pulsing wrote_reg for 1 ns"); 
                --    else --error
                --        error("P90 Error write Request for a read only register", C_SCOPE);
                --    end if;                    
                --    v_addr := v_addr +1; 
                --    wait until (spi_if.sclk = not config.CPOL) or spi_if.ss_n = '1';
                --end loop;                
            end if;
        end if;

    end procedure P90_SPI_mng;



end package body P90_bfm_pkg;
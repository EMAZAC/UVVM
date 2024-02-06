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
package asm330_bfm_pkg is

    --==========================================================================================
    -- Types and constants for asm330 BFM 
    --==========================================================================================
    constant C_BFM_SCOPE : string := "asm330 BFM";

    CONSTANT C_ASM330_INSTANCE_NUMBER : positive := 8;

    --type t_asm330_if is record
    --    spi_if : t_spi_if;
    --    int1   : std_logic;
    --    int2   : std_logic;
    --end record;

    type e_asm330_RegisterNames is (
            REG_RESERVED_x_0,              --0 offset 0x0       
            REG_RESERVED_x_1,              --1 offset 0x1      
            REG_PIN_CTRL,                  --2 offset 0x2         
            REG_RESERVED_x_3,              --3 offset 0x3          
            REG_RESERVED_x_4,              --4 offset 0x4         
            REG_RESERVED_x_5,              --5 offset 0x5   
            REG_RESERVED_x_6,              --6 offset 0x6          
            REG_FIFO_CTRL_1,               --7 offset 0x7          
            REG_FIFO_CTRL_2,               --8 offset 0x8         
            REG_FIFO_CTRL_3,               --9 offset 0x9         
            REG_FIFO_CTRL_4,               --10 offset 0xa         
            REG_COUNTER_BDR_REG1,          --11 offset 0xb         
            REG_COUNTER_BDR_REG2,          --12 offset 0xc         
            REG_INT1_CTRL,                 --13 offset 0xd         
            REG_INT2_CTRL,                 --14 offset 0xe         
            REG_WHO_AM_I,                  --15 offset 0xf         
            REG_CTRL1_XL,                  --16 offset 0x10         
            REG_CTRL2_G,                   --17 offset 0x11      
            REG_CTRL3_C,                   --18 offset 0x12      
            REG_CTRL4_C,                   --19 offset 0x13      
            REG_CTRL5_C,                   --20 offset 0x14      
            REG_CTRL6_G,                   --21 offset 0x15      
            REG_CTRL7_G,                   --22 offset 0x16      
            REG_CTRL8_XL,                  --23 offset 0x17      
            REG_CTRL9_XL,                  --24 offset 0x18      
            REG_CTRL10_C,                  --25 offset 0x19      
            REG_ALL_INT_SRC,               --26 offset 0x1a      
            REG_WAKE_UP_SRC,               --27 offset 0x1b      
            REG_RESERVED_x_1C,             --28 offset 0x1c      
            REG_D6D_SRC,                   --29 offset 0x1d      
            REG_STATUS_REG,                --30 offset 0x1e     
            REG_RESERVED_x_1F,             --31 offset 0x1f     
            REG_OUT_TEMP_L,                --32 offset 0x20     
            REG_OUT_TEMP_H,                --33 offset 0x21     
            REG_OUTX_L_G,                  --34 offset 0x22     
            REG_OUTX_H_G,                  --35 offset 0x23     
            REG_OUTY_L_G,                  --36 offset 0x24         
            REG_OUTY_H_G,                  --37 offset 0x25
            REG_OUTZ_L_G,                  --38 offset 0x26
            REG_OUTZ_H_G,                  --39 offset 0x27         
            REG_OUTX_L_A,                  --40 offset 0x28         
            REG_OUTX_H_A,                  --41 offset 0x29   
            REG_OUTY_L_A,                  --42 offset 0x2a        
            REG_OUTY_H_A,                  --43 offset 0x2b           
            REG_OUTZ_L_A,                  --44 offset 0x2c          
            REG_OUTZ_H_A,                  --45 offset 0x2d 
            REG_RESERVED_x_2e,             --46 offset 0x2e     
            REG_RESERVED_x_2f,             --47 offset 0x2f     
            REG_RESERVED_x_30,             --48 offset 0x30     
            REG_RESERVED_x_31,             --49 offset 0x31     
            REG_RESERVED_x_32,             --50 offset 0x32     
            REG_RESERVED_x_33,             --51 offset 0x33     
            REG_RESERVED_x_34,             --52 offset 0x34     
            REG_RESERVED_x_35,             --53 offset 0x35     
            REG_RESERVED_x_36,             --54 offset 0x36     
            REG_RESERVED_x_37,             --55 offset 0x37     
            REG_RESERVED_x_38,             --56 offset 0x38     
            REG_RESERVED_x_39,             --57 offset 0x39     
            REG_FIFO_STATUS1,              --58 offset 0x3a
            REG_FIFO_STATUS2,              --59 offset 0x3b
            REG_RESERVED_x_3C,             --60 offset 0x3c
            REG_RESERVED_x_3D,             --61 offset 0x3d
            REG_RESERVED_x_3E,             --62 offset 0x3e
            REG_RESERVED_x_3F,             --63 offset 0x3f
            REG_TIMESTAMP0_REG,            --64 offset 0x40
            REG_TIMESTAMP1_REG,            --65 offset 0x41
            REG_TIMESTAMP2_REG,            --66 offset 0x42
            REG_TIMESTAMP3_REG,            --67 offset 0x43
            REG_RESERVED_x_44,             --68 offset 0x44
            REG_RESERVED_x_45,             --69 offset 0x45
            REG_RESERVED_x_46,             --70 offset 0x46
            REG_RESERVED_x_47,             --71 offset 0x47
            REG_RESERVED_x_48,             --72 offset 0x48
            REG_RESERVED_x_49,             --73 offset 0x49
            REG_RESERVED_x_4A,             --74 offset 0x4a
            REG_RESERVED_x_4B,             --75 offset 0x4b
            REG_RESERVED_x_4C,             --76 offset 0x4c
            REG_RESERVED_x_4D,             --77 offset 0x4d
            REG_RESERVED_x_4E,             --78 offset 0x4e
            REG_RESERVED_x_4F,             --79 offset 0x4f
            REG_RESERVED_x_50,             --80 offset 0x50
            REG_RESERVED_x_51,             --81 offset 0x51
            REG_RESERVED_x_52,             --82 offset 0x52
            REG_RESERVED_x_53,             --83 offset 0x53
            REG_RESERVED_x_54,             --84 offset 0x54
            REG_RESERVED_x_55,             --85 offset 0x55
            REG_INT_CFG0,                  --86 offset 0x56
            REG_RESERVED_x_57,             --87 offset 0x57
            REG_INT_CFG1,                  --88 offset 0x58
            REG_THS_6D,                    --89 offset 0x59
            REG_RESERVED_x_5A,             --90 offset 0x5a
            REG_WAKE_UP_THS,               --91 offset 0x5b
            REG_WAKE_UP_DUR,               --92 offset 0x5c
            REG_FREE_FALL,                 --93 offset 0x5d
            REG_MD1_CFG,                   --94 offset 0x5e
            REG_MD2_CFG,                   --95 offset 0x5f
            REG_RESERVED_x_60,             --96 offset 0x60
            REG_RESERVED_x_61,             --97 offset 0x61
            REG_RESERVED_x_62,             --98 offset 0x62
            REG_INTERNAL_FREQ_FINE,        --99 offset 0x63
            REG_RESERVED_x_64,             --100 offset 0x64
            REG_RESERVED_x_65,             --101 offset 0x65
            REG_RESERVED_x_66,             --102 offset 0x66
            REG_RESERVED_x_67,             --103 offset 0x67
            REG_RESERVED_x_68,             --104 offset 0x68
            REG_RESERVED_x_69,             --105 offset 0x69
            REG_RESERVED_x_6A,             --106 offset 0x6a
            REG_RESERVED_x_6B,             --107 offset 0x6b
            REG_RESERVED_x_6C,             --108 offset 0x6c
            REG_RESERVED_x_6D,             --109 offset 0x6d
            REG_RESERVED_x_6E,             --110 offset 0x6e
            REG_RESERVED_x_6F,             --111 offset 0x6f
            REG_RESERVED_x_70,             --112 offset 0x70
            REG_RESERVED_x_71,             --113 offset 0x71
            REG_RESERVED_x_72,             --114 offset 0x72
            REG_X_OFS_USR,                 --115 offset 0x73
            REG_Y_OFS_USR,                 --116 offset 0x74
            REG_Z_OFS_USR,                 --117 offset 0x75
            REG_RESERVED_x_76,             --118 offset 0x76
            REG_RESERVED_x_77,             --119 offset 0x77
            REG_FIFO_DATA_OUT_TAG,         --120 offset 0x78
            REG_FIFO_DATA_OUT_X_L,         --121 offset 0x79
            REG_FIFO_DATA_OUT_X_H,         --122 offset 0x7a
            REG_FIFO_DATA_OUT_Y_L,         --123 offset 0x7b
            REG_FIFO_DATA_OUT_Y_H,         --124 offset 0x7c
            REG_FIFO_DATA_OUT_Z_L,         --125 offset 0x7d
            REG_FIFO_DATA_OUT_Z_H,         --126 offset 0x7e
            REG_RESERVED_x_7F,             --127 offset 0x7f
            RegN);               -- DO NOT MODIFY THE LAST REG ADD/REMOVE REGS BEFORE

    CONSTANT C_ASM330_REG_N : INTEGER := e_asm330_RegisterNames'POS(RegN);

    type t_asm330_reg is record
        reset_value : std_logic_vector(7 downto 0);
        value       : unsigned(7 downto 0);
        read        : boolean;
        write       : boolean;
    end record t_asm330_reg;

    type t_asm330_reg_map is array (0 to C_ASM330_REG_N-1) of t_asm330_reg;
    type t_asm330_reg_map_arr is array (0 to C_ASM330_INSTANCE_NUMBER-1) of t_asm330_reg_map;

    constant C_asm330_reg_map : t_asm330_reg_map := (
            e_asm330_RegisterNames'POS(REG_RESERVED_x_0)         => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_1)         => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_PIN_CTRL)             => (reset_value => x"3F", value => x"3F", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_3)         => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_4)         => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_5)         => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_6)         => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_CTRL_1)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_FIFO_CTRL_2)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_FIFO_CTRL_3)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_FIFO_CTRL_4)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_COUNTER_BDR_REG1)     => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_COUNTER_BDR_REG2)     => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_INT1_CTRL)            => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_INT2_CTRL)            => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_WHO_AM_I)             => (reset_value => x"6B", value => x"6B", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_CTRL1_XL)             => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL2_G)              => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL3_C)              => (reset_value => x"04", value => x"04", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL4_C)              => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL5_C)              => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL6_G)              => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL7_G)              => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL8_XL)             => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL9_XL)             => (reset_value => x"C0", value => x"C0", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_CTRL10_C)             => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_ALL_INT_SRC)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_WAKE_UP_SRC)          => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_1C)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_D6D_SRC)              => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_STATUS_REG)           => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_1F)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_OUT_TEMP_L)           => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUT_TEMP_H)           => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTX_L_G)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTX_H_G)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTY_L_G)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTY_H_G)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTZ_L_G)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTZ_H_G)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTX_L_A)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTX_H_A)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTY_L_A)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTY_H_A)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTZ_L_A)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_OUTZ_H_A)             => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_2e)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_2f)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_30)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_31)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_32)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_33)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_34)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_35)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_36)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_37)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_38)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_39)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_STATUS1)         => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_STATUS2)         => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_3C)        => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_3D)        => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_3E)        => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_3F)        => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_TIMESTAMP0_REG)       => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_TIMESTAMP1_REG)       => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_TIMESTAMP2_REG)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_TIMESTAMP3_REG)       => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_44)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_45)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_46)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_47)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_48)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_49)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_4A)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_4B)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_4C)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_4D)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_4E)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_4F)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_50)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_51)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_52)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_53)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_54)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_55)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_INT_CFG0)             => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_57)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_INT_CFG1)             => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_THS_6D)               => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_5A)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_WAKE_UP_THS)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_WAKE_UP_DUR)          => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_FREE_FALL)            => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_MD1_CFG)              => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_MD2_CFG)              => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_60)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_61)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_62)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_INTERNAL_FREQ_FINE)   => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_64)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_65)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_66)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_67)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_68)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_69)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_6A)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_6B)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_6C)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_6D)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_6E)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_6F)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_70)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_71)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_72)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_X_OFS_USR)            => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_Y_OFS_USR)            => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_Z_OFS_USR)            => (reset_value => x"00", value => x"00", read => true, write => true),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_76)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_77)        => (reset_value => x"00", value => x"00", read => false, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_DATA_OUT_TAG)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_DATA_OUT_X_L)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_DATA_OUT_X_H)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_DATA_OUT_Y_L)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_DATA_OUT_Y_H)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_DATA_OUT_Z_L)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_FIFO_DATA_OUT_Z_H)    => (reset_value => x"00", value => x"00", read => true, write => false),
            e_asm330_RegisterNames'POS(REG_RESERVED_x_7F)        => (reset_value => x"00", value => x"00", read => false, write => false));

    type t_asm330_spi_cmd is record
        reg             : e_asm330_RegisterNames;
        value           : unsigned(7 downto 0);
        read            : boolean;
        write           : boolean;
        next_cmd_seq_n  : integer;
    end record t_asm330_spi_cmd;

    constant C_ASM330_SPI_CMD_DEF  : t_asm330_spi_cmd := ( reg => REG_WHO_AM_I, value => x"XX", read => false, write => false, next_cmd_seq_n => 0);

    type t_asm330_spi_cmd_seq is array (integer range <>) of t_asm330_spi_cmd;

    type t_asm330_test_vector_element is record
        gyro_x_value     : unsigned(15 downto 0);
        gyro_y_value     : unsigned(15 downto 0);
        gyro_z_value     : unsigned(15 downto 0);
        acc_x_value      : unsigned(15 downto 0);
        acc_y_value      : unsigned(15 downto 0);
        acc_z_value      : unsigned(15 downto 0);
        temp_value       : unsigned(15 downto 0);
    end record t_asm330_test_vector_element;

    type t_asm330_test_vectors is array (integer range <>) of t_asm330_test_vector_element;

    constant C_ASM330_TEST_VECTOR_ELEMENT_DEF  : t_asm330_test_vector_element := ( others => (others => '0') );

    constant C_ASM330_SPI_BFM_CONFIG : t_spi_bfm_config := (
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
    type t_asm330_bfm_config is
        record
        SPI_BFM_CONFIG                   : t_spi_bfm_config;
        SPI_propagation_delay            : time;
        GYRO_TEST_MODE_DRDY_SCALE_FACTOR : integer;
        ACC_TEST_MODE_DRDY_SCALE_FACTOR  : integer;
        TEMP_TEST_MODE_DRDY_SCALE_FACTOR : integer;
        IRQ_noise_frequency_Hz           : integer;
    end record;


    -- Define the default value for the BFM config
    constant C_ASM330_BFM_CONFIG_DEFAULT : t_asm330_bfm_config := (
            SPI_BFM_CONFIG        => C_asm330_SPI_BFM_CONFIG,
            SPI_propagation_delay => C_SPI_propagation_delay,
            GYRO_TEST_MODE_DRDY_SCALE_FACTOR => 4,
            ACC_TEST_MODE_DRDY_SCALE_FACTOR => 4,
            TEMP_TEST_MODE_DRDY_SCALE_FACTOR => 50,
            IRQ_noise_frequency_Hz => 4000000
        );

    constant C_ORD_COUNT : t_integer_array(0 to 11) :=(
            0  => -1,
            1  => 512,
            2  => 256,
            3  => 128,
            4  => 64,
            5  => 32,
            6  => 16,
            7  => 8,
            8  => 4,
            9  => 2,
            10 => 1,
            11 => 1024);


    constant C_TEMP_ORD_COUNT : t_integer_array(0 to 3) :=(
            0  => -1,
            1  => 32,
            2  => 4,
            3  => 1);

    constant C_ORD_TIME_nS : t_integer_array(0 to 10) :=(
            0  => -1,
            1  => 80000000,
            2  => 38462000,
            3  => 19231000,
            4  => 9615000,
            5  => 4808000,
            6  => 2404000,
            7  => 1202000,
            8  => 601000,
            9  => 300000,
            10 => 150000);

    constant C_TEMP_TIME_nS : integer := 19230769;

    constant C_FIFO_BYTE_SIZE : integer := 8*3*1024; 

    constant C_FIFO_TAG_SENSOR_GYRO : std_logic_vector(7 downto 0) := "00001" & "00" & "1"; -- x"01";
    constant C_FIFO_TAG_SENSOR_ACC  : std_logic_vector(7 downto 0) := "00010" & "00" & "1"; -- x"02";
    constant C_FIFO_TAG_SENSOR_TEMP : std_logic_vector(7 downto 0) := "00011" & "00" & "0"; -- x"03";
    constant C_FIFO_TAG_SENSOR_TIME : std_logic_vector(7 downto 0) := "00100" & "00" & "1"; -- x"04";
    constant C_FIFO_TAG_SENSOR_CFG  : std_logic_vector(7 downto 0) := "00101" & "00" & "0"; -- x"05";

    --==========================================================================================
    -- Sincronization flag
    --==========================================================================================
    constant C_BLOCK_FLAG_NAME_SIZE   : integer := 12;
    constant C_BLOCK_FLAG_0           : string(1 to C_BLOCK_FLAG_NAME_SIZE) := "BLOCK FLAG 0";
    constant C_BLOCK_FLAG_1           : string(1 to C_BLOCK_FLAG_NAME_SIZE) := "BLOCK FLAG 1";
    constant C_BLOCK_FLAG_2           : string(1 to C_BLOCK_FLAG_NAME_SIZE) := "BLOCK FLAG 2";
    constant C_BLOCK_FLAG_3           : string(1 to C_BLOCK_FLAG_NAME_SIZE) := "BLOCK FLAG 3";

    --==========================================================================================
    -- BFM procedures 
    --==========================================================================================

    --function init_asm330_if_signals return t_asm330_if;

    procedure asm330_SPI_mng(
            signal spi_if     : inout t_spi_if;
            constant enable   : in    boolean := false;
            reg_map           : inout t_asm330_reg_map;
            signal reg        : inout   e_asm330_RegisterNames;
            signal readed_reg : inout   boolean;
            signal wrote_reg  : inout   boolean;
            constant config   : in t_spi_bfm_config         := C_SPI_BFM_CONFIG_DEFAULT
        );

    procedure asm330_update_fifo_status(
            reg_map           : inout t_asm330_reg_map;
            signal BDR_cnt    : in integer;
            signal fifo_idx   : in natural
        );

    function f_idx2int( index : e_asm330_RegisterNames) return integer;

end package asm330_bfm_pkg;



package body asm330_bfm_pkg is

    --function init_asm330_if_signals return t_asm330_if is
    --    variable result : t_asm330_if;
    --begin
    --    result.spi_if.ss_n := 'Z';
    --    result.spi_if.sclk := 'Z';
    --    result.spi_if.mosi := 'Z';
    --    result.spi_if.miso := 'Z';
    --    result.int1        := 'Z';
    --    result.int2        := 'Z';
    --    return result;
    --end function;

    function f_idx2int( index : e_asm330_RegisterNames) return integer is
    begin
        return e_asm330_RegisterNames'POS(index);
    end function;

    procedure asm330_SPI_mng(
            signal spi_if     : inout t_spi_if;
            constant enable   : in    boolean := false;
            reg_map    : inout t_asm330_reg_map;
            signal reg        : inout   e_asm330_RegisterNames;
            signal readed_reg : inout   boolean;
            signal wrote_reg  : inout   boolean;
            constant config   : in t_spi_bfm_config         := C_SPI_BFM_CONFIG_DEFAULT
        ) is
        variable v_data : std_logic_vector(7 downto 0); -- Result from read 1;
        variable v_addr : unsigned(6 downto 0);
        variable v_rnw  : std_logic;
        variable v_aborted  : boolean := false;
    begin

        if(enable) then
            
            spi_slave_receive( v_data, v_aborted, "Receiving from DUT", spi_if, START_TRANSFER_ON_NEXT_SS, C_SCOPE, shared_msg_id_panel, config);
            if (not v_aborted) then
                v_addr := unsigned(v_data(6 downto 0));
                v_rnw  := v_data(7);
                reg <= e_asm330_RegisterNames'VAL(to_integer(v_addr));
                if (v_rnw='1') then --read
                    while (spi_if.ss_n = '0') loop
                        if (reg_map(to_integer(v_addr)).read=true) then                    
                            spi_slave_transmit (std_logic_vector(reg_map(to_integer(v_addr)).value), v_aborted, "Reading from ASM330",spi_if,START_TRANSFER_IMMEDIATE, C_SCOPE, shared_msg_id_panel, config); 
                            
                            if (not v_aborted) then
                                reg <= e_asm330_RegisterNames'VAL(to_integer(v_addr));
                                gen_pulse(readed_reg, true, 1 ns, NON_BLOCKING, "Pulsing readed_reg for 1 ns"); 
                            end if;
                                            
                        else --error
                            error("asm330 Error read Request for a write only register", C_SCOPE);
                        end if;                    
                        v_addr := v_addr +1;
                        wait until (spi_if.sclk = not config.CPOL) or spi_if.ss_n = '1';
                    end loop;
                else --write
                    while (spi_if.ss_n = '0') loop
                        if (reg_map(to_integer(v_addr)).write=true) then
                            spi_slave_receive( v_data, v_aborted, "Receiving from DUT", spi_if, START_TRANSFER_IMMEDIATE, C_SCOPE, shared_msg_id_panel, config);
                            if (not v_aborted) then
                                reg_map(to_integer(v_addr)).value := unsigned(v_data(7 downto 0));
                                reg <= e_asm330_RegisterNames'VAL(to_integer(v_addr));
                                gen_pulse(wrote_reg, true, 1 ns, NON_BLOCKING, "Pulsing wrote_reg for 1 ns"); 
                            end if;
                        else --error
                            error("asm330 Error write Request for a read only register", C_SCOPE);
                        end if;                    
                        v_addr := v_addr +1; 
                        wait until (spi_if.sclk = not config.CPOL) or spi_if.ss_n = '1';
                    end loop;                
                end if;
            end if;            
        end if;

    end procedure asm330_SPI_mng;

    procedure asm330_update_fifo_status(
            reg_map           : inout t_asm330_reg_map;
            signal BDR_cnt    : in integer;
            signal fifo_idx   : in natural
        ) is
        variable v_fifo_byte_cnt : natural;
        variable v_fifo_byte_cnt_unsigned : unsigned(9 downto 0);
        variable v_fifo_WTM : unsigned(8 downto 0);
        variable v_fifo_BDR : unsigned(10 downto 0);
    begin 

        v_fifo_byte_cnt :=  uvvm_fifo_get_count(fifo_idx)/8;
        v_fifo_byte_cnt_unsigned := to_unsigned(v_fifo_byte_cnt,10);
        reg_map(f_idx2int(REG_FIFO_STATUS1)).value := v_fifo_byte_cnt_unsigned(7 downto 0);
        reg_map(f_idx2int(REG_FIFO_STATUS2)).value(1 downto 0) := v_fifo_byte_cnt_unsigned(9 downto 8);

        v_fifo_WTM := reg_map(f_idx2int(REG_FIFO_CTRL_2)).value(0) & reg_map(f_idx2int(REG_FIFO_CTRL_1)).value;
        v_fifo_BDR := reg_map(f_idx2int(REG_COUNTER_BDR_REG1)).value(2 downto 0) & reg_map(f_idx2int(REG_COUNTER_BDR_REG2)).value;

        if (v_fifo_byte_cnt/7>=v_fifo_WTM) then
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(7) := '1';
        else
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(7) := '0';
        end if;

        if (v_fifo_byte_cnt=C_FIFO_BYTE_SIZE) then
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(6) := '1';
        else
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(6) := '0';
        end if;

        if (v_fifo_byte_cnt>=C_FIFO_BYTE_SIZE-7) then
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(5) := '1';
        else
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(5) := '0';
        end if;

        if (v_fifo_byte_cnt=C_FIFO_BYTE_SIZE) then
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(4) := '1';                      
        end if;

        if (BDR_cnt>=v_fifo_BDR) then
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(3) := '1';
        else
            reg_map(f_idx2int(REG_FIFO_STATUS2)).value(3) := '0';
        end if;   

    end procedure;


end package body asm330_bfm_pkg;


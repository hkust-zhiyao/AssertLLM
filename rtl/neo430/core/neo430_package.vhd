-- #################################################################################################
-- #  << NEO430 - Processor Package >>                                                             #
-- # ********************************************************************************************* #
-- # This file is part of the NEO430 Processor project: https://github.com/stnolting/neo430        #
-- # Copyright by Stephan Nolting: stnolting@gmail.com                                             #
-- #                                                                                               #
-- # This source file may be used and distributed without restriction provided that this copyright #
-- # statement is not removed from the file and that any derivative work contains the original     #
-- # copyright notice and the associated disclaimer.                                               #
-- #                                                                                               #
-- # This source file is free software; you can redistribute it and/or modify it under the terms   #
-- # of the GNU Lesser General Public License as published by the Free Software Foundation,        #
-- # either version 3 of the License, or (at your option) any later version.                       #
-- #                                                                                               #
-- # This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;      #
-- # without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.     #
-- # See the GNU Lesser General Public License for more details.                                   #
-- #                                                                                               #
-- # You should have received a copy of the GNU Lesser General Public License along with this      #
-- # source; if not, download it from https://www.gnu.org/licenses/lgpl-3.0.en.html                #
-- # ********************************************************************************************* #
-- # Stephan Nolting, Hannover, Germany                                                 17.11.2018 #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package neo430_package is

  -- Processor Hardware Version -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant hw_version_c : std_ulogic_vector(15 downto 0) := x"0200"; -- no touchy!

  -- Danger Zone! ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant low_power_mode_c : boolean := false; -- reduces switching activity, but will also decrease f_max and might increase area
  constant awesome_mode_c   : boolean := true; -- of course!

  -- Internal Functions ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function index_size_f(input : natural) return natural;
  function is_power_of_two_f(num : natural; bit_width : natural) return boolean;
  function bit_reversal_f(input : std_ulogic_vector) return std_ulogic_vector;
  function set_bits_f(input : std_ulogic_vector) return natural;
  function leading_zeros_f(input : std_ulogic_vector) return natural;
  function cond_sel_natural_f(cond : boolean; val_t : natural; val_f : natural) return natural;
  function cond_sel_stdulogicvector_f(cond : boolean; val_t : std_ulogic_vector; val_f : std_ulogic_vector) return std_ulogic_vector;
  function bool_to_ulogic_f(cond : boolean) return std_ulogic;
  function bin_to_gray_f(input : std_ulogic_vector) return std_ulogic_vector;
  function gray_to_bin_f(input : std_ulogic_vector) return std_ulogic_vector;
  function int_to_hexchar_f(input : integer) return character;
  function bcd_add4_f(a : std_ulogic_vector; b : std_ulogic_vector; c : std_ulogic) return std_ulogic_vector;
  function or_all_f(a : std_ulogic_vector) return std_ulogic;
  function and_all_f(a : std_ulogic_vector) return std_ulogic;
  function xor_all_f(a : std_ulogic_vector) return std_ulogic;

  -- Address Space Layout -------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------

  -- Main Memory: IMEM(ROM/RAM) --
  constant imem_base_c : std_ulogic_vector(15 downto 0) := x"0000"; -- base address, fixed!

  -- Main Memory: DMEM(RAM) --
  constant dmem_base_c : std_ulogic_vector(15 downto 0) := x"C000"; -- base address, fixed!

  -- Boot ROM --
  constant boot_base_c : std_ulogic_vector(15 downto 0) := x"F000"; -- bootloader base address, fixed!
  constant boot_size_c : natural := 2048; -- bytes, max 2048 bytes!

  -- IO: Peripheral Devices ("IO") Area --
  -- Each device must use 2 bytes or a multiple of 2 bytes as address space!
  -- CONTROL register(s) (including the device enable) must be located at the base address of the device!
  constant io_base_c : std_ulogic_vector(15 downto 0) := x"FF80";
  constant io_size_c : natural := 128; -- bytes, fixed!

  -- IO: Multiplier/Divider Unit (MULDIV) --
  constant muldiv_base_c : std_ulogic_vector(15 downto 0) := x"FF80";
  constant muldiv_size_c : natural := 16; -- bytes

  constant muldiv_opa_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"0000");
  constant muldiv_opb_div_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"0002");
  constant muldiv_opb_mul_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"0004");
--constant muldiv_???_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"0006");
--constant muldiv_???_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"0008");
--constant muldiv_???_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"000A");
  constant muldiv_resx_addr_c    : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"000C");
  constant muldiv_resy_addr_c    : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(muldiv_base_c) + x"000E");

  -- IO: Wishbone32 Interface (WB32) --
  constant wb32_base_c : std_ulogic_vector(15 downto 0) := x"FF90";
  constant wb32_size_c : natural := 16; -- bytes

  constant wb32_ctrl_addr_c      : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"0000");
  constant wb32_rd_adr_lo_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"0002");
  constant wb32_rd_adr_hi_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"0004");
  constant wb32_wr_adr_lo_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"0006");
  constant wb32_wr_adr_hi_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"0008");
  constant wb32_data_lo_addr_c   : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"000A");
  constant wb32_data_hi_addr_c   : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"000C");
--constant wb32_???_addr_c       : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wb32_base_c) + x"000E");

  -- IO: Universal asynchronous receiver and transmitter (UART) --
  constant uart_base_c : std_ulogic_vector(15 downto 0) := x"FFA0";
  constant uart_size_c : natural := 4; -- bytes

  constant uart_ctrl_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(uart_base_c) + x"0000");
  constant uart_rtx_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(uart_base_c) + x"0002");

  -- IO: Serial Peripheral Interface (SPI) --
  constant spi_base_c : std_ulogic_vector(15 downto 0) := x"FFA4";
  constant spi_size_c : natural := 4; -- bytes

  constant spi_ctrl_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(spi_base_c) + x"0000");
  constant spi_rtx_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(spi_base_c) + x"0002");

  -- IO: General purpose input/output port (GPIO)  --
  constant gpio_base_c : std_ulogic_vector(15 downto 0) := x"FFA8";
  constant gpio_size_c : natural := 8; -- bytes

--constant gpio_???_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(gpio_base_c) + x"0000");
  constant gpio_irqmask_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(gpio_base_c) + x"0002");
  constant gpio_in_addr_c      : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(gpio_base_c) + x"0004");
  constant gpio_out_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(gpio_base_c) + x"0006");

  -- IO: High-Precision Timer (TIMER) --
  constant timer_base_c : std_ulogic_vector(15 downto 0) := x"FFB0";
  constant timer_size_c : natural := 8; -- bytes

  constant timer_ctrl_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(timer_base_c) + x"0000");
  constant timer_cnt_addr_c   : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(timer_base_c) + x"0002");
  constant timer_thres_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(timer_base_c) + x"0004");
--constant timer_???_addr_c   : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(timer_base_c) + x"0006");

  -- IO: Watchdog Timer (WDT) --
  constant wdt_base_c : std_ulogic_vector(15 downto 0) := x"FFB8";
  constant wdt_size_c : natural := 2; -- bytes

  constant wdt_ctrl_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(wdt_base_c) + x"0000");

  -- IO: Cyclic Redundancy Check (CRC) --
  constant crc_base_c : std_ulogic_vector(15 downto 0) := x"FFC0";
  constant crc_size_c : natural := 16; -- bytes

  constant crc_poly_lo_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"0000");
  constant crc_poly_hi_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"0002");
  constant crc_crc16_in_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"0004");
  constant crc_crc32_in_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"0006");
--constant crc_???_addr_c      : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"0008");
--constant crc_???_addr_c      : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"000A");
  constant crc_resx_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"000C");
  constant crc_resy_addr_c     : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(crc_base_c) + x"000E");

  -- IO: Custom Functions Unit (CFU) --
  constant cfu_base_c : std_ulogic_vector(15 downto 0) := x"FFD0";
  constant cfu_size_c : natural := 16; -- bytes

  constant cfu_reg0_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"0000");
  constant cfu_reg1_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"0002");
  constant cfu_reg2_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"0004");
  constant cfu_reg3_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"0006");
  constant cfu_reg4_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"0008");
  constant cfu_reg5_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"000A");
  constant cfu_reg6_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"000C");
  constant cfu_reg7_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(cfu_base_c) + x"000E");

  -- IO: Pulse-Width Modulation Controller (PWM) --
  constant pwm_base_c : std_ulogic_vector(15 downto 0) := x"FFE0";
  constant pwm_size_c : natural := 8; -- bytes

  constant pwm_ctrl_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(pwm_base_c) + x"0000");
  constant pwm_ch0_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(pwm_base_c) + x"0002");
  constant pwm_ch1_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(pwm_base_c) + x"0004");
  constant pwm_ch2_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(pwm_base_c) + x"0006");

  -- IO: Two Wire Serial Interface --
  constant twi_base_c : std_ulogic_vector(15 downto 0) := x"FFE8";
  constant twi_size_c : natural := 4; -- bytes

  constant twi_ctrl_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(twi_base_c) + x"0000");
  constant twi_rtx_addr_c  : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(twi_base_c) + x"0002");

  -- IO: RESERVED --
--constant ???_base_c : std_ulogic_vector(15 downto 0) := x"FFFC";
--constant ???_size_c : natural := 2; -- bytes

--constant ???_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(???_base_c) + x"0000");
--constant ???_addr_c : std_ulogic_vector(15 downto 0) := std_ulogic_vector(unsigned(???_base_c) + x"0002");

  -- IO: System Configuration --
  constant sysconfig_base_c : std_ulogic_vector(15 downto 0) := x"FFF0";
  constant sysconfig_size_c : natural := 16; -- bytes

  -- Clock Generator -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant clk_div2_c    : natural := 0;
  constant clk_div4_c    : natural := 1;
  constant clk_div8_c    : natural := 2;
  constant clk_div64_c   : natural := 3;
  constant clk_div128_c  : natural := 4;
  constant clk_div1024_c : natural := 5;
  constant clk_div2048_c : natural := 6;
  constant clk_div4096_c : natural := 7;

  -- Register Addresses ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant reg_pc_c : std_ulogic_vector(3 downto 0) := x"0"; -- program counter
  constant reg_sp_c : std_ulogic_vector(3 downto 0) := x"1"; -- stack pointer
  constant reg_sr_c : std_ulogic_vector(3 downto 0) := x"2"; -- status register
  constant reg_cg_c : std_ulogic_vector(3 downto 0) := x"3"; -- constant generator

  -- Status Register ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant sreg_c_c : natural := 0;  -- r/w: carry flag
  constant sreg_z_c : natural := 1;  -- r/w: zero flag
  constant sreg_n_c : natural := 2;  -- r/w: negative flag
  constant sreg_i_c : natural := 3;  -- r/w: global interrupt enable
  constant sreg_s_c : natural := 4;  -- r/w: CPU sleep flag
  constant sreg_v_c : natural := 8;  -- r/w: overflow flag
  constant sreg_q_c : natural := 14; -- -/w: clear pending IRQ buffer when set
  constant sreg_r_c : natural := 15; -- r/w: enable write access to IMEM (ROM) when set

  -- ALU Flag Bus ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant flag_c_c : natural := 0; -- carry flag
  constant flag_z_c : natural := 1; -- zero flag
  constant flag_n_c : natural := 2; -- negative flag
  constant flag_v_c : natural := 3; -- overflow flag

  -- Main Control Bus -----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- register file --
  constant ctrl_rf_in_sel_c   : natural :=  0; -- input source
  constant ctrl_rf_adr0_c     : natural :=  1; -- source/destination register address bit 0
  constant ctrl_rf_adr1_c     : natural :=  2; -- source/destination register address bit 1
  constant ctrl_rf_adr2_c     : natural :=  3; -- source/destination register address bit 2
  constant ctrl_rf_adr3_c     : natural :=  4; -- source/destination register address bit 3
  constant ctrl_rf_as0_c      : natural :=  5; -- source addressing mode bit 0
  constant ctrl_rf_as1_c      : natural :=  6; -- source addressing mode bit 1
  constant ctrl_rf_ad_c       : natural :=  7; -- destination addressing mode
  constant ctrl_rf_fup_c      : natural :=  8; -- update ALU flags
  constant ctrl_rf_wb_en_c    : natural :=  9; -- enable RF write back
  constant ctrl_rf_dsleep_c   : natural := 10; -- disable sleep mode
  constant ctrl_rf_dgie_c     : natural := 11; -- disable global interrupt enable
  constant ctrl_rf_boot_c     : natural := 12; -- inject PC boot address
  -- alu --
  constant ctrl_alu_in_sel_c  : natural := 13; -- ALU OP input select
  constant ctrl_alu_opa_wr_c  : natural := 14; -- write ALU operand A
  constant ctrl_alu_opb_wr_c  : natural := 15; -- write ALU operand B
  constant ctrl_alu_cmd0_c    : natural := 16; -- ALU command bit 0
  constant ctrl_alu_cmd1_c    : natural := 17; -- ALU command bit 1
  constant ctrl_alu_cmd2_c    : natural := 18; -- ALU command bit 2
  constant ctrl_alu_cmd3_c    : natural := 19; -- ALU command bit 3
  constant ctrl_alu_bw_c      : natural := 20; -- byte(1)/word(0) operation
  -- address generator --
  constant ctrl_adr_off0_c    : natural := 21; -- address offset selection bit 0
  constant ctrl_adr_off1_c    : natural := 22; -- address offset selection bit 1
  constant ctrl_adr_imm_en_c  : natural := 23; -- select immediate branch input
  constant ctrl_adr_mar_sel_c : natural := 24; -- select input for MAR
  constant ctrl_adr_bp_en_c   : natural := 25; -- mem addr output select, 0:MAR, 1:bypass
  constant ctrl_adr_ivec_oe_c : natural := 26; -- output IRQ if 1, else output PC
  constant ctrl_adr_mar_wr_c  : natural := 27; -- write MAR
  -- memory interface --
  constant ctrl_mem_wr_c      : natural := 28; -- write to memory
  constant ctrl_mem_rd_c      : natural := 29; -- read from memory
  -- bus size --
  constant ctrl_width_c       : natural := 30; -- control bus size

  -- Condition Codes ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant cond_ne_c : std_ulogic_vector(2 downto 0) := "000"; -- not equal
  constant cond_eq_c : std_ulogic_vector(2 downto 0) := "001"; -- equal
  constant cond_lo_c : std_ulogic_vector(2 downto 0) := "010"; -- lower
  constant cond_hs_c : std_ulogic_vector(2 downto 0) := "011"; -- higher or same
  constant cond_mi_c : std_ulogic_vector(2 downto 0) := "100"; -- negative
  constant cond_ge_c : std_ulogic_vector(2 downto 0) := "101"; -- greater or equal
  constant cond_le_c : std_ulogic_vector(2 downto 0) := "110"; -- less
  constant cond_al_c : std_ulogic_vector(2 downto 0) := "111"; -- always

  -- ALU Function Codes ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  constant alu_rrc_c  : std_ulogic_vector(3 downto 0) := "0000"; -- r <= a >>> 1, rotate right through carry
  constant alu_swap_c : std_ulogic_vector(3 downto 0) := "0001"; -- r <= swap bytes of a
  constant alu_rra_c  : std_ulogic_vector(3 downto 0) := "0010"; -- r <= a >>> 1, rotate right arithmetically
  constant alu_sxt_c  : std_ulogic_vector(3 downto 0) := "0011"; -- r <= a, sign extend byte
  constant alu_mov_c  : std_ulogic_vector(3 downto 0) := "0100"; -- r <= a
  constant alu_add_c  : std_ulogic_vector(3 downto 0) := "0101"; -- r <= a + b
  constant alu_addc_c : std_ulogic_vector(3 downto 0) := "0110"; -- r <= a + b + carry
  constant alu_subc_c : std_ulogic_vector(3 downto 0) := "0111"; -- r <= b - a - 1 + carry
  constant alu_sub_c  : std_ulogic_vector(3 downto 0) := "1000"; -- r <= b - a
  constant alu_cmp_c  : std_ulogic_vector(3 downto 0) := "1001"; -- b - a (no write back)
  constant alu_dadd_c : std_ulogic_vector(3 downto 0) := "1010"; -- r <= a + b (BCD!)
  constant alu_bit_c  : std_ulogic_vector(3 downto 0) := "1011"; -- a & b (no write back)
  constant alu_bic_c  : std_ulogic_vector(3 downto 0) := "1100"; -- r <= !a & b
  constant alu_bis_c  : std_ulogic_vector(3 downto 0) := "1101"; -- r <= a | b
  constant alu_xor_c  : std_ulogic_vector(3 downto 0) := "1110"; -- r <= a xor b
  constant alu_and_c  : std_ulogic_vector(3 downto 0) := "1111"; -- r <= a & b


  -- The Core of the Problem: Processor Top Entity ------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_top
    generic (
      -- general configuration --
      CLOCK_SPEED : natural := 100000000; -- main clock in Hz
      IMEM_SIZE   : natural := 4*1024; -- internal IMEM size in bytes, max 32kB (default=4kB)
      DMEM_SIZE   : natural := 2*1024; -- internal DMEM size in bytes, max 28kB (default=2kB)
      -- additional configuration --
      USER_CODE   : std_ulogic_vector(15 downto 0) := x"0000"; -- custom user code
      -- module configuration --
      DADD_USE    : boolean := true; -- implement DADD instruction? (default=true)
      MULDIV_USE  : boolean := true; -- implement multiplier/divider unit? (default=true)
      WB32_USE    : boolean := true; -- implement WB32 unit? (default=true)
      WDT_USE     : boolean := true; -- implement WDT? (default=true)
      GPIO_USE    : boolean := true; -- implement GPIO unit? (default=true)
      TIMER_USE   : boolean := true; -- implement timer? (default=true)
      UART_USE    : boolean := true; -- implement UART? (default=true)
      CRC_USE     : boolean := true; -- implement CRC unit? (default=true)
      CFU_USE     : boolean := false; -- implement custom functions unit? (default=false)
      PWM_USE     : boolean := true; -- implement PWM controller? (default = true)
      TWI_USE     : boolean := true; -- implement two wire serial interface? (default=true)
      SPI_USE     : boolean := true; -- implement SPI? (default=true)
      -- boot configuration --
      BOOTLD_USE  : boolean := true; -- implement and use bootloader? (default=true)
      IMEM_AS_ROM : boolean := false -- implement IMEM as read-only memory? (default=false)
    );
    port (
      -- global control --
      clk_i      : in  std_ulogic; -- global clock, rising edge
      rst_i      : in  std_ulogic; -- global reset, async, low-active
      -- gpio --
      gpio_o     : out std_ulogic_vector(15 downto 0); -- parallel output
      gpio_i     : in  std_ulogic_vector(15 downto 0); -- parallel input
      -- pwm channels --
      pwm_o      : out std_ulogic_vector(02 downto 0); -- pwm channels
      -- serial com --
      uart_txd_o : out std_ulogic; -- UART send data
      uart_rxd_i : in  std_ulogic; -- UART receive data
      spi_sclk_o : out std_ulogic; -- serial clock line
      spi_mosi_o : out std_ulogic; -- serial data line out
      spi_miso_i : in  std_ulogic; -- serial data line in
      spi_cs_o   : out std_ulogic_vector(07 downto 0); -- SPI CS 0..7
      twi_sda_io : inout std_logic; -- twi serial data line
      twi_scl_io : inout std_logic; -- twi serial clock line
      -- 32-bit wishbone interface --
      wb_adr_o   : out std_ulogic_vector(31 downto 0); -- address
      wb_dat_i   : in  std_ulogic_vector(31 downto 0); -- read data
      wb_dat_o   : out std_ulogic_vector(31 downto 0); -- write data
      wb_we_o    : out std_ulogic; -- read/write
      wb_sel_o   : out std_ulogic_vector(03 downto 0); -- byte enable
      wb_stb_o   : out std_ulogic; -- strobe
      wb_cyc_o   : out std_ulogic; -- valid cycle
      wb_ack_i   : in  std_ulogic; -- transfer acknowledge
      -- interrupts --
      irq_i      : in  std_ulogic; -- external interrupt request line
      irq_ack_o  : out std_ulogic  -- external interrupt request acknowledge
    );
  end component;

  -- Component: Control ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_control
    generic (
      DADD_USE : boolean := true -- implement DADD instruction?
    );
    port (
      -- global control --
      clk_i     : in  std_ulogic; -- global clock, rising edge
      rst_i     : in  std_ulogic; -- global reset, low-active, async
      -- memory interface --
      instr_i   : in  std_ulogic_vector(15 downto 0); -- instruction word from memory
      -- control --
      sreg_i    : in  std_ulogic_vector(15 downto 0); -- current status register
      ctrl_o    : out std_ulogic_vector(ctrl_width_c-1 downto 0); -- control signals
      irq_vec_o : out std_ulogic_vector(01 downto 0); -- irq channel address
      imm_o     : out std_ulogic_vector(15 downto 0); -- branch offset
      -- irq lines --
      irq_i     : in  std_ulogic_vector(03 downto 0); -- IRQ lines
      irq_ack_o : out std_ulogic_vector(03 downto 0)  -- IRQ acknowledge
    );
  end component;

  -- Component: Register File ---------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_reg_file
    generic (
      BOOTLD_USE  : boolean := true; -- implement and use bootloader?
      IMEM_AS_ROM : boolean := false -- implement IMEM as read-only memory?
    );
    port (
      -- global control --
      clk_i  : in  std_ulogic; -- global clock, rising edge
      rst_i  : in  std_ulogic; -- global reset, low-active, async
      -- data input --
      alu_i  : in  std_ulogic_vector(15 downto 0); -- data from alu
      addr_i : in  std_ulogic_vector(15 downto 0); -- data from addr unit
      flag_i : in  std_ulogic_vector(03 downto 0); -- new ALU flags
      -- control --
      ctrl_i : in  std_ulogic_vector(ctrl_width_c-1 downto 0);
      -- data output --
      data_o : out std_ulogic_vector(15 downto 0); -- read data
      sreg_o : out std_ulogic_vector(15 downto 0)  -- current SR
    );
  end component;

  -- Component: Data ALU --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_alu
    generic (
      DADD_USE : boolean := true -- implement DADD instruction?
    );
    port (
      -- global control --
      clk_i  : in  std_ulogic; -- global clock, rising edge
      -- operands --
      reg_i  : in  std_ulogic_vector(15 downto 0); -- data from reg file
      mem_i  : in  std_ulogic_vector(15 downto 0); -- data from memory
      sreg_i : in  std_ulogic_vector(15 downto 0); -- current SR
      -- control --
      ctrl_i : in  std_ulogic_vector(ctrl_width_c-1 downto 0);
      -- results --
      data_o : out std_ulogic_vector(15 downto 0); -- result
      flag_o : out std_ulogic_vector(03 downto 0)  -- new ALU flags
    );
  end component;

  -- Component: Address Generator -----------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_addr_gen
    port (
      -- global control --
      clk_i      : in  std_ulogic; -- global clock, rising edge
      -- data input --
      reg_i      : in  std_ulogic_vector(15 downto 0); -- reg file input
      mem_i      : in  std_ulogic_vector(15 downto 0); -- memory input
      imm_i      : in  std_ulogic_vector(15 downto 0); -- branch offset
      irq_sel_i  : in  std_ulogic_vector(01 downto 0); -- IRQ vector
      -- control --
      ctrl_i     : in  std_ulogic_vector(ctrl_width_c-1 downto 0);
      -- data output --
      mem_addr_o : out std_ulogic_vector(15 downto 0); -- memory address
      dwb_o      : out std_ulogic_vector(15 downto 0)  -- data write back output
    );
  end component;

  -- Component: CPU core --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_cpu
    generic (
      DADD_USE    : boolean := true; -- implement DADD instruction?
      BOOTLD_USE  : boolean := true; -- implement and use bootloader?
      IMEM_AS_ROM : boolean := false -- implement IMEM as read-only memory?
    );
    port(
      -- global control --
      clk_i      : in  std_ulogic; -- global clock, rising edge
      rst_i      : in  std_ulogic; -- global reset, low-active, async
      -- memory interface --
      mem_rd_o   : out std_ulogic; -- memory read
      mem_imwe_o : out std_ulogic; -- allow writing to IMEM
      mem_wr_o   : out std_ulogic_vector(01 downto 0); -- memory write
      mem_addr_o : out std_ulogic_vector(15 downto 0); -- address
      mem_data_o : out std_ulogic_vector(15 downto 0); -- write data
      mem_data_i : in  std_ulogic_vector(15 downto 0); -- read data
      -- interrupt system --
      irq_i      : in  std_ulogic_vector(03 downto 0); -- interrupt requests
      irq_ack_o  : out std_ulogic_vector(03 downto 0)  -- IRQ acknowledge
    );
  end component;

  -- Component: Instruction Memory (ROM) ----------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_imem
    generic (
      IMEM_SIZE   : natural := 4*1024; -- internal IMEM size in bytes
      IMEM_AS_ROM : boolean := false;  -- implement IMEM as read-only memory?
      BOOTLD_USE  : boolean := true    -- implement and use bootloader?
    );
    port (
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      wren_i : in  std_ulogic_vector(01 downto 0); -- write enable
      upen_i : in  std_ulogic; -- update enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_i : in  std_ulogic_vector(15 downto 0); -- data in
      data_o : out std_ulogic_vector(15 downto 0)  -- data out
    );
  end component;

  -- Component: Data Memory (RAM) -----------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_dmem
    generic (
      DMEM_SIZE : natural := 2*1024 -- internal DMEM size in bytes
    );
    port (
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      wren_i : in  std_ulogic_vector(01 downto 0); -- write enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_i : in  std_ulogic_vector(15 downto 0); -- data in
      data_o : out std_ulogic_vector(15 downto 0)  -- data out
    );
  end component;

  -- Component: Bootloader ROM --------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_boot_rom
    port (
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_o : out std_ulogic_vector(15 downto 0)  -- data out
    );
  end component;

  -- Component: Multiplier/Divider ----------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_muldiv
    port (
      -- host access --
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      wren_i : in  std_ulogic; -- write enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_i : in  std_ulogic_vector(15 downto 0); -- data in
      data_o : out std_ulogic_vector(15 downto 0)  -- data out
    );
  end component;

  -- Component: 32bit Wishbone Interface ----------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_wb_interface
    port (
      -- host access --
      clk_i    : in  std_ulogic; -- global clock line
      rden_i   : in  std_ulogic; -- read enable
      wren_i   : in  std_ulogic; -- write enable
      addr_i   : in  std_ulogic_vector(15 downto 0); -- address
      data_i   : in  std_ulogic_vector(15 downto 0); -- data in
      data_o   : out std_ulogic_vector(15 downto 0); -- data out
      -- wishbone interface --
      wb_adr_o : out std_ulogic_vector(31 downto 0); -- address
      wb_dat_i : in  std_ulogic_vector(31 downto 0); -- read data
      wb_dat_o : out std_ulogic_vector(31 downto 0); -- write data
      wb_we_o  : out std_ulogic; -- read/write
      wb_sel_o : out std_ulogic_vector(03 downto 0); -- byte enable
      wb_stb_o : out std_ulogic; -- strobe
      wb_cyc_o : out std_ulogic; -- valid cycle
      wb_ack_i : in  std_ulogic  -- transfer acknowledge
    );
  end component;

  -- Component: UART ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_uart
    port (
      -- host access --
      clk_i       : in  std_ulogic; -- global clock line
      rden_i      : in  std_ulogic; -- read enable
      wren_i      : in  std_ulogic; -- write enable
      addr_i      : in  std_ulogic_vector(15 downto 0); -- address
      data_i      : in  std_ulogic_vector(15 downto 0); -- data in
      data_o      : out std_ulogic_vector(15 downto 0); -- data out
      -- clock generator --
      clkgen_en_o : out std_ulogic; -- enable clock generator
      clkgen_i    : in  std_ulogic_vector(07 downto 0);
      -- com lines --
      uart_txd_o  : out std_ulogic;
      uart_rxd_i  : in  std_ulogic;
      -- interrupts --
      uart_irq_o  : out std_ulogic  -- uart rx/tx interrupt
    );
  end component;

  -- Component: SPI -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_spi
    port (
      -- host access --
      clk_i       : in  std_ulogic; -- global clock line
      rden_i      : in  std_ulogic; -- read enable
      wren_i      : in  std_ulogic; -- write enable
      addr_i      : in  std_ulogic_vector(15 downto 0); -- address
      data_i      : in  std_ulogic_vector(15 downto 0); -- data in
      data_o      : out std_ulogic_vector(15 downto 0); -- data out
      -- clock generator --
      clkgen_en_o : out std_ulogic; -- enable clock generator
      clkgen_i    : in  std_ulogic_vector(07 downto 0);
      -- com lines --
      spi_sclk_o  : out std_ulogic; -- SPI serial clock
      spi_mosi_o  : out std_ulogic; -- SPI master out, slave in
      spi_miso_i  : in  std_ulogic; -- SPI master in, slave out
      spi_cs_o    : out std_ulogic_vector(07 downto 0); -- SPI CS 0..7
      -- interrupt --
      spi_irq_o   : out std_ulogic -- transmission done interrupt
    );
  end component;

  -- Component: GPIO ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_gpio
    port (
      -- host access --
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      wren_i : in  std_ulogic; -- write enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_i : in  std_ulogic_vector(15 downto 0); -- data in
      data_o : out std_ulogic_vector(15 downto 0); -- data out
      -- parallel io --
      gpio_o : out std_ulogic_vector(15 downto 0);
      gpio_i : in  std_ulogic_vector(15 downto 0);
      -- interrupt --
      irq_o  : out std_ulogic
    );
  end component;

  -- Component: High-Precision Timer --------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_timer
    port (
      -- host access --
      clk_i       : in  std_ulogic; -- global clock line
      rden_i      : in  std_ulogic; -- read enable
      wren_i      : in  std_ulogic; -- write enable
      addr_i      : in  std_ulogic_vector(15 downto 0); -- address
      data_i      : in  std_ulogic_vector(15 downto 0); -- data in
      data_o      : out std_ulogic_vector(15 downto 0); -- data out
      -- clock generator --
      clkgen_en_o : out std_ulogic; -- enable clock generator
      clkgen_i    : in  std_ulogic_vector(07 downto 0);
      -- interrupt --
      irq_o       : out std_ulogic  -- interrupt request
    );
  end component;

  -- Component: Watchdog Timer --------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_wdt
    port (
      -- host access --
      clk_i       : in  std_ulogic; -- global clock line
      rst_i       : in  std_ulogic; -- global (external) reset, low-active, use as async
      rden_i      : in  std_ulogic; -- read enable
      wren_i      : in  std_ulogic; -- write enable
      addr_i      : in  std_ulogic_vector(15 downto 0); -- address
      data_i      : in  std_ulogic_vector(15 downto 0); -- data in
      data_o      : out std_ulogic_vector(15 downto 0); -- data out
      -- clock generator --
      clkgen_en_o : out std_ulogic; -- enable clock generator
      clkgen_i    : in  std_ulogic_vector(07 downto 0);
      -- system reset --
      rst_o       :  out std_ulogic  -- timeout reset, low_active, use as async
    );
  end component;

  -- Component: CRC Module ------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_crc
    port (
      -- host access --
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      wren_i : in  std_ulogic; -- write enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_i : in  std_ulogic_vector(15 downto 0); -- data in
      data_o : out std_ulogic_vector(15 downto 0)  -- data out
    );
  end component;

  -- Component: Custom Functions Unit -------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_cfu
    port (
      -- host access --
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      wren_i : in  std_ulogic; -- write enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_i : in  std_ulogic_vector(15 downto 0); -- data in
      data_o : out std_ulogic_vector(15 downto 0)  -- data out
      -- custom IOs --
--    ...
    );
  end component;

  -- Component: PWM Controller --------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_pwm
    port (
      -- host access --
      clk_i       : in  std_ulogic; -- global clock line
      rden_i      : in  std_ulogic; -- read enable
      wren_i      : in  std_ulogic; -- write enable
      addr_i      : in  std_ulogic_vector(15 downto 0); -- address
      data_i      : in  std_ulogic_vector(15 downto 0); -- data in
      data_o      : out std_ulogic_vector(15 downto 0); -- data out
      -- clock generator --
      clkgen_en_o : out std_ulogic; -- enable clock generator
      clkgen_i    : in  std_ulogic_vector(07 downto 0);
      -- pwm output channels --
      pwm_o       : out std_ulogic_vector(02 downto 0)
    );
  end component;

  -- Component: Serial Two Wire Interfcae ---------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_twi
    port (
      -- host access --
      clk_i       : in  std_ulogic; -- global clock line
      rden_i      : in  std_ulogic; -- read enable
      wren_i      : in  std_ulogic; -- write enable
      addr_i      : in  std_ulogic_vector(15 downto 0); -- address
      data_i      : in  std_ulogic_vector(15 downto 0); -- data in
      data_o      : out std_ulogic_vector(15 downto 0); -- data out
      -- clock generator --
      clkgen_en_o : out std_ulogic; -- enable clock generator
      clkgen_i    : in  std_ulogic_vector(07 downto 0);
      -- com lines --
      twi_sda_io  : inout std_logic; -- serial data line
      twi_scl_io  : inout std_logic; -- serial clock line
      -- interrupt --
      twi_irq_o   : out std_ulogic -- transfer done IRQ
    );
  end component;

  -- Component: System Configuration --------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component neo430_sysconfig
    generic (
      -- general configuration --
      CLOCK_SPEED : natural := 100000000; -- main clock in Hz
      IMEM_SIZE   : natural := 4*1024; -- internal IMEM size in bytes
      DMEM_SIZE   : natural := 2*1024; -- internal DMEM size in bytes
      -- additional configuration --
      USER_CODE   : std_ulogic_vector(15 downto 0) := x"0000"; -- custom user code
      -- module configuration --
      DADD_USE    : boolean := true; -- implement DADD instruction?
      MULDIV_USE  : boolean := true; -- implement multiplier/divider unit?
      WB32_USE    : boolean := true; -- implement WB32 unit?
      WDT_USE     : boolean := true; -- implement WDT?
      GPIO_USE    : boolean := true; -- implement GPIO unit?
      TIMER_USE   : boolean := true; -- implement timer?
      UART_USE    : boolean := true; -- implement UART?
      CRC_USE     : boolean := true; -- implement CRC unit?
      CFU_USE     : boolean := true; -- implement CF unit?
      PWM_USE     : boolean := true; -- implement PWM controller?
      TWI_USE     : boolean := true; -- implement TWI?
      SPI_USE     : boolean := true; -- implement SPI?
      -- boot configuration --
      BOOTLD_USE  : boolean := true; -- implement and use bootloader?
      IMEM_AS_ROM : boolean := false -- implement IMEM as read-only memory?
    );
    port (
      clk_i  : in  std_ulogic; -- global clock line
      rden_i : in  std_ulogic; -- read enable
      wren_i : in  std_ulogic; -- write enable
      addr_i : in  std_ulogic_vector(15 downto 0); -- address
      data_i : in  std_ulogic_vector(15 downto 0); -- data in
      data_o : out std_ulogic_vector(15 downto 0)  -- data out
    );
  end component;

end neo430_package;

package body neo430_package is

  -- Function: Minimal required bit width ---------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function index_size_f(input : natural) return natural is
  begin
    for i in 0 to natural'high loop
      if (2**i >= input) then
        return i;
      end if;
    end loop; -- i
    return 0;
  end function index_size_f;

  -- Function: Test is value (encoded with a certain bit width) is a power of 2 -------------
  -- -------------------------------------------------------------------------------------------
  function is_power_of_two_f(num : natural; bit_width : natural) return boolean is
  begin
    for i in 0 to bit_width loop
      if ((2**i) = num) then
        return true;
      end if;
    end loop; -- i
    return false;
  end function is_power_of_two_f;

  -- Function: Bit reversal -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function bit_reversal_f(input : std_ulogic_vector) return std_ulogic_vector is
    variable output_v : std_ulogic_vector(input'range);
  begin
    for i in 0 to input'length-1 loop
      output_v(input'length-i-1) := input(i);
    end loop; -- i
    return output_v;
  end function bit_reversal_f;

  -- Function: Count number of set bits (aka population count) ------------------------------
  -- -------------------------------------------------------------------------------------------
  function set_bits_f(input : std_ulogic_vector) return natural is
    variable cnt_v : natural range 0 to input'length-1;
  begin
    cnt_v := 0;
    for i in input'length-1 downto 0 loop
      if (input(i) = '1') then
        cnt_v := cnt_v + 1;
      end if;
    end loop; -- i
    return cnt_v;
  end function set_bits_f;

  -- Function: Count leading zeros ----------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function leading_zeros_f(input : std_ulogic_vector) return natural is
    variable cnt_v : natural range 0 to input'length;
  begin
    cnt_v := 0;
    for i in input'length-1 downto 0 loop
      if (input(i) = '0') then
        cnt_v := cnt_v + 1;
      else
        exit;
      end if;
    end loop; -- i
    return cnt_v;
  end function leading_zeros_f;

  -- Function: Conditional select natural ---------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function cond_sel_natural_f(cond : boolean; val_t : natural; val_f : natural) return natural is
  begin
    if (cond = true) then
      return val_t;
    else
      return val_f;
    end if;
  end function cond_sel_natural_f;

  -- Function: Conditional select std_ulogic_vector -----------------------------------------
  -- -------------------------------------------------------------------------------------------
  function cond_sel_stdulogicvector_f(cond : boolean; val_t : std_ulogic_vector; val_f : std_ulogic_vector) return std_ulogic_vector is
  begin
    if (cond = true) then
      return val_t;
    else
      return val_f;
    end if;
  end function cond_sel_stdulogicvector_f;

  -- Function: Convert BOOL to STD_ULOGIC ---------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function bool_to_ulogic_f(cond : boolean) return std_ulogic is
  begin
    if (cond = true) then
      return '1';
    else
      return '0';
    end if;
  end function bool_to_ulogic_f;

  -- Function: Binary to Gray ---------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function bin_to_gray_f(input : std_ulogic_vector) return std_ulogic_vector is
    variable output_v : std_ulogic_vector(input'range);
  begin
    output_v(input'length-1) := input(input'length-1); -- keep MSB
    for i in input'length-2 downto 0 loop
      output_v(i) := input(i) xor input(i+1);
    end loop; -- i
    return output_v;
  end function bin_to_gray_f;

  -- Function: Gray to Binary ---------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function gray_to_bin_f(input : std_ulogic_vector) return std_ulogic_vector is
    variable output_v : std_ulogic_vector(input'range);
  begin
    output_v(input'length-1) := input(input'length-1); -- keep MSB
    for i in input'length-2 downto 0 loop
      output_v(i) := output_v(i+1) xor input(i);
    end loop; -- i
    return output_v;
  end function gray_to_bin_f;

  -- Function: Integer (4-bit) to hex char --------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function int_to_hexchar_f(input : integer) return character is
    variable output_v : character;
  begin
    case (input) is
      when  0 => output_v := '0';
      when  1 => output_v := '1';
      when  2 => output_v := '2';
      when  3 => output_v := '3';
      when  4 => output_v := '4';
      when  5 => output_v := '5';
      when  6 => output_v := '6';
      when  7 => output_v := '7';
      when  8 => output_v := '8';
      when  9 => output_v := '9';
      when 10 => output_v := 'A';
      when 11 => output_v := 'B';
      when 12 => output_v := 'C';
      when 13 => output_v := 'D';
      when 14 => output_v := 'E';
      when 15 => output_v := 'F';
      when others => output_v := '?';
    end case;
    return output_v;
  end function int_to_hexchar_f;

  -- Function: 4-bit BCD addition with carry ------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function bcd_add4_f(a : std_ulogic_vector; b : std_ulogic_vector; c : std_ulogic) return std_ulogic_vector is
    variable tmp_v : unsigned(4 downto 0);
    variable res_v : unsigned(3 downto 0);
    variable cry_v : std_ulogic;
  begin
    tmp_v := ('0' & unsigned(a)) + ('0' & unsigned(b)) + ("0000" & c); 
    if (tmp_v > 9) then
      res_v := resize((tmp_v + "00110"), 4);
      cry_v := '1';
    else
      res_v := tmp_v(3 downto 0);
      cry_v := '0';
    end if;
    return std_ulogic_vector(cry_v & res_v);
  end function bcd_add4_f;

  -- Function: OR all bits ------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function or_all_f(a : std_ulogic_vector) return std_ulogic is
    variable tmp_v : std_ulogic;
  begin
    tmp_v := a(a'low);
    for i in a'low+1 to a'high loop
      tmp_v := tmp_v or a(i);
    end loop; -- i
    return tmp_v;
  end function or_all_f;

  -- Function: AND all bits -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function and_all_f(a : std_ulogic_vector) return std_ulogic is
    variable tmp_v : std_ulogic;
  begin
    tmp_v := a(a'low);
    for i in a'low+1 to a'high loop
      tmp_v := tmp_v and a(i);
    end loop; -- i
    return tmp_v;
  end function and_all_f;

  -- Function: XOR all bits -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  function xor_all_f(a : std_ulogic_vector) return std_ulogic is
    variable tmp_v : std_ulogic;
  begin
    tmp_v := a(a'low);
    for i in a'low+1 to a'high loop
      tmp_v := tmp_v xor a(i);
    end loop; -- i
    return tmp_v;
  end function xor_all_f;


end neo430_package;

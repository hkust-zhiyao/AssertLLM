---------------------------------------------------------------------
-- LXP32C CPU top-level module (C-series, with instruction cache)
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- This version uses Wishbone B3 interface for the instruction bus
-- (IBUS). It is designed for high-latency program memory, such as
-- external SDRAM chips.
--
-- Parameters:
--     DBUS_RMW:           Use RMW cycle instead of SEL_O() signal
--                         for byte-granular access to data bus
--     DIVIDER_EN:         enable divider
--     IBUS_BURST_SIZE:    size of the burst
--     IBUS_PREFETCH_SIZE: initiate read burst if number of words
--                         left in the buffer is less than specified
--     MUL_ARCH:           multiplier architecture ("dsp", "opt"
--                         or "seq")
--     START_ADDR:         address in program memory where execution
--                         starts
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lxp32c_top is
	generic(
		DBUS_RMW: boolean:=false;
		DIVIDER_EN: boolean:=true;
		IBUS_BURST_SIZE: integer:=16;
		IBUS_PREFETCH_SIZE: integer:=32;
		MUL_ARCH: string:="dsp";
		START_ADDR: std_logic_vector(31 downto 0):=(others=>'0')
	);
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		ibus_cyc_o: out std_logic;
		ibus_stb_o: out std_logic;
		ibus_cti_o: out std_logic_vector(2 downto 0);
		ibus_bte_o: out std_logic_vector(1 downto 0);
		ibus_ack_i: in std_logic;
		ibus_adr_o: out std_logic_vector(29 downto 0);
		ibus_dat_i: in std_logic_vector(31 downto 0);
		
		dbus_cyc_o: out std_logic;
		dbus_stb_o: out std_logic;
		dbus_we_o: out std_logic;
		dbus_sel_o: out std_logic_vector(3 downto 0);
		dbus_ack_i: in std_logic;
		dbus_adr_o: out std_logic_vector(31 downto 2);
		dbus_dat_o: out std_logic_vector(31 downto 0);
		dbus_dat_i: in std_logic_vector(31 downto 0);
		
		irq_i: in std_logic_vector(7 downto 0)
	);
end entity;

architecture rtl of lxp32c_top is

signal lli_re: std_logic;
signal lli_adr: std_logic_vector(29 downto 0);
signal lli_dat: std_logic_vector(31 downto 0);
signal lli_busy: std_logic;

begin

cpu_inst: entity work.lxp32_cpu(rtl)
	generic map(
		DBUS_RMW=>DBUS_RMW,
		DIVIDER_EN=>DIVIDER_EN,
		MUL_ARCH=>MUL_ARCH,
		START_ADDR=>START_ADDR
	)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		lli_re_o=>lli_re,
		lli_adr_o=>lli_adr,
		lli_dat_i=>lli_dat,
		lli_busy_i=>lli_busy,
		
		dbus_cyc_o=>dbus_cyc_o,
		dbus_stb_o=>dbus_stb_o,
		dbus_we_o=>dbus_we_o,
		dbus_sel_o=>dbus_sel_o,
		dbus_ack_i=>dbus_ack_i,
		dbus_adr_o=>dbus_adr_o,
		dbus_dat_o=>dbus_dat_o,
		dbus_dat_i=>dbus_dat_i,
		
		irq_i=>irq_i
	);

icache_inst: entity work.lxp32_icache(rtl)
	generic map(
		BURST_SIZE=>IBUS_BURST_SIZE,
		PREFETCH_SIZE=>IBUS_PREFETCH_SIZE
	)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		lli_re_i=>lli_re,
		lli_adr_i=>lli_adr,
		lli_dat_o=>lli_dat,
		lli_busy_o=>lli_busy,
		
		wbm_cyc_o=>ibus_cyc_o,
		wbm_stb_o=>ibus_stb_o,
		wbm_cti_o=>ibus_cti_o,
		wbm_bte_o=>ibus_bte_o,
		wbm_ack_i=>ibus_ack_i,
		wbm_adr_o=>ibus_adr_o,
		wbm_dat_i=>ibus_dat_i
	);

end architecture;

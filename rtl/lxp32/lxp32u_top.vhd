---------------------------------------------------------------------
-- LXP32U CPU top-level module (U-series, without instruction cache)
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- This version uses a Low Latency Interface for the instruction bus
-- (IBUS). It is designed for low-latency slaves such as on-chip
-- RAM blocks.
--
-- Parameters:
--     DBUS_RMW:           Use RMW cycle instead of SEL_O() signal
--                         for byte-granular access to data bus
--     DIVIDER_EN:         enable divider
--     MUL_ARCH:           multiplier architecture ("dsp", "opt"
--                         or "seq")
--     START_ADDR:         address in program memory where execution
--                         starts
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lxp32u_top is
	generic(
		DBUS_RMW: boolean:=false;
		DIVIDER_EN: boolean:=true;
		MUL_ARCH: string:="dsp";
		START_ADDR: std_logic_vector(31 downto 0):=(others=>'0')
	);
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		lli_re_o: out std_logic;
		lli_adr_o: out std_logic_vector(29 downto 0);
		lli_dat_i: in std_logic_vector(31 downto 0);
		lli_busy_i: in std_logic;
		
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

architecture rtl of lxp32u_top is

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
		
		lli_re_o=>lli_re_o,
		lli_adr_o=>lli_adr_o,
		lli_dat_i=>lli_dat_i,
		lli_busy_i=>lli_busy_i,
		
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

end architecture;

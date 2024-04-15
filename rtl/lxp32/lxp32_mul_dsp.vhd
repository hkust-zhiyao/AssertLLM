---------------------------------------------------------------------
-- DSP multiplier
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- This multiplier is designed for technologies that provide fast
-- 16x16 multipliers, including most modern FPGA families. One
-- multiplication takes 2 cycles.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_mul_dsp is
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		ce_i: in std_logic;
		op1_i: in std_logic_vector(31 downto 0);
		op2_i: in std_logic_vector(31 downto 0);
		ce_o: out std_logic;
		result_o: out std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_mul_dsp is

signal pp00: std_logic_vector(31 downto 0);
signal pp01: std_logic_vector(31 downto 0);
signal pp10: std_logic_vector(31 downto 0);

signal product: unsigned(31 downto 0);

signal ceo: std_logic:='0';

begin

mul00_inst: entity work.lxp32_mul16x16
	port map(
		clk_i=>clk_i,
		a_i=>op1_i(15 downto 0),
		b_i=>op2_i(15 downto 0),
		p_o=>pp00
	);

mul01_inst: entity work.lxp32_mul16x16
	port map(
		clk_i=>clk_i,
		a_i=>op1_i(15 downto 0),
		b_i=>op2_i(31 downto 16),
		p_o=>pp01
	);

mul10_inst: entity work.lxp32_mul16x16
	port map(
		clk_i=>clk_i,
		a_i=>op1_i(31 downto 16),
		b_i=>op2_i(15 downto 0),
		p_o=>pp10
	);

product(31 downto 16)<=unsigned(pp00(31 downto 16))+unsigned(pp01(15 downto 0))+unsigned(pp10(15 downto 0));
product(15 downto 0)<=unsigned(pp00(15 downto 0));
result_o<=std_logic_vector(product);

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			ceo<='0';
		else
			ceo<=ce_i;
		end if;
	end if;
end process;

ce_o<=ceo;

end architecture;

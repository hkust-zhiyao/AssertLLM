---------------------------------------------------------------------
-- Complementor
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- Computes a 2's complement of its input. Used as an auxiliary
-- unit in the divider.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_compl is
	port(
		clk_i: in std_logic;
		compl_i: in std_logic;
		d_i: in std_logic_vector(31 downto 0);
		d_o: out std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_compl is

signal d_prepared: unsigned(d_i'range);
signal sum_low: unsigned(16 downto 0);
signal d_high: unsigned(15 downto 0);
signal sum_high: unsigned(15 downto 0);

begin

d_prepared_gen: for i in d_prepared'range generate
	d_prepared(i)<=d_i(i) xor compl_i;
end generate;

process (clk_i) is
begin
	if rising_edge(clk_i) then
		sum_low<=("0"&d_prepared(15 downto 0))+(to_unsigned(0,16)&compl_i);
		d_high<=d_prepared(31 downto 16);
	end if;
end process;

sum_high<=d_high+(to_unsigned(0,15)&sum_low(sum_low'high));

d_o<=std_logic_vector(sum_high&sum_low(15 downto 0));

end architecture;

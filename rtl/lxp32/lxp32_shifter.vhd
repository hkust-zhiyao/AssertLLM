---------------------------------------------------------------------
-- Barrel shifter
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- Performs logical (unsigned) and arithmetic (signed) shifts
-- in both directions. Pipeline latency: 1 cycle.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lxp32_shifter is
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		ce_i: in std_logic;
		d_i: in std_logic_vector(31 downto 0);
		s_i: in std_logic_vector(4 downto 0);
		right_i: in std_logic;
		sig_i: in std_logic;
		ce_o: out std_logic;
		d_o: out std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_shifter is

signal data: std_logic_vector(d_i'range);
signal data_shifted: std_logic_vector(d_i'range);

signal fill: std_logic; -- 0 for unsigned shifts, sign bit for signed ones
signal fill_v: std_logic_vector(3 downto 0);

type cascades_type is array (4 downto 0) of std_logic_vector(d_i'range);
signal cascades: cascades_type;

signal stage2_data: std_logic_vector(d_i'range);
signal stage2_s: std_logic_vector(s_i'range);
signal stage2_fill: std_logic;
signal stage2_fill_v: std_logic_vector(15 downto 0);
signal stage2_right: std_logic;

signal ceo: std_logic:='0';

begin

-- Internally, data are shifted in left direction. For right shifts
-- we reverse the argument's bit order

data_gen: for i in data'range generate
	data(i)<=d_i(i) when right_i='0' else d_i(d_i'high-i);
end generate;

-- A set of cascaded shifters shifting by powers of two

fill<=sig_i and data(0);
fill_v<=(others=>fill);

cascades(0)<=data(30 downto 0)&fill_v(0) when s_i(0)='1' else data;
cascades(1)<=cascades(0)(29 downto 0)&fill_v(1 downto 0) when s_i(1)='1' else cascades(0);
cascades(2)<=cascades(1)(27 downto 0)&fill_v(3 downto 0) when s_i(2)='1' else cascades(1);

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			ceo<='0';
			stage2_data<=(others=>'-');
			stage2_s<=(others=>'-');
			stage2_fill<='-';
			stage2_right<='-';
		else
			ceo<=ce_i;
			stage2_data<=cascades(2);
			stage2_s<=s_i;
			stage2_fill<=fill;
			stage2_right<=right_i;
		end if;
	end if;
end process;

stage2_fill_v<=(others=>stage2_fill);

cascades(3)<=stage2_data(23 downto 0)&stage2_fill_v(7 downto 0) when stage2_s(3)='1' else stage2_data;
cascades(4)<=cascades(3)(15 downto 0)&stage2_fill_v(15 downto 0) when stage2_s(4)='1' else cascades(3);

-- Reverse bit order back, if needed

data_shifted_gen: for i in data_shifted'range generate
	data_shifted(i)<=cascades(4)(i) when stage2_right='0' else cascades(4)(cascades(4)'high-i);
end generate;

d_o<=data_shifted;
ce_o<=ceo;

end architecture;

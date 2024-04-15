---------------------------------------------------------------------
-- Divider
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- Based on the NRD (Non Restoring Division) algorithm. Takes
-- 36 cycles to calculate quotient (37 for remainder).
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_divider is
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		ce_i: in std_logic;
		op1_i: in std_logic_vector(31 downto 0);
		op2_i: in std_logic_vector(31 downto 0);
		signed_i: in std_logic;
		rem_i: in std_logic;
		ce_o: out std_logic;
		result_o: out std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_divider is

-- Complementor signals

signal compl_inv: std_logic;
signal compl_mux: std_logic_vector(31 downto 0);
signal compl_out: std_logic_vector(31 downto 0);

signal inv_res: std_logic;

-- Divider FSM signals

signal fsm_ce: std_logic:='0';

signal dividend: unsigned(31 downto 0);
signal divisor: unsigned(32 downto 0);
signal want_remainder: std_logic;

signal partial_remainder: unsigned(32 downto 0);
signal addend: unsigned(32 downto 0);
signal sum: unsigned(32 downto 0);
signal sum_positive: std_logic;
signal sum_subtract: std_logic;

signal cnt: integer range 0 to 34:=0;

signal ceo: std_logic:='0';

-- Output restoration signals

signal remainder_corrector: unsigned(31 downto 0);
signal remainder_corrector_1: std_logic;
signal remainder_pos: unsigned(31 downto 0);
signal result_pos: unsigned(31 downto 0);

begin

compl_inv<=op1_i(31) and signed_i when ce_i='1' else inv_res;
compl_mux<=op1_i when ce_i='1' else std_logic_vector(result_pos);

compl_op1_inst: entity work.lxp32_compl(rtl)
	port map(
		clk_i=>clk_i,
		compl_i=>compl_inv,
		d_i=>compl_mux,
		d_o=>compl_out
	);

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			fsm_ce<='0';
			want_remainder<='-';
			inv_res<='-';
		else
			fsm_ce<=ce_i;
			if ce_i='1' then
				want_remainder<=rem_i;
				if rem_i='1' then
					inv_res<=op1_i(31) and signed_i;
				else
					inv_res<=(op1_i(31) xor op2_i(31)) and signed_i;
				end if;
			end if;
		end if;
	end if;
end process;

-- Main adder/subtractor

addend_gen: for i in addend'range generate
	addend(i)<=divisor(i) xor sum_subtract;
end generate;

sum<=partial_remainder+addend+(to_unsigned(0,32)&sum_subtract);
sum_positive<=not sum(32);

-- Divider state machine

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			cnt<=0;
			ceo<='0';
			divisor<=(others=>'-');
			dividend<=(others=>'-');
			partial_remainder<=(others=>'-');
			sum_subtract<='-';
		else
			if cnt=1 then
				ceo<='1';
			else
				ceo<='0';
			end if;
			
			if ce_i='1' then
				divisor(31 downto 0)<=unsigned(op2_i);
				divisor(32)<=op2_i(31) and signed_i;
			end if;
			
			if fsm_ce='1' then
				dividend<=unsigned(compl_out(30 downto 0)&"0");
				partial_remainder<=to_unsigned(0,32)&compl_out(31);
				sum_subtract<=not divisor(32);
				if want_remainder='1' then
					cnt<=34;
				else
					cnt<=33;
				end if;
			else
				partial_remainder<=sum(31 downto 0)&dividend(31);
				sum_subtract<=sum_positive xor divisor(32);
				dividend<=dividend(30 downto 0)&sum_positive;
				if cnt>0 then
					cnt<=cnt-1;
				end if;
			end if;
		end if;
	end if;
end process;

-- Output restoration circuit

process (clk_i) is
begin
	if rising_edge(clk_i) then
		for i in remainder_corrector'range loop
			remainder_corrector(i)<=(divisor(i) xor divisor(32)) and not sum_positive;
		end loop;
		remainder_corrector_1<=divisor(32) and not sum_positive;
		remainder_pos<=partial_remainder(32 downto 1)+remainder_corrector+
			(to_unsigned(0,31)&remainder_corrector_1);
	end if;
end process;

result_pos<=remainder_pos when want_remainder='1' else dividend;

result_o<=compl_out;
ce_o<=ceo;

end architecture;

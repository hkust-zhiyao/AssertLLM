---------------------------------------------------------------------
-- Sequential multiplier
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- The smallest possible multiplier. Implemented using
-- an accumulator. One multiplication takes 34 cycles.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_mul_seq is
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

architecture rtl of lxp32_mul_seq is

signal reg1: unsigned(op1_i'range);
signal reg2: unsigned(op2_i'range);
signal pp: unsigned(31 downto 0);
signal acc_sum: unsigned(31 downto 0);
signal cnt: integer range 0 to 32:=0;
signal ceo: std_logic:='0';

begin

pp<=reg1 when reg2(0)='1' else (others=>'0');

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			ceo<='0';
			cnt<=0;
			reg1<=(others=>'-');
			reg2<=(others=>'-');
			acc_sum<=(others=>'-');
		else
			if cnt=1 then
				ceo<='1';
			else
				ceo<='0';
			end if;
			
			if ce_i='1' then
				cnt<=32;
				reg1<=unsigned(op1_i);
				reg2<=unsigned(op2_i);
				acc_sum<=(others=>'0');
			else
				acc_sum<=acc_sum+pp;
				reg1<=reg1(reg1'high-1 downto 0)&"0";
				reg2<="0"&reg2(reg2'high downto 1);
				if cnt>0 then
					cnt<=cnt-1;
				end if;
			end if;
		end if;
	end if;
end process;

result_o<=std_logic_vector(acc_sum);
ce_o<=ceo;

end architecture;

---------------------------------------------------------------------
-- Optimized multiplier
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- This multiplier is designed for technologies that don't provide
-- fast 16x16 multipliers. One multiplication takes 6 cycles.
--
-- The multiplication algorithm is based on carry-save accumulation
-- of partial products.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_mul_opt is
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

architecture rtl of lxp32_mul_opt is

function csa_sum(a: unsigned; b: unsigned; c: unsigned; n: integer) return unsigned is
	variable r: unsigned(n-1 downto 0);
begin
	for i in r'range loop
		r(i):=a(i) xor b(i) xor c(i);
	end loop;
	return r;
end function;

function csa_carry(a: unsigned; b: unsigned; c: unsigned; n: integer) return unsigned is
	variable r: unsigned(n-1 downto 0);
begin
	for i in r'range loop
		r(i):=(a(i) and b(i)) or (a(i) and c(i)) or (b(i) and c(i));
	end loop;
	return r&"0";
end function;

signal reg1: unsigned(op1_i'range);
signal reg2: unsigned(op2_i'range);

type pp_type is array (7 downto 0) of unsigned(31 downto 0);
signal pp: pp_type;

type pp_sum_type is array (7 downto 0) of unsigned(31 downto 0);
signal pp_sum: pp_sum_type;

type pp_carry_type is array (7 downto 0) of unsigned(32 downto 0);
signal pp_carry: pp_carry_type;

signal acc_sum: unsigned(31 downto 0);
signal acc_carry: unsigned(31 downto 0);

signal cnt: integer range 0 to 4:=0;

signal result: std_logic_vector(result_o'range);
signal ceo: std_logic:='0';

begin

-- Calculate 8 partial products in parallel

pp_gen: for i in pp'range generate
	pp(i)<=shift_left(reg1,i) when reg2(i)='1' else (others=>'0');
end generate;

-- Add partial products to the accumulator using carry-save adder tree

pp_sum(0)<=csa_sum(pp(0),pp(1),pp(2),32);
pp_carry(0)<=csa_carry(pp(0),pp(1),pp(2),32);

pp_sum(1)<=csa_sum(pp(3),pp(4),pp(5),32);
pp_carry(1)<=csa_carry(pp(3),pp(4),pp(5),32);

pp_sum(2)<=csa_sum(pp(6),pp(7),acc_sum,32);
pp_carry(2)<=csa_carry(pp(6),pp(7),acc_sum,32);

pp_sum(3)<=csa_sum(pp_sum(0),pp_carry(0),pp_sum(1),32);
pp_carry(3)<=csa_carry(pp_sum(0),pp_carry(0),pp_sum(1),32);

pp_sum(4)<=csa_sum(pp_carry(1),pp_sum(2),pp_carry(2),32);
pp_carry(4)<=csa_carry(pp_carry(1),pp_sum(2),pp_carry(2),32);

pp_sum(5)<=csa_sum(pp_sum(3),pp_carry(3),pp_sum(4),32);
pp_carry(5)<=csa_carry(pp_sum(3),pp_carry(3),pp_sum(4),32);

pp_sum(6)<=csa_sum(pp_sum(5),pp_carry(5),pp_carry(4),32);
pp_carry(6)<=csa_carry(pp_sum(5),pp_carry(5),pp_carry(4),32);

pp_sum(7)<=csa_sum(pp_sum(6),pp_carry(6),acc_carry,32);
pp_carry(7)<=csa_carry(pp_sum(6),pp_carry(6),acc_carry,32);

-- Multiplier state machine

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			ceo<='0';
			cnt<=0;
			reg1<=(others=>'-');
			reg2<=(others=>'-');
			acc_sum<=(others=>'-');
			acc_carry<=(others=>'-');
		else
			if cnt=1 then
				ceo<='1';
			else
				ceo<='0';
			end if;
			
			if ce_i='1' then
				cnt<=4;
				reg1<=unsigned(op1_i);
				reg2<=unsigned(op2_i);
				acc_sum<=(others=>'0');
				acc_carry<=(others=>'0');
			else
				acc_sum<=pp_sum(7);
				acc_carry<=pp_carry(7)(acc_carry'range);
				reg1<=reg1(reg1'high-8 downto 0)&X"00";
				reg2<=X"00"&reg2(reg2'high downto 8);
				if cnt>0 then
					cnt<=cnt-1;
				end if;
			end if;
		end if;
	end if;
end process;

result<=std_logic_vector(acc_sum+acc_carry);

result_o<=result;
ce_o<=ceo;

-- A simulation-time multiplication check

-- synthesis translate_off

process (clk_i) is
	variable p: unsigned(op1_i'length+op2_i'length-1 downto 0);
begin
	if rising_edge(clk_i) then
		if ce_i='1' then
			p:=unsigned(op1_i)*unsigned(op2_i);
		elsif ceo='1' then
			assert result=std_logic_vector(p(result'range))
				report "Incorrect multiplication result"
				severity failure;
		end if;
	end if;
end process;

-- synthesis translate_on

end architecture;

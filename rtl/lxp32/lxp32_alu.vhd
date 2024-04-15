---------------------------------------------------------------------
-- Arithmetic logic unit
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- Performs arithmetic and logic operations.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_alu is
	generic(
		DIVIDER_EN: boolean;
		MUL_ARCH: string
	);
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		valid_i: in std_logic;
		
		cmd_signed_i: in std_logic;
		cmd_addsub_i: in std_logic;
		cmd_mul_i: in std_logic;
		cmd_div_i: in std_logic;
		cmd_div_mod_i: in std_logic;
		cmd_cmp_i: in std_logic;
		cmd_negate_op2_i: in std_logic;
		cmd_and_i: in std_logic;
		cmd_xor_i: in std_logic;
		cmd_shift_i: in std_logic;
		cmd_shift_right_i: in std_logic;
		
		op1_i: in std_logic_vector(31 downto 0);
		op2_i: in std_logic_vector(31 downto 0);
		
		result_o: out std_logic_vector(31 downto 0);
		
		cmp_eq_o: out std_logic;
		cmp_ug_o: out std_logic;
		cmp_sg_o: out std_logic;
		
		we_o: out std_logic;
		busy_o: out std_logic
	);
end entity;

architecture rtl of lxp32_alu is

signal addend1: unsigned(31 downto 0);
signal addend2: unsigned(31 downto 0);
signal adder_result: unsigned(32 downto 0);
signal adder_we: std_logic;

signal cmp_eq: std_logic;
signal cmp_carry: std_logic;
signal cmp_s1: std_logic;
signal cmp_s2: std_logic;

signal logic_result: std_logic_vector(31 downto 0);
signal logic_we: std_logic;

signal mul_result: std_logic_vector(31 downto 0);
signal mul_ce: std_logic;
signal mul_we: std_logic;

signal div_result: std_logic_vector(31 downto 0);
signal div_ce: std_logic;
signal div_we: std_logic;

signal shift_result: std_logic_vector(31 downto 0);
signal shift_ce: std_logic;
signal shift_we: std_logic;

signal result_mux: std_logic_vector(31 downto 0);
signal result_we: std_logic;

signal busy: std_logic:='0';

begin

assert MUL_ARCH="dsp" or MUL_ARCH="seq" or MUL_ARCH="opt"
	report "Invalid MUL_ARCH generic value: dsp, opt or seq expected"
	severity failure;

-- Add/subtract

addend1<=unsigned(op1_i);

addend2_gen: for i in addend2'range generate
	addend2(i)<=op2_i(i) xor cmd_negate_op2_i;
end generate;

adder_result<=("0"&addend1)+("0"&addend2)+(to_unsigned(0,adder_result'length-1)&cmd_negate_op2_i);
adder_we<=cmd_addsub_i and valid_i;

-- Comparator (needs cmd_negate_op2_i to work correctly)

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if valid_i='1' and cmd_cmp_i='1' then
			if op1_i=op2_i then
				cmp_eq<='1';
			else
				cmp_eq<='0';
			end if;
			
			cmp_carry<=adder_result(adder_result'high);
			cmp_s1<=op1_i(op1_i'high);
			cmp_s2<=op2_i(op2_i'high);
		end if;
	end if;
end process;

cmp_eq_o<=cmp_eq;
cmp_ug_o<=cmp_carry and not cmp_eq;
cmp_sg_o<=((cmp_s1 and cmp_s2 and cmp_carry) or
	(not cmp_s1 and not cmp_s2 and cmp_carry) or
	(not cmp_s1 and cmp_s2)) and not cmp_eq;

-- Bitwise operations (and, or, xor)
-- Note: (a or b) = (a and b) or (a xor b)

logic_result_gen: for i in logic_result'range generate
	logic_result(i)<=((op1_i(i) and op2_i(i)) and cmd_and_i) or
		((op1_i(i) xor op2_i(i)) and cmd_xor_i);
end generate;

logic_we<=(cmd_and_i or cmd_xor_i) and valid_i;

-- Multiplier

mul_ce<=cmd_mul_i and valid_i;

gen_mul_dsp: if MUL_ARCH="dsp" generate
	mul_inst: entity work.lxp32_mul_dsp(rtl)
		port map(
			clk_i=>clk_i,
			rst_i=>rst_i,
			ce_i=>mul_ce,
			op1_i=>op1_i,
			op2_i=>op2_i,
			ce_o=>mul_we,
			result_o=>mul_result
		);
end generate;

gen_mul_opt: if MUL_ARCH="opt" generate
	mul_inst: entity work.lxp32_mul_opt(rtl)
		port map(
			clk_i=>clk_i,
			rst_i=>rst_i,
			ce_i=>mul_ce,
			op1_i=>op1_i,
			op2_i=>op2_i,
			ce_o=>mul_we,
			result_o=>mul_result
		);
end generate;

gen_mul_seq: if MUL_ARCH="seq" generate
	mul_inst: entity work.lxp32_mul_seq(rtl)
		port map(
			clk_i=>clk_i,
			rst_i=>rst_i,
			ce_i=>mul_ce,
			op1_i=>op1_i,
			op2_i=>op2_i,
			ce_o=>mul_we,
			result_o=>mul_result
		);
end generate;

-- Divider

div_ce<=cmd_div_i and valid_i;

gen_divider: if DIVIDER_EN generate
	divider_inst: entity work.lxp32_divider(rtl)
		port map(
			clk_i=>clk_i,
			rst_i=>rst_i,
			ce_i=>div_ce,
			op1_i=>op1_i,
			op2_i=>op2_i,
			signed_i=>cmd_signed_i,
			rem_i=>cmd_div_mod_i,
			ce_o=>div_we,
			result_o=>div_result
		);
end generate;

gen_no_divider: if not DIVIDER_EN generate
	div_we<=div_ce;
	div_result<=(others=>'0');
end generate;

-- Shifter

shift_ce<=cmd_shift_i and valid_i;

shifter_inst: entity work.lxp32_shifter(rtl)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		ce_i=>shift_ce,
		d_i=>op1_i,
		s_i=>op2_i(4 downto 0),
		right_i=>cmd_shift_right_i,
		sig_i=>cmd_signed_i,
		ce_o=>shift_we,
		d_o=>shift_result
	);

-- Result multiplexer

result_mux_gen: for i in result_mux'range generate
	result_mux(i)<=(adder_result(i) and adder_we) or
		(logic_result(i) and logic_we) or
		(mul_result(i) and mul_we) or
		(div_result(i) and div_we) or
		(shift_result(i) and shift_we);
end generate;

result_o<=result_mux;

result_we<=adder_we or logic_we or mul_we or div_we or shift_we;
we_o<=result_we;

-- Pipeline control

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' or result_we='1' then
			busy<='0';
		elsif shift_ce='1' or mul_ce='1' or div_ce='1' then
			busy<='1';
		end if;
	end if;
end process;

busy_o<=busy;

end architecture;

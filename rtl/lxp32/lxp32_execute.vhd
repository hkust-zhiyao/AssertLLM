---------------------------------------------------------------------
-- Execution unit
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- The third stage of the LXP32 pipeline.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lxp32_execute is
	generic(
		DBUS_RMW: boolean;
		DIVIDER_EN: boolean;
		MUL_ARCH: string
	);
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		cmd_loadop3_i: in std_logic;
		cmd_signed_i: in std_logic;
		cmd_dbus_i: in std_logic;
		cmd_dbus_store_i: in std_logic;
		cmd_dbus_byte_i: in std_logic;
		cmd_addsub_i: in std_logic;
		cmd_mul_i: in std_logic;
		cmd_div_i: in std_logic;
		cmd_div_mod_i: in std_logic;
		cmd_cmp_i: in std_logic;
		cmd_jump_i: in std_logic;
		cmd_negate_op2_i: in std_logic;
		cmd_and_i: in std_logic;
		cmd_xor_i: in std_logic;
		cmd_shift_i: in std_logic;
		cmd_shift_right_i: in std_logic;
		
		jump_type_i: in std_logic_vector(3 downto 0);
		
		op1_i: in std_logic_vector(31 downto 0);
		op2_i: in std_logic_vector(31 downto 0);
		op3_i: in std_logic_vector(31 downto 0);
		dst_i: in std_logic_vector(7 downto 0);
		
		sp_waddr_o: out std_logic_vector(7 downto 0);
		sp_we_o: out std_logic;
		sp_wdata_o: out std_logic_vector(31 downto 0);
		
		valid_i: in std_logic;
		ready_o: out std_logic;
		
		dbus_cyc_o: out std_logic;
		dbus_stb_o: out std_logic;
		dbus_we_o: out std_logic;
		dbus_sel_o: out std_logic_vector(3 downto 0);
		dbus_ack_i: in std_logic;
		dbus_adr_o: out std_logic_vector(31 downto 2);
		dbus_dat_o: out std_logic_vector(31 downto 0);
		dbus_dat_i: in std_logic_vector(31 downto 0);
		
		jump_valid_o: out std_logic;
		jump_dst_o: out std_logic_vector(29 downto 0);
		jump_ready_i: in std_logic;
		
		interrupt_return_o: out std_logic
	);
end entity;

architecture rtl of lxp32_execute is

-- Pipeline control signals

signal busy: std_logic;
signal can_execute: std_logic;

-- ALU signals

signal alu_result: std_logic_vector(31 downto 0);
signal alu_we: std_logic;
signal alu_busy: std_logic;

signal alu_cmp_eq: std_logic;
signal alu_cmp_ug: std_logic;
signal alu_cmp_sg: std_logic;

-- OP3 loader signals

signal loadop3_we: std_logic;

-- Jump machine signals

signal jump_condition: std_logic;
signal jump_valid: std_logic:='0';
signal jump_dst: std_logic_vector(jump_dst_o'range);

-- DBUS signals

signal dbus_result: std_logic_vector(31 downto 0);
signal dbus_busy: std_logic;
signal dbus_we: std_logic;

-- Result mux signals

signal result_mux: std_logic_vector(31 downto 0);
signal result_valid: std_logic;
signal result_regaddr: std_logic_vector(7 downto 0);

signal dst_reg: std_logic_vector(7 downto 0);

-- Signals related to interrupt handling

signal interrupt_return: std_logic:='0';

begin

-- Pipeline control

busy<=alu_busy or dbus_busy;
ready_o<=not busy;
can_execute<=valid_i and not busy;

-- ALU

alu_inst: entity work.lxp32_alu(rtl)
	generic map(
		DIVIDER_EN=>DIVIDER_EN,
		MUL_ARCH=>MUL_ARCH
	)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		valid_i=>can_execute,
		
		cmd_signed_i=>cmd_signed_i,
		cmd_addsub_i=>cmd_addsub_i,
		cmd_mul_i=>cmd_mul_i,
		cmd_div_i=>cmd_div_i,
		cmd_div_mod_i=>cmd_div_mod_i,
		cmd_cmp_i=>cmd_cmp_i,
		cmd_negate_op2_i=>cmd_negate_op2_i,
		cmd_and_i=>cmd_and_i,
		cmd_xor_i=>cmd_xor_i,
		cmd_shift_i=>cmd_shift_i,
		cmd_shift_right_i=>cmd_shift_right_i,
		
		op1_i=>op1_i,
		op2_i=>op2_i,
		
		result_o=>alu_result,
		
		cmp_eq_o=>alu_cmp_eq,
		cmp_ug_o=>alu_cmp_ug,
		cmp_sg_o=>alu_cmp_sg,
		
		we_o=>alu_we,
		busy_o=>alu_busy
	);

-- OP3 loader

loadop3_we<=can_execute and cmd_loadop3_i;

-- Jump logic

jump_condition<=(not cmd_cmp_i) or (jump_type_i(3) and alu_cmp_eq) or
	(jump_type_i(2) and not alu_cmp_eq) or (jump_type_i(1) and alu_cmp_ug) or
	(jump_type_i(0) and alu_cmp_sg);

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			jump_valid<='0';
			interrupt_return<='0';
			jump_dst<=(others=>'-');
		else
			if jump_valid='0' then
				jump_dst<=op1_i(31 downto 2);
				if can_execute='1' and cmd_jump_i='1' and jump_condition='1' then
					jump_valid<='1';
					interrupt_return<=op1_i(0);
				end if;
			elsif jump_ready_i='1' then
				jump_valid<='0';
				interrupt_return<='0';
			end if;
		end if;
	end if;
end process;

jump_valid_o<=jump_valid or (can_execute and cmd_jump_i and jump_condition);
jump_dst_o<=jump_dst when jump_valid='1' else op1_i(31 downto 2);

interrupt_return_o<=interrupt_return;

-- DBUS access

dbus_inst: entity work.lxp32_dbus(rtl)
	generic map(
		RMW=>DBUS_RMW
	)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		valid_i=>can_execute,
		
		cmd_dbus_i=>cmd_dbus_i,
		cmd_dbus_store_i=>cmd_dbus_store_i,
		cmd_dbus_byte_i=>cmd_dbus_byte_i,
		cmd_signed_i=>cmd_signed_i,
		addr_i=>op1_i,
		wdata_i=>op2_i,
		
		rdata_o=>dbus_result,
		busy_o=>dbus_busy,
		we_o=>dbus_we,
		
		dbus_cyc_o=>dbus_cyc_o,
		dbus_stb_o=>dbus_stb_o,
		dbus_we_o=>dbus_we_o,
		dbus_sel_o=>dbus_sel_o,
		dbus_ack_i=>dbus_ack_i,
		dbus_adr_o=>dbus_adr_o,
		dbus_dat_o=>dbus_dat_o,
		dbus_dat_i=>dbus_dat_i
	);

-- Result multiplexer

result_mux_gen: for i in result_mux'range generate
	result_mux(i)<=(alu_result(i) and alu_we) or
		(op3_i(i) and loadop3_we) or
		(dbus_result(i) and dbus_we);
end generate;

result_valid<=alu_we or loadop3_we or dbus_we;

-- Write destination register

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if can_execute='1' then
			dst_reg<=dst_i;
		end if;
	end if;
end process;

result_regaddr<=dst_i when can_execute='1' else dst_reg;

sp_we_o<=result_valid;
sp_waddr_o<=result_regaddr;
sp_wdata_o<=result_mux;

end architecture;

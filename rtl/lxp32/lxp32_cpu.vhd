---------------------------------------------------------------------
-- LXP32 CPU Core
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lxp32_cpu is
	generic(
		DBUS_RMW: boolean;
		DIVIDER_EN: boolean;
		MUL_ARCH: string;
		START_ADDR: std_logic_vector(31 downto 0)
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

architecture rtl of lxp32_cpu is

signal fetch_word: std_logic_vector(31 downto 0);
signal fetch_next_ip: std_logic_vector(29 downto 0);
signal fetch_current_ip: std_logic_vector(29 downto 0);
signal fetch_valid: std_logic;
signal fetch_jump_ready: std_logic;

signal decode_ready: std_logic;
signal decode_valid: std_logic;

signal decode_cmd_loadop3: std_logic;
signal decode_cmd_signed: std_logic;
signal decode_cmd_dbus: std_logic;
signal decode_cmd_dbus_store: std_logic;
signal decode_cmd_dbus_byte: std_logic;
signal decode_cmd_addsub: std_logic;
signal decode_cmd_mul: std_logic;
signal decode_cmd_div: std_logic;
signal decode_cmd_div_mod: std_logic;
signal decode_cmd_cmp: std_logic;
signal decode_cmd_jump: std_logic;
signal decode_cmd_negate_op2: std_logic;
signal decode_cmd_and: std_logic;
signal decode_cmd_xor: std_logic;
signal decode_cmd_shift: std_logic;
signal decode_cmd_shift_right: std_logic;

signal decode_jump_type: std_logic_vector(3 downto 0);

signal decode_op1: std_logic_vector(31 downto 0);
signal decode_op2: std_logic_vector(31 downto 0);
signal decode_op3: std_logic_vector(31 downto 0);
signal decode_dst: std_logic_vector(7 downto 0);

signal execute_ready: std_logic;
signal execute_jump_valid: std_logic;
signal execute_jump_dst: std_logic_vector(29 downto 0);

signal sp_raddr1: std_logic_vector(7 downto 0);
signal sp_rdata1: std_logic_vector(31 downto 0);
signal sp_raddr2: std_logic_vector(7 downto 0);
signal sp_rdata2: std_logic_vector(31 downto 0);
signal sp_waddr: std_logic_vector(7 downto 0);
signal sp_we: std_logic;
signal sp_wdata: std_logic_vector(31 downto 0);

signal interrupt_valid: std_logic;
signal interrupt_vector: std_logic_vector(2 downto 0);
signal interrupt_ready: std_logic;
signal interrupt_return: std_logic;

begin

fetch_inst: entity work.lxp32_fetch(rtl)
	generic map(
		START_ADDR=>START_ADDR
	)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		lli_re_o=>lli_re_o,
		lli_adr_o=>lli_adr_o,
		lli_dat_i=>lli_dat_i,
		lli_busy_i=>lli_busy_i,
		
		word_o=>fetch_word,
		next_ip_o=>fetch_next_ip,
		current_ip_o=>fetch_current_ip,
		valid_o=>fetch_valid,
		ready_i=>decode_ready,
		
		jump_valid_i=>execute_jump_valid,
		jump_dst_i=>execute_jump_dst,
		jump_ready_o=>fetch_jump_ready
	);

decode_inst: entity work.lxp32_decode(rtl)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		word_i=>fetch_word,
		next_ip_i=>fetch_next_ip,
		current_ip_i=>fetch_current_ip,
		valid_i=>fetch_valid,
		jump_valid_i=>execute_jump_valid,
		ready_o=>decode_ready,
		
		interrupt_valid_i=>interrupt_valid,
		interrupt_vector_i=>interrupt_vector,
		interrupt_ready_o=>interrupt_ready,
		
		sp_raddr1_o=>sp_raddr1,
		sp_rdata1_i=>sp_rdata1,
		sp_raddr2_o=>sp_raddr2,
		sp_rdata2_i=>sp_rdata2,
		
		ready_i=>execute_ready,
		valid_o=>decode_valid,
		
		cmd_loadop3_o=>decode_cmd_loadop3,
		cmd_signed_o=>decode_cmd_signed,
		cmd_dbus_o=>decode_cmd_dbus,
		cmd_dbus_store_o=>decode_cmd_dbus_store,
		cmd_dbus_byte_o=>decode_cmd_dbus_byte,
		cmd_addsub_o=>decode_cmd_addsub,
		cmd_mul_o=>decode_cmd_mul,
		cmd_div_o=>decode_cmd_div,
		cmd_div_mod_o=>decode_cmd_div_mod,
		cmd_cmp_o=>decode_cmd_cmp,
		cmd_jump_o=>decode_cmd_jump,
		cmd_negate_op2_o=>decode_cmd_negate_op2,
		cmd_and_o=>decode_cmd_and,
		cmd_xor_o=>decode_cmd_xor,
		cmd_shift_o=>decode_cmd_shift,
		cmd_shift_right_o=>decode_cmd_shift_right,
		
		jump_type_o=>decode_jump_type,
		
		op1_o=>decode_op1,
		op2_o=>decode_op2,
		op3_o=>decode_op3,
		dst_o=>decode_dst
	);

execute_inst: entity work.lxp32_execute(rtl)
	generic map(
		DBUS_RMW=>DBUS_RMW,
		DIVIDER_EN=>DIVIDER_EN,
		MUL_ARCH=>MUL_ARCH
	)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		cmd_loadop3_i=>decode_cmd_loadop3,
		cmd_signed_i=>decode_cmd_signed,
		cmd_dbus_i=>decode_cmd_dbus,
		cmd_dbus_store_i=>decode_cmd_dbus_store,
		cmd_dbus_byte_i=>decode_cmd_dbus_byte,
		cmd_addsub_i=>decode_cmd_addsub,
		cmd_mul_i=>decode_cmd_mul,
		cmd_div_i=>decode_cmd_div,
		cmd_div_mod_i=>decode_cmd_div_mod,
		cmd_cmp_i=>decode_cmd_cmp,
		cmd_jump_i=>decode_cmd_jump,
		cmd_negate_op2_i=>decode_cmd_negate_op2,
		cmd_and_i=>decode_cmd_and,
		cmd_xor_i=>decode_cmd_xor,
		cmd_shift_i=>decode_cmd_shift,
		cmd_shift_right_i=>decode_cmd_shift_right,
		
		jump_type_i=>decode_jump_type,
		
		op1_i=>decode_op1,
		op2_i=>decode_op2,
		op3_i=>decode_op3,
		dst_i=>decode_dst,
		
		sp_waddr_o=>sp_waddr,
		sp_we_o=>sp_we,
		sp_wdata_o=>sp_wdata,
		
		valid_i=>decode_valid,
		ready_o=>execute_ready,
		
		dbus_cyc_o=>dbus_cyc_o,
		dbus_stb_o=>dbus_stb_o,
		dbus_we_o=>dbus_we_o,
		dbus_sel_o=>dbus_sel_o,
		dbus_ack_i=>dbus_ack_i,
		dbus_adr_o=>dbus_adr_o,
		dbus_dat_o=>dbus_dat_o,
		dbus_dat_i=>dbus_dat_i,
		
		jump_valid_o=>execute_jump_valid,
		jump_dst_o=>execute_jump_dst,
		jump_ready_i=>fetch_jump_ready,
		
		interrupt_return_o=>interrupt_return
	);

scratchpad_inst: entity work.lxp32_scratchpad(rtl)
	port map(
		clk_i=>clk_i,
		
		raddr1_i=>sp_raddr1,
		rdata1_o=>sp_rdata1,
		raddr2_i=>sp_raddr2,
		rdata2_o=>sp_rdata2,
		
		waddr_i=>sp_waddr,
		we_i=>sp_we,
		wdata_i=>sp_wdata
	);

interrupt_mux_inst: entity work.lxp32_interrupt_mux(rtl)
	port map(
		clk_i=>clk_i,
		rst_i=>rst_i,
		
		irq_i=>irq_i,
		
		interrupt_valid_o=>interrupt_valid,
		interrupt_vector_o=>interrupt_vector,
		interrupt_ready_i=>interrupt_ready,
		interrupt_return_i=>interrupt_return,
		
		sp_waddr_i=>sp_waddr,
		sp_we_i=>sp_we,
		sp_wdata_i=>sp_wdata
	);

end architecture;

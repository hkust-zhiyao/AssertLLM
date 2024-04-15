---------------------------------------------------------------------
-- Instruction decoder
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- The second stage of the LXP32 pipeline.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_decode is
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		word_i: in std_logic_vector(31 downto 0);
		next_ip_i: in std_logic_vector(29 downto 0);
		current_ip_i: in std_logic_vector(29 downto 0);
		valid_i: in std_logic;
		jump_valid_i: in std_logic;
		ready_o: out std_logic;
		
		interrupt_valid_i: in std_logic;
		interrupt_vector_i: in std_logic_vector(2 downto 0);
		interrupt_ready_o: out std_logic;
		
		sp_raddr1_o: out std_logic_vector(7 downto 0);
		sp_rdata1_i: in std_logic_vector(31 downto 0);
		sp_raddr2_o: out std_logic_vector(7 downto 0);
		sp_rdata2_i: in std_logic_vector(31 downto 0);
		
		ready_i: in std_logic;
		valid_o: out std_logic;
		
		cmd_loadop3_o: out std_logic;
		cmd_signed_o: out std_logic;
		cmd_dbus_o: out std_logic;
		cmd_dbus_store_o: out std_logic;
		cmd_dbus_byte_o: out std_logic;
		cmd_addsub_o: out std_logic;
		cmd_mul_o: out std_logic;
		cmd_div_o: out std_logic;
		cmd_div_mod_o: out std_logic;
		cmd_cmp_o: out std_logic;
		cmd_jump_o: out std_logic;
		cmd_negate_op2_o: out std_logic;
		cmd_and_o: out std_logic;
		cmd_xor_o: out std_logic;
		cmd_shift_o: out std_logic;
		cmd_shift_right_o: out std_logic;
		
		jump_type_o: out std_logic_vector(3 downto 0);
		
		op1_o: out std_logic_vector(31 downto 0);
		op2_o: out std_logic_vector(31 downto 0);
		op3_o: out std_logic_vector(31 downto 0);
		dst_o: out std_logic_vector(7 downto 0)
	);
end entity;

architecture rtl of lxp32_decode is

-- Decoder FSM state

type DecoderState is (Regular,ContinueLc,ContinueCjmp,ContinueInterrupt,Halt);
signal state: DecoderState:=Regular;

-- Input instruction portions

signal opcode: std_logic_vector(5 downto 0);
signal t1: std_logic;
signal t2: std_logic;
signal destination: std_logic_vector(7 downto 0);
signal rd1: std_logic_vector(7 downto 0);
signal rd2: std_logic_vector(7 downto 0);

-- Signals related to pipeline control

signal downstream_busy: std_logic;
signal self_busy: std_logic:='0';
signal busy: std_logic;
signal valid_out: std_logic:='0';

signal dst_out: std_logic_vector(7 downto 0);

-- Signals related to RD operand decoding

signal rd1_reg: std_logic_vector(7 downto 0);
signal rd2_reg: std_logic_vector(7 downto 0);

signal rd1_select: std_logic;
signal rd1_direct: std_logic_vector(31 downto 0);
signal rd2_select: std_logic;
signal rd2_direct: std_logic_vector(31 downto 0);

-- Signals related to interrupt handling

signal interrupt_ready: std_logic:='0';

begin

-- Dissect input word

opcode<=word_i(31 downto 26);
t1<=word_i(25);
t2<=word_i(24);
destination<=word_i(23 downto 16);
rd1<=word_i(15 downto 8);
rd2<=word_i(7 downto 0);

-- Pipeline control

downstream_busy<=valid_out and not ready_i;
busy<=downstream_busy or self_busy;

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			valid_out<='0';
			self_busy<='0';
			state<=Regular;
			interrupt_ready<='0';
			cmd_loadop3_o<='-';
			cmd_signed_o<='-';
			cmd_dbus_o<='-';
			cmd_dbus_store_o<='-';
			cmd_dbus_byte_o<='-';
			cmd_addsub_o<='-';
			cmd_negate_op2_o<='-';
			cmd_mul_o<='-';
			cmd_div_o<='-';
			cmd_div_mod_o<='-';
			cmd_cmp_o<='-';
			cmd_jump_o<='-';
			cmd_and_o<='-';
			cmd_xor_o<='-';
			cmd_shift_o<='-';
			cmd_shift_right_o<='-';
			rd1_select<='-';
			rd1_direct<=(others=>'-');
			rd2_select<='-';
			rd2_direct<=(others=>'-');
			op3_o<=(others=>'-');
			jump_type_o<=(others=>'-');
			dst_out<=(others=>'-');
		else
			interrupt_ready<='0';
			if jump_valid_i='1' then
				valid_out<='0';
				self_busy<='0';
				state<=Regular;
			elsif downstream_busy='0' then
				op3_o<=(others=>'-');
				rd1_direct<=std_logic_vector(resize(signed(rd1),rd1_direct'length));
				rd2_direct<=std_logic_vector(resize(signed(rd2),rd2_direct'length));
				
				cmd_signed_o<=opcode(0);
				cmd_div_mod_o<=opcode(1);
				cmd_shift_right_o<=opcode(1);
				cmd_dbus_byte_o<=opcode(1);
				cmd_dbus_store_o<=opcode(2);
				
				case state is
				when Regular =>
					cmd_loadop3_o<='0';
					cmd_dbus_o<='0';
					cmd_addsub_o<='0';
					cmd_negate_op2_o<='0';
					cmd_mul_o<='0';
					cmd_div_o<='0';
					cmd_cmp_o<='0';
					cmd_jump_o<='0';
					cmd_and_o<='0';
					cmd_xor_o<='0';
					cmd_shift_o<='0';
					
					jump_type_o<=opcode(3 downto 0);
					
					if interrupt_valid_i='1' and valid_i='1' then
						cmd_jump_o<='1';
						cmd_loadop3_o<='1';
						op3_o<=current_ip_i&"01"; -- LSB indicates interrupt return
						dst_out<=X"FD"; -- interrupt return pointer
						rd1_select<='1';
						rd2_select<='0';
						valid_out<='1';
						interrupt_ready<='1';
						self_busy<='1';
						state<=ContinueInterrupt;
					else
						if opcode(5 downto 3)="101" or opcode="000001" then -- lc or lcs
							cmd_loadop3_o<='1';
-- Setting op3_o here only affects the lcs instruction
							op3_o<=std_logic_vector(resize(signed(opcode(2 downto 0)&
								t1&t2&rd1&rd2),op3_o'length));
						end if;
						
						if opcode(5 downto 3)="001" then
							cmd_dbus_o<='1';
						end if;
						
						if opcode(5 downto 1)="01000" then
							cmd_addsub_o<='1';
						end if;
						
						cmd_negate_op2_o<=opcode(0);
						
						if opcode="010010" then
							cmd_mul_o<='1';
						end if;
						
						if opcode(5 downto 2)="0101" then
							cmd_div_o<='1';
						end if;
						
						if opcode(5 downto 3)="100" then -- jump or call
							cmd_jump_o<='1';
							cmd_loadop3_o<=opcode(0);
-- Setting op3_o here only affects the call instruction
							op3_o<=next_ip_i&"00";
						end if;
						
						-- Note: (a or b) = (a and b) or (a xor b)
						
						if opcode(5 downto 1)="01100" then
							cmd_and_o<='1';
						end if;
						
						if opcode="011010" or opcode="011001" then
							cmd_xor_o<='1';
						end if;
						
						if opcode(5 downto 2)="0111" then
							cmd_shift_o<='1';
						end if;
						
						if opcode(5 downto 4)="11" then
							cmd_cmp_o<='1';
							cmd_negate_op2_o<='1';
						end if;
						
						rd1_select<=t1;
						rd2_select<=t2;
						
						dst_out<=destination;
						
						if valid_i='1' then
							if opcode="000001" then
								valid_out<='0';
								self_busy<='0';
								state<=ContinueLc;
							elsif opcode="000010" then
								valid_out<='0';
								self_busy<='1';
								state<=Halt;
							elsif opcode(5 downto 4)="11" then
								valid_out<='1';
								self_busy<='1';
								state<=ContinueCjmp;
							else
								valid_out<='1';
							end if;
						else
							valid_out<='0';
						end if;
					end if;
				when ContinueLc =>
					if valid_i='1' then
						valid_out<='1';
						op3_o<=word_i;
						self_busy<='0';
						state<=Regular;
					end if;
				when ContinueCjmp =>
					valid_out<='1';
					cmd_jump_o<='1';
					rd1_select<='1';
					self_busy<='0';
					state<=Regular;
				when ContinueInterrupt =>
					valid_out<='0';
				when Halt =>
					if interrupt_valid_i='1' then
						self_busy<='0';
						state<=Regular;
					end if;
				end case;
			end if;
		end if;
	end if;
end process;

valid_o<=valid_out;
dst_o<=dst_out;

ready_o<=not busy;

interrupt_ready_o<=interrupt_ready;

-- Decode RD (register/direct) operands

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if busy='0' then
			rd1_reg<=rd1;
			rd2_reg<=rd2;
		end if;
	end if;
end process;

sp_raddr1_o<="11110"&interrupt_vector_i when (state=Regular and interrupt_valid_i='1' and downstream_busy='0') or state=ContinueInterrupt else
	dst_out when (state=ContinueCjmp and downstream_busy='0') else
	rd1_reg when busy='1' else
	rd1;

sp_raddr2_o<=rd2_reg when busy='1' else rd2;

op1_o<=sp_rdata1_i when rd1_select='1' else rd1_direct;
op2_o<=sp_rdata2_i when rd2_select='1' else rd2_direct;

end architecture;

---------------------------------------------------------------------
-- Interrupt multiplexer
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- Manages LXP32 interrupts. Interrupts with lower numbers have
-- higher priority.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_interrupt_mux is
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		irq_i: in std_logic_vector(7 downto 0);
		
		interrupt_valid_o: out std_logic;
		interrupt_vector_o: out std_logic_vector(2 downto 0);
		interrupt_ready_i: in std_logic;
		interrupt_return_i: in std_logic;
		
		sp_waddr_i: in std_logic_vector(7 downto 0);
		sp_we_i: in std_logic;
		sp_wdata_i: in std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_interrupt_mux is

signal irq_reg: std_logic_vector(irq_i'range):=(others=>'0');

type state_type is (Ready,Requested,WaitForExit);
signal state: state_type:=Ready;

signal pending_interrupts: std_logic_vector(irq_i'range):=(others=>'0');

signal interrupt_valid: std_logic:='0';

signal interrupts_enabled: std_logic_vector(7 downto 0):=(others=>'0');
signal interrupts_blocked: std_logic_vector(7 downto 0):=(others=>'0');

begin

-- Note: "disabled" interrupts (i.e. for which interrupts_enabled_i(i)='0')
-- are ignored completely, meaning that the interrupt handler won't be
-- called even if the interrupt is enabled later. Conversely, "blocked"
-- interrupts are registered, but their handlers are not called until they
-- are unblocked.

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			irq_reg<=(others=>'0');
			pending_interrupts<=(others=>'0');
			state<=Ready;
			interrupt_valid<='0';
			interrupt_vector_o<=(others=>'-');
		else
			irq_reg<=irq_i;
			
			pending_interrupts<=(pending_interrupts or 
				(irq_i and not irq_reg)) and
				interrupts_enabled;
			
			case state is
			when Ready =>
				for i in pending_interrupts'reverse_range loop -- lower interrupts have priority
					if pending_interrupts(i)='1' and interrupts_blocked(i)='0' then
						pending_interrupts(i)<='0';
						interrupt_valid<='1';
						interrupt_vector_o<=std_logic_vector(to_unsigned(i,3));
						state<=Requested;
						exit;
					end if;
				end loop;
			when Requested =>
				if interrupt_ready_i='1' then
					interrupt_valid<='0';
					state<=WaitForExit;
				end if;
			when WaitForExit =>
				if interrupt_return_i='1' then
					state<=Ready;
				end if;
			end case;
		end if;
	end if;
end process;

interrupt_valid_o<=interrupt_valid;

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			interrupts_enabled<=(others=>'0');
			interrupts_blocked<=(others=>'0');
		elsif sp_we_i='1' and sp_waddr_i=X"FC" then
			interrupts_enabled<=sp_wdata_i(7 downto 0);
			interrupts_blocked<=sp_wdata_i(15 downto 8);
		end if;
	end if;
end process;

end architecture;

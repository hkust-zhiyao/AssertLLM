---------------------------------------------------------------------
-- Microbuffer
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- A small buffer with a FIFO-like interface, implemented
-- using registers.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lxp32_ubuf is
	generic(
		DATA_WIDTH: integer
	);
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		we_i: in std_logic;
		d_i: in std_logic_vector(DATA_WIDTH-1 downto 0);
		re_i: in std_logic;
		d_o: out std_logic_vector(DATA_WIDTH-1 downto 0);
		
		empty_o: out std_logic;
		full_o: out std_logic
	);
end entity;

architecture rtl of lxp32_ubuf is

signal we: std_logic;
signal re: std_logic;

signal empty: std_logic:='1';
signal full: std_logic:='0';

type regs_type is array (1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal regs: regs_type;
signal regs_mux: regs_type;

begin

we<=we_i and not full;
re<=re_i and not empty;

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			empty<='1';
			full<='0';
			regs<=(others=>(others=>'-'));
		else
			if re='0' then
				regs(0)<=regs_mux(0);
			else
				regs(0)<=regs_mux(1);
			end if;
			
			regs(1)<=regs_mux(1);
			
			if we='1' and re='0' then
				empty<='0';
				full<=not empty;
			elsif we='0' and re='1' then
				empty<=not full;
				full<='0';
			end if;
		end if;
	end if;
end process;

regs_mux(0)<=regs(0) when we='0' or empty='0' else d_i;
regs_mux(1)<=regs(1) when we='0' or empty='1' else d_i;

d_o<=regs(0);
empty_o<=empty;
full_o<=full;

end architecture;

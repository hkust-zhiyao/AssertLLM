---------------------------------------------------------------------
-- Scratchpad
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- LXP32 register file implemented as a RAM block. Since we need
-- to read two registers simultaneously, the memory is duplicated.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lxp32_scratchpad is
	port(
		clk_i: in std_logic;
		
		raddr1_i: in std_logic_vector(7 downto 0);
		rdata1_o: out std_logic_vector(31 downto 0);
		raddr2_i: in std_logic_vector(7 downto 0);
		rdata2_o: out std_logic_vector(31 downto 0);
		
		waddr_i: in std_logic_vector(7 downto 0);
		we_i: in std_logic;
		wdata_i: in std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_scratchpad is

signal wdata_reg: std_logic_vector(wdata_i'range);
signal ram1_rdata: std_logic_vector(31 downto 0);
signal ram2_rdata: std_logic_vector(31 downto 0);

signal ram1_collision: std_logic;
signal ram2_collision: std_logic;

begin

-- RAM 1

ram_inst1: entity work.lxp32_ram256x32(rtl)
	port map(
		clk_i=>clk_i,
		
		we_i=>we_i,
		waddr_i=>waddr_i,
		wdata_i=>wdata_i,
		
		re_i=>'1',
		raddr_i=>raddr1_i,
		rdata_o=>ram1_rdata
	);

-- RAM 2

ram_inst2: entity work.lxp32_ram256x32(rtl)
	port map(
		clk_i=>clk_i,
		
		we_i=>we_i,
		waddr_i=>waddr_i,
		wdata_i=>wdata_i,
		
		re_i=>'1',
		raddr_i=>raddr2_i,
		rdata_o=>ram2_rdata
	);

-- Read/write collision detection

process (clk_i) is
begin
	if rising_edge(clk_i) then
		wdata_reg<=wdata_i;
		if waddr_i=raddr1_i and we_i='1' then
			ram1_collision<='1';
		else
			ram1_collision<='0';
		end if;
		if waddr_i=raddr2_i and we_i='1' then
			ram2_collision<='1';
		else
			ram2_collision<='0';
		end if;
	end if;
end process;

rdata1_o<=ram1_rdata when ram1_collision='0' else wdata_reg;
rdata2_o<=ram2_rdata when ram2_collision='0' else wdata_reg;

end architecture;

---------------------------------------------------------------------
-- Generic dual-port memory
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- Portable description of a dual-port memory block with one write
-- port. Major FPGA synthesis tools can infer on-chip block RAM
-- from this description. Can be replaced with a library component
-- wrapper if needed.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_ram256x32 is
	port(
		clk_i: in std_logic;
		
		we_i: in std_logic;
		waddr_i: in std_logic_vector(7 downto 0);
		wdata_i: in std_logic_vector(31 downto 0);
		
		re_i: in std_logic;
		raddr_i: in std_logic_vector(7 downto 0);
		rdata_o: out std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_ram256x32 is

type ram_type is array(255 downto 0) of std_logic_vector(31 downto 0);
signal ram: ram_type:=(others=>(others=>'0')); -- zero-initialize for SRAM-based FPGAs

attribute syn_ramstyle: string;
attribute syn_ramstyle of ram: signal is "no_rw_check";
attribute ram_style: string; -- for Xilinx
attribute ram_style of ram: signal is "block";

begin

-- Write port

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if we_i='1' then
			ram(to_integer(unsigned(waddr_i)))<=wdata_i;
		end if;
	end if;
end process;

-- Read port

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if re_i='1' then
			if is_x(raddr_i) then -- to avoid numeric_std warnings during simulation
				rdata_o<=(others=>'X');
			else
				rdata_o<=ram(to_integer(unsigned(raddr_i)));
			end if;
		end if;
	end if;
end process;

end architecture;

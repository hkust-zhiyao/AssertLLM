---------------------------------------------------------------------
-- DBUS master
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- Manages data bus (DBUS) access.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_dbus is
	generic(
		RMW: boolean
	);
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		valid_i: in std_logic;
		
		cmd_dbus_i: in std_logic;
		cmd_dbus_store_i: in std_logic;
		cmd_dbus_byte_i: in std_logic;
		cmd_signed_i: in std_logic;
		addr_i: in std_logic_vector(31 downto 0);
		wdata_i: in std_logic_vector(31 downto 0);
		
		rdata_o: out std_logic_vector(31 downto 0);
		we_o: out std_logic;
		busy_o: out std_logic;
		
		dbus_cyc_o: out std_logic;
		dbus_stb_o: out std_logic;
		dbus_we_o: out std_logic;
		dbus_sel_o: out std_logic_vector(3 downto 0);
		dbus_ack_i: in std_logic;
		dbus_adr_o: out std_logic_vector(31 downto 2);
		dbus_dat_o: out std_logic_vector(31 downto 0);
		dbus_dat_i: in std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_dbus is

signal strobe: std_logic:='0';
signal we_out: std_logic:='0';
signal we: std_logic;
signal byte_mode: std_logic;
signal sel: std_logic_vector(3 downto 0);
signal sig: std_logic;
signal rmw_mode: std_logic;

signal dbus_rdata: std_logic_vector(31 downto 0);
signal selected_byte: std_logic_vector(7 downto 0);

begin

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			we_out<='0';
			strobe<='0';
			sig<='-';
			byte_mode<='-';
			sel<=(others=>'-');
			we<='-';
			rmw_mode<='-';
			dbus_adr_o<=(others=>'-');
			dbus_dat_o<=(others=>'-');
		else
			we_out<='0';
			if strobe='0' then
				if valid_i='1' and cmd_dbus_i='1' then
					strobe<='1';
					sig<=cmd_signed_i;
					
					dbus_adr_o<=addr_i(31 downto 2);
					
					if cmd_dbus_byte_i='0' then
						byte_mode<='0';
						dbus_dat_o<=wdata_i;
						sel<="1111";
						
						-- synthesis translate_off
						assert addr_i(1 downto 0)="00"
							report "Misaligned word-granular access on data bus"
							severity warning;
						-- synthesis translate_on
					else
						byte_mode<='1';
						dbus_dat_o<=wdata_i(7 downto 0)&wdata_i(7 downto 0)&
							wdata_i(7 downto 0)&wdata_i(7 downto 0);
						
						case addr_i(1 downto 0) is
						when "00" => sel<="0001";
						when "01" => sel<="0010";
						when "10" => sel<="0100";
						when "11" => sel<="1000";
						when others =>
						end case;
					end if;
					
					if not RMW then
						we<=cmd_dbus_store_i;
						rmw_mode<='0';
					else
						we<=cmd_dbus_store_i and not cmd_dbus_byte_i;
						rmw_mode<=cmd_dbus_store_i and cmd_dbus_byte_i;
					end if;
				end if;
			else
				if dbus_ack_i='1' then
					if rmw_mode='1' and we='0' and RMW then
						we<='1';
						for i in sel'range loop
							if sel(i)='0' then
								dbus_dat_o(i*8+7 downto i*8)<=
									dbus_dat_i(i*8+7 downto i*8);
							end if;
						end loop;
					else
						strobe<='0';
						if we='0' then
							we_out<='1';
						end if;
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

dbus_cyc_o<=strobe;
dbus_stb_o<=strobe;
dbus_we_o<=we;

sel_no_rmw_gen: if not RMW generate
	dbus_sel_o<=sel;
end generate;

sel_rmw_gen: if RMW generate
	dbus_sel_o<=(others=>'1');
end generate;

process (clk_i) is
begin
	if rising_edge(clk_i) then
		dbus_rdata<=dbus_dat_i;
	end if;
end process;

selected_byte_gen: for i in selected_byte'range generate
	selected_byte(i)<=(dbus_rdata(i) and sel(0)) or
		(dbus_rdata(i+8) and sel(1)) or
		(dbus_rdata(i+16) and sel(2)) or
		(dbus_rdata(i+24) and sel(3));
end generate;

rdata_o<=dbus_rdata when byte_mode='0' else
	X"000000"&selected_byte when selected_byte(selected_byte'high)='0' or sig='0' else
	X"FFFFFF"&selected_byte;

we_o<=we_out;
busy_o<=strobe or we_out;

end architecture;

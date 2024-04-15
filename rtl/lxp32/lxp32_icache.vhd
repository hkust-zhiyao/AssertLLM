---------------------------------------------------------------------
-- Instruction cache
--
-- Part of the LXP32 CPU
--
-- Copyright (c) 2016 by Alex I. Kuznetsov
--
-- A simple single-page buffer providing both caching and
-- prefetching capabilities. Useful for high-latency memory,
-- such as external SDRAM.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lxp32_icache is
	generic(
		BURST_SIZE: integer;
		PREFETCH_SIZE: integer
	);
	port(
		clk_i: in std_logic;
		rst_i: in std_logic;
		
		lli_re_i: in std_logic;
		lli_adr_i: in std_logic_vector(29 downto 0);
		lli_dat_o: out std_logic_vector(31 downto 0);
		lli_busy_o: out std_logic;
		
		wbm_cyc_o: out std_logic;
		wbm_stb_o: out std_logic;
		wbm_cti_o: out std_logic_vector(2 downto 0);
		wbm_bte_o: out std_logic_vector(1 downto 0);
		wbm_ack_i: in std_logic;
		wbm_adr_o: out std_logic_vector(29 downto 0);
		wbm_dat_i: in std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of lxp32_icache is

signal lli_adr_reg: std_logic_vector(lli_adr_i'range);
signal lli_adr_mux: std_logic_vector(lli_adr_i'range);

signal ram_waddr: std_logic_vector(7 downto 0);
signal ram_raddr: std_logic_vector(7 downto 0);
signal ram_re: std_logic;
signal ram_we: std_logic;

signal read_base: unsigned(21 downto 0);
signal read_offset: unsigned(7 downto 0);

signal init: std_logic:='0';
signal burst1: std_logic;
signal terminate_burst: std_logic;
signal near_miss: std_logic:='0';
signal prefetch_distance: unsigned(7 downto 0);
signal wrap_cnt: integer range 0 to 3:=0;
signal burst_cnt: integer range 0 to BURST_SIZE:=0;
signal wb_stb: std_logic:='0';
signal wb_cti: std_logic_vector(2 downto 0);

-- Note: the following five signals are zero-initialized for
-- simulation only, to suppress warnings from numeric_std.
-- This initialization is not required for synthesis.

signal current_base: unsigned(21 downto 0):=(others=>'0');
signal current_offset: unsigned(7 downto 0):=(others=>'0');
signal prev_base: unsigned(21 downto 0):=(others=>'0');
signal next_base: unsigned(21 downto 0):=(others=>'0');
signal start_offset: unsigned(7 downto 0):=(others=>'0');

signal hitc: std_logic;
signal hitp: std_logic;
signal miss: std_logic:='0';

begin

assert PREFETCH_SIZE>=4
	report "PREFETCH_SIZE cannot be less than 4"
	severity failure;
assert BURST_SIZE>=4
	report "BURST_SIZE cannot be less than 4"
	severity failure;
assert PREFETCH_SIZE+BURST_SIZE<=128
	report "PREFETCH_SIZE and BURST_SIZE combined cannot be greater than 128"
	severity failure;


process (clk_i) is
begin
	if rising_edge(clk_i) then
		if miss='0' then
			lli_adr_reg<=lli_adr_i;
		end if;
	end if;
end process;

lli_adr_mux<=lli_adr_i when miss='0' else lli_adr_reg;

read_base<=unsigned(lli_adr_mux(29 downto 8));
read_offset<=unsigned(lli_adr_mux(7 downto 0));

-- Cache RAM

ram_waddr<=std_logic_vector(current_offset);
ram_raddr<=std_logic_vector(read_offset);
ram_we<=wb_stb and wbm_ack_i;
ram_re<=lli_re_i or miss;

ram_inst: entity work.lxp32_ram256x32(rtl)
	port map(
		clk_i=>clk_i,
		
		we_i=>ram_we,
		waddr_i=>ram_waddr,
		wdata_i=>wbm_dat_i,
		
		re_i=>ram_re,
		raddr_i=>ram_raddr,
		rdata_o=>lli_dat_o
	);

-- Determine hit/miss

-- This cache uses a single ring buffer. Address in buffer corresponds
-- to the lower 8 bits of the full address. The part of the buffer that
-- is higher than current_offset represents a previous block ("p"), the
-- other part represents a current block ("c").

hitc<='1' when read_base=current_base and read_offset<current_offset and
	((wrap_cnt=1 and read_offset>=start_offset) or
	wrap_cnt=2 or wrap_cnt=3) else '0';

hitp<='1' when read_base=prev_base and read_offset>current_offset and
	((wrap_cnt=2 and read_offset>=start_offset) or
	wrap_cnt=3) else '0';

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			miss<='0';
		else
			if hitc='0' and hitp='0' and ram_re='1' then
				miss<='1';
			else
				miss<='0';
			end if;
		end if;
	end if;
end process;

lli_busy_o<=miss;

-- Set INIT flag when the first lli_re_i signal is detected

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			init<='0';
		elsif lli_re_i='1' then
			init<='1';
		end if;
	end if;
end process;

-- Fill cache

prefetch_distance<=current_offset-read_offset;

-- Note: "near_miss" signal prevents cache invalidation when difference
-- between the requested address and the currently fetched address 
-- is too small (and, therefore, the requested data will be fetched soon
-- without invalidation).

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			near_miss<='0';
		elsif wrap_cnt>0 and read_offset-current_offset<=to_unsigned(BURST_SIZE/2,8) and
			((read_base=current_base and read_offset>=current_offset) or
			(read_base=next_base and read_offset<current_offset))
		then
			near_miss<='1';
		else
			near_miss<='0';
		end if;
	end if;
end process;

terminate_burst<='1' when burst_cnt<BURST_SIZE-1 and miss='1' and
	(burst_cnt>2 or burst1='0') and near_miss='0' else '0';

process (clk_i) is
begin
	if rising_edge(clk_i) then
		if rst_i='1' then
			burst_cnt<=0;
			wb_stb<='0';
			wrap_cnt<=0;
			wb_cti<=(others=>'-');
			burst1<='-';
			current_offset<=(others=>'-');
			start_offset<=(others=>'-');
			current_base<=(others=>'-');
			next_base<=(others=>'-');
			prev_base<=(others=>'-');
			
			-- To suppress numeric_std warnings
			-- synthesis translate_off
			current_offset<=(others=>'0');
			start_offset<=(others=>'0');
			current_base<=(others=>'0');
			next_base<=(others=>'0');
			prev_base<=(others=>'0');
			-- synthesis translate_on
		else
			if burst_cnt=0 and init='1' then
				if miss='1' and near_miss='0' then
					wb_stb<='1';
					wb_cti<="010";
					current_offset<=read_offset;
					start_offset<=read_offset;
					current_base<=read_base;
					next_base<=read_base+1;
					burst_cnt<=1;
					burst1<='1';
					wrap_cnt<=1;
				elsif prefetch_distance<to_unsigned(PREFETCH_SIZE,8) or near_miss='1' then
					wb_stb<='1';
					wb_cti<="010";
					burst_cnt<=1;
					burst1<='0';
				end if;
			else
				if wbm_ack_i='1' then
					current_offset<=current_offset+1;
					if current_offset=X"FF" then
						current_base<=next_base;
						next_base<=next_base+1;
						prev_base<=current_base;
						if wrap_cnt<3 then
							wrap_cnt<=wrap_cnt+1;
						end if;
					end if;
					if burst_cnt=BURST_SIZE-1 or terminate_burst='1' then
						burst_cnt<=BURST_SIZE;
						wb_cti<="111";
					elsif burst_cnt<BURST_SIZE-1 then
						burst_cnt<=burst_cnt+1;
						wb_cti<="010";
					else
						if miss='1' and near_miss='0' then
							wb_stb<='1';
							wb_cti<="010";
							current_offset<=read_offset;
							start_offset<=read_offset;
							current_base<=read_base;
							next_base<=read_base+1;
							burst_cnt<=1;
							burst1<='1';
							wrap_cnt<=1;
						elsif prefetch_distance<to_unsigned(PREFETCH_SIZE,8) or near_miss='1' then
							wb_stb<='1';
							wb_cti<="010";
							burst_cnt<=1;
							burst1<='0';
						else
							burst_cnt<=0;
							wb_stb<='0';
						end if;
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

wbm_cyc_o<=wb_stb;
wbm_stb_o<=wb_stb;
wbm_cti_o<=wb_cti;
wbm_bte_o<="00";
wbm_adr_o<=std_logic_vector(current_base&current_offset);

end architecture;

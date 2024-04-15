-- #################################################################################################
-- #  << NEO430 - High-Precision Timer >>                                                          #
-- # ********************************************************************************************* #
-- # This timer uses a configurable prescaler to increment an internal 16-bit counter. When the    #
-- # counter value reaches the programmable threshold an interrupt can be triggered. Optionally,   #
-- # the counter can be automatically reset when reaching the threshold value.                     #
-- # Configure THRES before enabling the timer to prevent false interrupt requests.                #
-- # ********************************************************************************************* #
-- # This file is part of the NEO430 Processor project: https://github.com/stnolting/neo430        #
-- # Copyright by Stephan Nolting: stnolting@gmail.com                                             #
-- #                                                                                               #
-- # This source file may be used and distributed without restriction provided that this copyright #
-- # statement is not removed from the file and that any derivative work contains the original     #
-- # copyright notice and the associated disclaimer.                                               #
-- #                                                                                               #
-- # This source file is free software; you can redistribute it and/or modify it under the terms   #
-- # of the GNU Lesser General Public License as published by the Free Software Foundation,        #
-- # either version 3 of the License, or (at your option) any later version.                       #
-- #                                                                                               #
-- # This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;      #
-- # without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.     #
-- # See the GNU Lesser General Public License for more details.                                   #
-- #                                                                                               #
-- # You should have received a copy of the GNU Lesser General Public License along with this      #
-- # source; if not, download it from https://www.gnu.org/licenses/lgpl-3.0.en.html                #
-- # ********************************************************************************************* #
-- #  tephan Nolting, Hannover, Germany                                                 29.09.2018 #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neo430;
use neo430.neo430_package.all;

entity neo430_timer is
  port (
    -- host access --
    clk_i       : in  std_ulogic; -- global clock line
    rden_i      : in  std_ulogic; -- read enable
    wren_i      : in  std_ulogic; -- write enable
    addr_i      : in  std_ulogic_vector(15 downto 0); -- address
    data_i      : in  std_ulogic_vector(15 downto 0); -- data in
    data_o      : out std_ulogic_vector(15 downto 0); -- data out
    -- clock generator --
    clkgen_en_o : out std_ulogic; -- enable clock generator
    clkgen_i    : in  std_ulogic_vector(07 downto 0);
    -- interrupt --
    irq_o       : out std_ulogic  -- interrupt request
  );
end neo430_timer;

architecture neo430_timer_rtl of neo430_timer is

  -- IO space: module base address --
  constant hi_abb_c : natural := index_size_f(io_size_c)-1; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(timer_size_c); -- low address boundary bit

  -- control reg bits --
  constant ctrl_en_bit_c     : natural := 0; -- r/w: timer enable
  constant ctrl_arst_bit_c   : natural := 1; -- r/w: auto reset on match
  constant ctrl_irq_en_bit_c : natural := 2; -- r/w: interrupt enable
  constant ctrl_prsc0_bit_c  : natural := 3; -- r/w: prescaler select bit 0
  constant ctrl_prsc1_bit_c  : natural := 4; -- r/w: prescaler select bit 1
  constant ctrl_prsc2_bit_c  : natural := 5; -- r/w: prescaler select bit 2

  -- access control --
  signal acc_en : std_ulogic; -- module access enable
  signal addr   : std_ulogic_vector(15 downto 0); -- access address
  signal wr_en  : std_ulogic; -- word write enable

  -- timer regs --
  signal cnt  : std_ulogic_vector(15 downto 0);
  signal thres : std_ulogic_vector(15 downto 0);
  signal ctrl : std_ulogic_vector(05 downto 0);

  -- prescaler clock generator --
  signal prsc_tick : std_ulogic;

  -- timer control --
  signal match       : std_ulogic; -- thres = cnt
  signal irq_fire    : std_ulogic;
  signal irq_fire_ff : std_ulogic;

begin

  -- Access Control -----------------------------------------------------------
  -- -----------------------------------------------------------------------------
  acc_en <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = timer_base_c(hi_abb_c downto lo_abb_c)) else '0';
  addr   <= timer_base_c(15 downto lo_abb_c) & addr_i(lo_abb_c-1 downto 1) & '0'; -- word aligned
  wr_en  <= acc_en and wren_i;


  -- Write access and timer update --------------------------------------------
  -- -----------------------------------------------------------------------------
  wr_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      -- edge detector --
      irq_fire_ff <= irq_fire;
      -- timer counter --
      if (wr_en = '1') and (addr = timer_cnt_addr_c) then
        cnt <= data_i;
      elsif (ctrl(ctrl_en_bit_c) = '1') then -- timer enabled
        if (match = '1') and (ctrl(ctrl_arst_bit_c) = '1') then -- match?
          cnt <= (others => '0');
        elsif (match = '0') and (prsc_tick = '1') then -- count++ if no match
          cnt <= std_ulogic_vector(unsigned(cnt) + 1);
        end if;
      end if;
      -- control & threshold --
      if (wr_en = '1') then
        case addr is
          when timer_thres_addr_c =>
            thres <= data_i;
          when timer_ctrl_addr_c =>
            ctrl(ctrl_en_bit_c)     <= data_i(ctrl_en_bit_c);
            ctrl(ctrl_arst_bit_c)   <= data_i(ctrl_arst_bit_c);
            ctrl(ctrl_irq_en_bit_c) <= data_i(ctrl_irq_en_bit_c);
            ctrl(ctrl_prsc0_bit_c)  <= data_i(ctrl_prsc0_bit_c);
            ctrl(ctrl_prsc1_bit_c)  <= data_i(ctrl_prsc1_bit_c);
            ctrl(ctrl_prsc2_bit_c)  <= data_i(ctrl_prsc2_bit_c);
          when others => NULL;
        end case;
      end if;
    end if;
  end process wr_access;

  -- timer clock select --
  prsc_tick <= clkgen_i(to_integer(unsigned(ctrl(ctrl_prsc2_bit_c downto ctrl_prsc0_bit_c))));

  -- enable external clock generator --
  clkgen_en_o <= ctrl(ctrl_en_bit_c);

  -- match --
  match <= '1' when (cnt = thres) else '0';

  -- interrupt line --
  irq_fire <= match and ctrl(ctrl_en_bit_c) and ctrl(ctrl_irq_en_bit_c);

  -- edge detector --
  irq_o <= irq_fire and (not irq_fire_ff);


  -- Read access --------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  rd_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      data_o <= (others => '0');
      if (rden_i = '1') and (acc_en = '1') then
        case addr is
          when timer_ctrl_addr_c =>
            data_o(ctrl_en_bit_c)     <= ctrl(ctrl_en_bit_c);
            data_o(ctrl_arst_bit_c)   <= ctrl(ctrl_arst_bit_c);
            data_o(ctrl_irq_en_bit_c) <= ctrl(ctrl_irq_en_bit_c);
            data_o(ctrl_prsc0_bit_c)  <= ctrl(ctrl_prsc0_bit_c);
            data_o(ctrl_prsc1_bit_c)  <= ctrl(ctrl_prsc1_bit_c);
            data_o(ctrl_prsc2_bit_c)  <= ctrl(ctrl_prsc2_bit_c);
          when timer_cnt_addr_c =>
            data_o <= cnt;
          when others =>
        --when timer_thres_addr_c =>
            data_o <= thres;
        end case;
      end if;
    end if;
  end process rd_access;


end neo430_timer_rtl;

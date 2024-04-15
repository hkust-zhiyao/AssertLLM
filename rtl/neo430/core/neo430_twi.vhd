-- #################################################################################################
-- #  << NEO430 - Two Wire Serial Interface (I2C) >>                                               #
-- # ********************************************************************************************* #
-- # Supports START and STOP condition and 8 bit data + ACK/NACK transfers.                        #
-- # No multi-master support! No clock stretching support yet!                                     #
-- # Interrupt: TWI_transfer_done                                                                  #
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
-- # Stephan Nolting, Hannover, Germany                                                 17.11.2018 #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neo430;
use neo430.neo430_package.all;

entity neo430_twi is
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
    -- com lines --
    twi_sda_io  : inout std_logic; -- serial data line
    twi_scl_io  : inout std_logic; -- serial clock line
    -- interrupt --
    twi_irq_o   : out std_ulogic -- transfer done IRQ
  );
end neo430_twi;

architecture neo430_twi_rtl of neo430_twi is

  -- IO space: module base address --
  constant hi_abb_c : natural := index_size_f(io_size_c)-1; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(twi_size_c); -- low address boundary bit

  -- control reg bits --
  constant ctrl_twi_en_c     : natural := 0; -- r/w: TWI enable
  constant ctrl_twi_start_c  : natural := 1; -- -/w: Generate START condition
  constant ctrl_twi_stop_c   : natural := 2; -- -/w: Generate STOP condition
  constant ctrl_twi_busy_c   : natural := 3; -- r/-: Set if TWI is busy
  constant ctrl_twi_prsc0_c  : natural := 4; -- r/w: CLK prsc bit 0
  constant ctrl_twi_prsc1_c  : natural := 5; -- r/w: CLK prsc bit 1
  constant ctrl_twi_prsc2_c  : natural := 6; -- r/w: CLK prsc bit 2
  constant ctrl_twi_irq_en_c : natural := 7; -- r/w: transmission done interrupt

  -- dta register flags --
  constant data_twi_ack_c   : natural := 15; -- r/-: Set if ACK received

  -- access control --
  signal acc_en : std_ulogic; -- module access enable
  signal addr   : std_ulogic_vector(15 downto 0); -- access address
  signal wr_en  : std_ulogic; -- word write enable
  signal rd_en  : std_ulogic; -- read enable

  -- twi clocking --
  signal twi_clk        : std_ulogic;
  signal twi_phase_gen  : std_ulogic_vector(3 downto 0);
  signal twi_clk_phase  : std_ulogic_vector(3 downto 0);

  -- twi transceiver core --
  signal ctrl         : std_ulogic_vector(7 downto 0); -- unit's control register
  signal arbiter      : std_ulogic_vector(2 downto 0);
  signal twi_bitcnt   : std_ulogic_vector(3 downto 0);
  signal twi_rtx_sreg : std_ulogic_vector(8 downto 0); -- main rx/tx shift reg

  -- tri-state I/O --
  signal twi_sda_i_ff0, twi_sda_i_ff1 : std_ulogic; -- sda input sync
  signal twi_scl_i_ff0, twi_scl_i_ff1 : std_ulogic; -- sda input sync
  signal twi_sda_i,     twi_sda_o     : std_ulogic;
  signal twi_scl_i,     twi_scl_o     : std_ulogic;

begin

  -- Access Control -----------------------------------------------------------
  -- -----------------------------------------------------------------------------
  acc_en <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = twi_base_c(hi_abb_c downto lo_abb_c)) else '0';
  addr   <= twi_base_c(15 downto lo_abb_c) & addr_i(lo_abb_c-1 downto 1) & '0'; -- word aligned
  wr_en  <= acc_en and wren_i;
  rd_en  <= acc_en and rden_i;


  -- Write access -------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  wr_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (wr_en = '1') then
        if (addr = twi_ctrl_addr_c) then
          ctrl <= data_i(7 downto 0);
        end if;
      end if;
    end if;
  end process wr_access;


  -- Clock Generation ---------------------------------------------------------
  -- -----------------------------------------------------------------------------
  -- clock generator enable --
  clkgen_en_o <= ctrl(ctrl_twi_en_c);

  -- main twi clock select --
  twi_clk <= clkgen_i(to_integer(unsigned(ctrl(ctrl_twi_prsc2_c downto ctrl_twi_prsc0_c))));

  -- generate four non-overlapping clock ticks at twi_clk/4 each --
  clock_phase_gen: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (arbiter(2) = '0') or (arbiter = "100") then -- offline or idle
        twi_phase_gen <= "0001"; -- make sure to start with a new phase 0,1,2,3 stepping
      else
        if (twi_clk = '1') then
          twi_phase_gen <= twi_phase_gen(2 downto 0) & twi_phase_gen(3); -- shift left
        end if;
      end if;
    end if;
  end process clock_phase_gen;

  twi_clk_phase(0) <= twi_phase_gen(0) and twi_clk;
  twi_clk_phase(1) <= twi_phase_gen(1) and twi_clk;
  twi_clk_phase(2) <= twi_phase_gen(2) and twi_clk;
  twi_clk_phase(3) <= twi_phase_gen(3) and twi_clk;


  -- TWI transceiver ----------------------------------------------------------
  -- -----------------------------------------------------------------------------
  twi_rtx_unit: process(clk_i)
  begin
    if rising_edge(clk_i) then
      -- input synchronizer --
      twi_sda_i_ff0 <= twi_sda_i;
      twi_sda_i_ff1 <= twi_sda_i_ff0;
      twi_scl_i_ff0 <= twi_scl_i;
      twi_scl_i_ff1 <= twi_scl_i_ff0;

      -- defaults --
      twi_irq_o <= '0';

      -- arbiter FSM --
      -- TWI bus signals are set/sampled using 4 clock phases
      case arbiter is

        when "100" => -- IDLE: waiting for requests, bus is still claimed by the master if no STOP condition was generated
          arbiter(2) <= ctrl(ctrl_twi_en_c); -- still activated?
          twi_bitcnt <= (others => '0');
          if (wr_en = '1') then
            if (addr = twi_ctrl_addr_c) then
              if (data_i(ctrl_twi_start_c) = '1') then -- issue START condition
                arbiter(1 downto 0) <= "01";
              elsif (data_i(ctrl_twi_stop_c) = '1') then  -- issue STOP condition
                arbiter(1 downto 0) <= "10";
              end if;
            elsif (addr = twi_rtx_addr_c) then -- start transmission
              twi_rtx_sreg <= data_i(7 downto 0) & '1'; -- one bit extra for stop condition
              arbiter(1 downto 0) <= "11";
            end if;
          end if;

        when "101" => -- START: generate START condition
          arbiter(2) <= ctrl(ctrl_twi_en_c); -- still activated?

          if (twi_clk_phase(0) = '1') then
            twi_sda_o <= '1';
          elsif (twi_clk_phase(1) = '1') then
            twi_sda_o <= '0';
          end if;

          if (twi_clk_phase(0) = '1') then
            twi_scl_o <= '1';
          elsif (twi_clk_phase(3) = '1') then
            twi_scl_o <= '0';
            arbiter(1 downto 0) <= "00"; -- go back to IDLE
          end if;

        when "110" => -- STOP: generate STOP condition
          arbiter(2) <= ctrl(ctrl_twi_en_c); -- still activated?

          if (twi_clk_phase(0) = '1') then
            twi_sda_o <= '0';
          elsif (twi_clk_phase(3) = '1') then
            twi_sda_o <= '1';
            arbiter(1 downto 0) <= "00"; -- go back to IDLE
          end if;
          
          if (twi_clk_phase(0) = '1') then
            twi_scl_o <= '0';
          elsif (twi_clk_phase(1) = '1') then
            twi_scl_o <= '1';
          end if;

        when "111" => -- TRANSMISSION: transmission in progress
          arbiter(2) <= ctrl(ctrl_twi_en_c); -- still activated?

          if (twi_clk_phase(0) = '1') then
            twi_bitcnt   <= std_ulogic_vector(unsigned(twi_bitcnt) + 1);
            twi_scl_o    <= '0';
            twi_sda_o    <= twi_rtx_sreg(8); -- MSB first
          elsif (twi_clk_phase(1) = '1') then -- first half + second half of valid data strobe
            twi_scl_o <= '1';
          elsif (twi_clk_phase(3) = '1') then
            twi_rtx_sreg <= twi_rtx_sreg(7 downto 0) & twi_sda_i_ff1; -- sample and shift left
            twi_scl_o    <= '0';
          end if;

          if (twi_bitcnt = "1010") then -- 8 data bits + 1 bit for ACK + 1 tick delay
            arbiter(1 downto 0) <= "00"; -- go back to IDLE
            twi_irq_o <= ctrl(ctrl_twi_irq_en_c); -- fire IRQ if enabled
          end if;

        when others => -- "0--" OFFLINE: deactivated
          twi_sda_o <= '1';
          twi_scl_o <= '1';
          arbiter   <= ctrl(ctrl_twi_en_c) & "00"; -- stay here, go to idle when activated

      end case;
    end if;
  end process twi_rtx_unit;


  -- Read access --------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  rd_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      data_o <= (others => '0');
      if (rd_en = '1') then
        if (addr = twi_ctrl_addr_c) then
          data_o(ctrl_twi_en_c)     <= ctrl(ctrl_twi_en_c);
          data_o(ctrl_twi_prsc0_c)  <= ctrl(ctrl_twi_prsc0_c);
          data_o(ctrl_twi_prsc1_c)  <= ctrl(ctrl_twi_prsc1_c);
          data_o(ctrl_twi_prsc2_c)  <= ctrl(ctrl_twi_prsc2_c);
          data_o(ctrl_twi_irq_en_c) <= ctrl(ctrl_twi_irq_en_c);
          data_o(ctrl_twi_busy_c)   <= arbiter(1) or arbiter(0);
        else -- twi_rtx_addr_c =>
          data_o(7 downto 0)        <= twi_rtx_sreg(8 downto 1);
          data_o(data_twi_ack_c)    <= not twi_rtx_sreg(0);
        end if;
      end if;
    end if;
  end process rd_access;


  -- Tri-State Driver ---------------------------------------------------------
  -- -----------------------------------------------------------------------------
  -- SDA and SCL need to be of type std_logic to be correctly resolved in simulation
  twi_sda_io <= '0' when (twi_sda_o = '0') else 'Z';
  twi_scl_io <= '0' when (twi_scl_o = '0') else 'Z';

  -- read-back --
  twi_sda_i <= std_ulogic(twi_sda_io);
  twi_scl_i <= std_ulogic(twi_scl_io);


end neo430_twi_rtl;

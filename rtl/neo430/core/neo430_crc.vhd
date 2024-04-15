-- #################################################################################################
-- # << NEO430 - CRC Module >>                                                                     #
-- # ********************************************************************************************* #
-- # This module generates CRC16 and CRC32 check sums with variable polynomial masks.              #
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
-- # Stephan Nolting, Hannover, Germany                                                 29.09.2018 #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neo430;
use neo430.neo430_package.all;

entity neo430_crc is
  port (
    -- host access --
    clk_i  : in  std_ulogic; -- global clock line
    rden_i : in  std_ulogic; -- read enable
    wren_i : in  std_ulogic; -- write enable
    addr_i : in  std_ulogic_vector(15 downto 0); -- address
    data_i : in  std_ulogic_vector(15 downto 0); -- data in
    data_o : out std_ulogic_vector(15 downto 0)  -- data out
  );
end neo430_crc;

architecture neo430_crc_rtl of neo430_crc is

  -- IO space: module base address --
  constant hi_abb_c : natural := index_size_f(io_size_c)-1; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(crc_size_c); -- low address boundary bit

  -- access control --
  signal acc_en : std_ulogic; -- module access enable
  signal addr   : std_ulogic_vector(15 downto 0); -- access address
  signal wren   : std_ulogic;

  -- accessible registers --
  signal idata : std_ulogic_vector(07 downto 0);
  signal poly  : std_ulogic_vector(31 downto 0);
  signal start : std_ulogic;
  signal mode  : std_ulogic;

  -- core --
  signal cnt     : std_ulogic_vector(02 downto 0);
  signal run     : std_ulogic;
  signal crc_bit : std_ulogic;
  signal crc_sr  : std_ulogic_vector(31 downto 0);

begin

  -- Access Control -----------------------------------------------------------
  -- -----------------------------------------------------------------------------
  acc_en <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = crc_base_c(hi_abb_c downto lo_abb_c)) else '0';
  addr   <= crc_base_c(15 downto lo_abb_c) & addr_i(lo_abb_c-1 downto 1) & '0'; -- word aligned
  wren   <= acc_en and wren_i;


  -- Write Access -------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  write_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      start <= '0';
      if (wren = '1') then
        -- operands --
        case addr is
          when crc_crc16_in_addr_c | crc_crc32_in_addr_c => -- write data & start operation
            idata <= data_i(7 downto 0);
            start <= '1'; -- start operation
          when crc_poly_lo_addr_c => -- low (part) polynomial
            poly(15 downto 00) <= data_i;
          when crc_poly_hi_addr_c => -- high (part) polynomial
            poly(31 downto 16) <= data_i;
          when others =>
            NULL;
        end case;
        -- operation selection --
        if (addr = crc_crc16_in_addr_c) then
          mode <= '0'; -- crc16 mode
        else
          mode <= '1'; -- crc32 mode
        end if;
      end if;
    end if;
  end process write_access;


  -- CRC Core -----------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  crc_core: process(clk_i)
  begin
    if rising_edge(clk_i) then
      -- arbitration --
      if (start = '1') then
        run <= '1';
      elsif (cnt = "000") then -- all done?
        run <= '0';
      end if;
      if (start = '1') then
        cnt <= "111"; -- start with MSB
      elsif (run = '1') then
        cnt <= std_ulogic_vector(unsigned(cnt) - 1);
      end if;

      -- computation --
      if ((wren = '1') and (addr = crc_resx_addr_c)) then -- write low part of CRC shift reg
        crc_sr(15 downto 0) <= data_i;
      elsif ((wren = '1') and (addr = crc_resy_addr_c)) then -- write high part of CRC shift reg
        crc_sr(31 downto 16) <= data_i;
      elsif (run = '1') then -- compute new CRC
        if (crc_bit /= idata(to_integer(unsigned(cnt(2 downto 0))))) then
          crc_sr <= (crc_sr(30 downto 0) & '0') xor poly;
        else
          crc_sr <= (crc_sr(30 downto 0) & '0');
        end if;
      end if;
    end if;
  end process crc_core;

  -- select compare bit according to selected mode --
  crc_bit <= crc_sr(31) when (mode = '1') else crc_sr(15);


  -- Read Access --------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  read_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      data_o <= (others => '0');
      if (acc_en = '1') and (rden_i = '1') then
        if (addr = crc_resx_addr_c) then
          data_o <= crc_sr(15 downto 00);
        else -- if addr = crc_resy_addr_c
          data_o <= crc_sr(31 downto 16);
        end if;
      end if;
    end if;
  end process read_access;


end neo430_crc_rtl;

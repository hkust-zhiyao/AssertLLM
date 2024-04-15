-- #################################################################################################
-- #  << NEO430 - Arithmetical/Logical Unit >>                                                     #
-- # ********************************************************************************************* #
-- # Main data processing ALU and temporary operand registers.                                     #
-- # BCD arithmetic operations need 2 cycles, all other operations only take one cycle.            #
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
-- # Stephan Nolting, Hannover, Germany                                                 22.06.2018 #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neo430;
use neo430.neo430_package.all;

entity neo430_alu is
  generic (
    DADD_USE : boolean := true -- implement DADD instruction?
  );
  port (
    -- global control --
    clk_i  : in  std_ulogic; -- global clock, rising edge
    -- operands --
    reg_i  : in  std_ulogic_vector(15 downto 0); -- data from reg file
    mem_i  : in  std_ulogic_vector(15 downto 0); -- data from memory
    sreg_i : in  std_ulogic_vector(15 downto 0); -- current SR
    -- control --
    ctrl_i : in  std_ulogic_vector(ctrl_width_c-1 downto 0);
    -- results --
    data_o : out std_ulogic_vector(15 downto 0); -- result
    flag_o : out std_ulogic_vector(03 downto 0)  -- new ALU flags
  );
end neo430_alu;

architecture neo430_alu_rtl of neo430_alu is

  signal op_data          : std_ulogic_vector(15 downto 0); -- operand data
  signal op_a_ff, op_b_ff : std_ulogic_vector(15 downto 0); -- operand register
  signal add_res          : std_ulogic_vector(17 downto 0); -- adder/subtractor kernel result
  signal dadd_res         : std_ulogic_vector(16 downto 0); -- decimal adder kernel result
  signal dadd_res_ff      : std_ulogic_vector(16 downto 0); -- decimal adder kernel result buffered
  signal dadd_res_in      : std_ulogic_vector(16 downto 0); -- decimal adder kernel result buffered
  signal alu_res          : std_ulogic_vector(15 downto 0); -- alu result
  signal data_res         : std_ulogic_vector(15 downto 0); -- final alu result
  signal zero             : std_ulogic; -- zero detector
  signal negative         : std_ulogic; -- sign detectors

begin

  -- Input Operand Selection --------------------------------------------------
  -- -----------------------------------------------------------------------------
  op_data <= reg_i when (ctrl_i(ctrl_alu_in_sel_c) = '0') else mem_i;-- when (ctrl_i(ctrl_alu_bw_c) = '0') else (x"00" & mem_i(7 downto 0));


  -- Operand Registers --------------------------------------------------------
  -- -----------------------------------------------------------------------------
  operand_register: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (ctrl_i(ctrl_alu_opa_wr_c) = '1') then
        op_a_ff <= op_data;
      end if;
      if (ctrl_i(ctrl_alu_opb_wr_c) = '1') then
        op_b_ff <= op_data;
      end if;
    end if;
  end process operand_register;


  -- Binary Arithmetic Core ---------------------------------------------------
  -- -----------------------------------------------------------------------------
  binary_arithmetic_core: process(ctrl_i, op_a_ff, op_b_ff, sreg_i)
    variable op_a_v             : std_ulogic_vector(15 downto 0);
    variable carry_v            : std_ulogic;
    variable carry_null_v       : std_ulogic;
    variable a_lo_v, a_hi_v     : std_ulogic_vector(8 downto 0);
    variable b_lo_v, b_hi_v     : std_ulogic_vector(8 downto 0);
    variable add_lo_v, add_hi_v : std_ulogic_vector(8 downto 0);
    variable carry_in_v         : std_ulogic_vector(0 downto 0);
    variable ova_16_v, ova_8_v  : std_ulogic;
  begin
    -- add/sub control (for operand A= --
    if (ctrl_i(ctrl_alu_cmd3_c downto ctrl_alu_cmd0_c) = alu_add_c) or 
       (ctrl_i(ctrl_alu_cmd3_c downto ctrl_alu_cmd0_c) = alu_addc_c) then -- addition
      op_a_v       := op_a_ff;
      carry_null_v := '0';
    else -- subtraction
      op_a_v       := not op_a_ff;
      carry_null_v := '1';
    end if;

    -- carry input --
    if (ctrl_i(ctrl_alu_cmd3_c downto ctrl_alu_cmd0_c) = alu_addc_c) or 
       (ctrl_i(ctrl_alu_cmd3_c downto ctrl_alu_cmd0_c) = alu_subc_c) then -- use carry in
      carry_in_v(0) := sreg_i(sreg_c_c);
    else
      carry_in_v(0) := carry_null_v; -- set default NO ACTIVE CARRY input
    end if;

    -- operands --
    a_lo_v := '0' & op_a_v(07 downto 0);
    a_hi_v := '0' & op_a_v(15 downto 8);
    b_lo_v := '0' & op_b_ff(07 downto 0);
    b_hi_v := '0' & op_b_ff(15 downto 8);

    -- adder core --
    add_lo_v := std_ulogic_vector(unsigned(a_lo_v) + unsigned(b_lo_v) + unsigned(carry_in_v(0 downto 0)));
    add_hi_v := std_ulogic_vector(unsigned(a_hi_v) + unsigned(b_hi_v) + unsigned(add_lo_v(8 downto 8)));

    -- overflow logic for the actual ADDER CORE (thx Edward!): plus + plus = minus || minus + minus = plus --
    ova_16_v := ((not op_a_v(15)) and (not op_b_ff(15)) and add_hi_v(7)) or (op_a_v(15) and op_b_ff(15) and (not add_hi_v(7)));
    ova_8_v  := ((not op_a_v(7))  and (not op_b_ff(7))  and add_lo_v(7)) or (op_a_v(7)  and op_b_ff(7)  and (not add_lo_v(7)));

    -- output --
    add_res(15 downto 0) <= add_hi_v(7 downto 0) & add_lo_v(7 downto 0); -- result
    if (ctrl_i(ctrl_alu_bw_c) = '1') then -- byte mode flags
      add_res(16) <= add_lo_v(8);
      add_res(17) <= ova_8_v;
    else -- word mode flags
      add_res(16) <= add_hi_v(8);
      add_res(17) <= ova_16_v;
    end if;
  end process binary_arithmetic_core;


  -- Decimal Arithmetic Core --------------------------------------------------
  -- -----------------------------------------------------------------------------
  decimal_arithmetic_core: process(op_a_ff, op_b_ff, sreg_i)
    variable dsum_ll_v, dsum_lh_v, dsum_hl_v, dsum_hh_v : std_ulogic_vector(4 downto 0);
  begin
    -- four 4-bit BCD adders --
    dsum_ll_v := bcd_add4_f(op_a_ff(03 downto 00), op_b_ff(03 downto 00), sreg_i(sreg_c_c));
    dsum_lh_v := bcd_add4_f(op_a_ff(07 downto 04), op_b_ff(07 downto 04), dsum_ll_v(4));
    dsum_hl_v := bcd_add4_f(op_a_ff(11 downto 08), op_b_ff(11 downto 08), dsum_lh_v(4));
    dsum_hh_v := bcd_add4_f(op_a_ff(15 downto 12), op_b_ff(15 downto 12), dsum_hl_v(4));

    -- output --
    dadd_res(03 downto 00) <= dsum_ll_v(3 downto 0);
    dadd_res(07 downto 04) <= dsum_lh_v(3 downto 0);
    dadd_res(11 downto 08) <= dsum_hl_v(3 downto 0);
    dadd_res(15 downto 12) <= dsum_hh_v(3 downto 0);
    dadd_res(16) <= dsum_hh_v(4);
  end process decimal_arithmetic_core;


  -- DADD Pipeline Register ---------------------------------------------------
  -- -----------------------------------------------------------------------------
  dadd_pipe_reg: process(clk_i)
  begin
    if rising_edge(clk_i) then
      dadd_res_ff <= dadd_res;
    end if;
  end process dadd_pipe_reg;

  -- implement DADD instruction? --
  dadd_res_in <= dadd_res_ff when (DADD_USE = true) else (others => '0');


  -- ALU Core -----------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  alu_core: process(ctrl_i, op_a_ff, op_b_ff, sreg_i, negative, zero, add_res, dadd_res_in)
  begin
    -- defaults --
    alu_res <= op_a_ff;
    flag_o(flag_c_c) <= sreg_i(sreg_c_c); -- keep
    flag_o(flag_v_c) <= sreg_i(sreg_v_c); -- keep
    flag_o(flag_n_c) <= negative; -- update
    flag_o(flag_z_c) <= zero; -- update

    -- function selection --
    case ctrl_i(ctrl_alu_cmd3_c downto ctrl_alu_cmd0_c) is
      when alu_add_c => -- r <= a + b
        alu_res <= add_res(15 downto 0);
        flag_o(flag_c_c) <= add_res(16);
        flag_o(flag_v_c) <= add_res(17);

      when alu_addc_c => -- r <= a + b + c
        alu_res <= add_res(15 downto 0);
        flag_o(flag_c_c) <= add_res(16);
        flag_o(flag_v_c) <= add_res(17);

      when alu_sub_c => -- r <= b - a
        alu_res <= add_res(15 downto 0);
        flag_o(flag_c_c) <= add_res(16);
        flag_o(flag_v_c) <= add_res(17);

      when alu_subc_c => -- r <= b - a - 1 + c
        alu_res <= add_res(15 downto 0);
        flag_o(flag_c_c) <= add_res(16);
        flag_o(flag_v_c) <= add_res(17);

      when alu_dadd_c => -- r <= a + b + c (decimal)
        alu_res <= dadd_res_in(15 downto 0);
        flag_o(flag_c_c) <= dadd_res_in(16);
        flag_o(flag_v_c) <= '0';

      when alu_cmp_c => -- b - a (no write back, done by ctrl arbiter)
        alu_res <= add_res(15 downto 0);
        flag_o(flag_c_c) <= add_res(16);
        flag_o(flag_v_c) <= add_res(17);

      when alu_and_c => -- r <= a & b
        alu_res <= op_a_ff and op_b_ff;
        flag_o(flag_c_c) <= not zero;
        flag_o(flag_v_c) <= '0';

      when alu_xor_c => -- r <= a xor b
        alu_res <= op_a_ff xor op_b_ff;
        flag_o(flag_c_c) <= not zero;
        flag_o(flag_v_c) <= op_a_ff(15) and op_b_ff(15); -- word mode
        if (ctrl_i(ctrl_alu_bw_c) = '1') then -- byte mode
          flag_o(flag_v_c) <= op_a_ff(7) and op_b_ff(7);
        end if;

      when alu_bic_c => -- r <= !a & b
        alu_res <= (not op_a_ff) and op_b_ff;
        flag_o(flag_c_c) <= sreg_i(sreg_c_c); -- keep
        flag_o(flag_v_c) <= sreg_i(sreg_v_c); -- keep
        flag_o(flag_n_c) <= sreg_i(sreg_n_c); -- keep
        flag_o(flag_z_c) <= sreg_i(sreg_z_c); -- keep

      when alu_bis_c => -- r <= a | b
        alu_res <= op_a_ff or op_b_ff;
        flag_o(flag_c_c) <= sreg_i(sreg_c_c); -- keep
        flag_o(flag_v_c) <= sreg_i(sreg_v_c); -- keep
        flag_o(flag_n_c) <= sreg_i(sreg_n_c); -- keep
        flag_o(flag_z_c) <= sreg_i(sreg_z_c); -- keep

      when alu_bit_c => -- r <= a & b (no write back, done by ctrl arbiter)
        alu_res <= op_a_ff and op_b_ff;
        flag_o(flag_c_c) <= not zero;
        flag_o(flag_v_c) <= '0';

      when alu_rra_c => -- r <= a >> 1, rotate right arithmetically
        alu_res <= op_a_ff(15) & op_a_ff(15 downto 1); -- word mode
        if (ctrl_i(ctrl_alu_bw_c) = '1') then -- byte mode
          alu_res(7) <= op_a_ff(7);
        end if;
        flag_o(flag_c_c) <= op_a_ff(0);
        flag_o(flag_v_c) <= '0';

      when alu_rrc_c => -- r <= a >> 1, rotate right through carry
        alu_res <= sreg_i(sreg_c_c) & op_a_ff(15 downto 1); -- word mode
        if (ctrl_i(ctrl_alu_bw_c) = '1') then -- byte mode
          alu_res(7) <= sreg_i(sreg_c_c);
        end if;
        flag_o(flag_c_c) <= op_a_ff(0);
        flag_o(flag_v_c) <= '0';

      when alu_sxt_c => -- r <= a, sign extend byte
        for i in 8 to 15 loop
          alu_res(i) <= op_a_ff(7);
        end loop;
        alu_res(7 downto 0) <= op_a_ff(7 downto 0);
        flag_o(flag_c_c) <= not zero;
        flag_o(flag_v_c) <= '0';

      when alu_swap_c => -- r <= swap bytes of a
        alu_res <= op_a_ff(7 downto 0) & op_a_ff(15 downto 8);
        flag_o(flag_c_c) <= sreg_i(sreg_c_c); -- keep
        flag_o(flag_v_c) <= sreg_i(sreg_v_c); -- keep
        flag_o(flag_n_c) <= sreg_i(sreg_n_c); -- keep
        flag_o(flag_z_c) <= sreg_i(sreg_z_c); -- keep

      when alu_mov_c => -- r <= a
        alu_res <= op_a_ff;
        flag_o(flag_c_c) <= sreg_i(sreg_c_c); -- keep
        flag_o(flag_v_c) <= sreg_i(sreg_v_c); -- keep
        flag_o(flag_n_c) <= sreg_i(sreg_n_c); -- keep
        flag_o(flag_z_c) <= sreg_i(sreg_z_c); -- keep

      when others => -- undefined
        alu_res <= op_a_ff;
        flag_o(flag_c_c) <= sreg_i(sreg_c_c); -- keep
        flag_o(flag_v_c) <= sreg_i(sreg_v_c); -- keep
        flag_o(flag_n_c) <= sreg_i(sreg_n_c); -- keep
        flag_o(flag_z_c) <= sreg_i(sreg_z_c); -- keep
    end case;
  end process alu_core;


  -- Post processing logic ----------------------------------------------------
  -- -----------------------------------------------------------------------------

  -- word/byte mode mask --
  data_res(07 downto 0) <= alu_res(07 downto 0);
  data_res(15 downto 8) <= alu_res(15 downto 8) when (ctrl_i(ctrl_alu_bw_c) = '0') else x"00";

  -- zero flag --
  zero <= not or_all_f(data_res);

  -- negative flag --
  negative <= data_res(7) when (ctrl_i(ctrl_alu_bw_c) = '1') else data_res(15);

  -- final data output --
  data_o <= data_res;


end neo430_alu_rtl;

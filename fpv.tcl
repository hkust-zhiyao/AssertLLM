set FPV_ROOT    /hpc/home/connect.wfang838/fpv/
set DES_PATH    $FPV_ROOT/rtl
set SVA_PATH    $FPV_ROOT/sva
set FLIST_ROOT  $FPV_ROOT/filelist



analyze -sv -f $FLIST_ROOT/design.f


elaborate -top top_name

clock clk_name
reset rst_name

prove -all

check_cov -measure -type {coi proof}
report -summary -force -result -file design.fpv.rpt

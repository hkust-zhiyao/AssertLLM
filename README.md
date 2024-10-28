# AssertEval: Open Framework and Benchmark for RTL Verification

## Workflow
![image](https://github.com/user-attachments/assets/c3c4ef7d-874d-46fa-b8c1-7b76096a9626)


## Dataset Structure
### 1. Specification document files (folder 'spec')
Contains the complete natural language specifications for the 20 designs. 

### 2. Golden RTL implementations (folder 'rtl')
RTL designs are implemented according to the specifications and verified as functional and correct.

### 3. FPV Script (file 'fpv.tcl')
Please change the design name, top name, clock name, and rst name first.
```
jg fpv.tcl
```

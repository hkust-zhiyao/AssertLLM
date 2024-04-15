# AssertLLM: Generating Hardware Verification Assertions from Design Specifications via Multi-LLMs

## Abstract
Assertion-based verification (ABV) is a critical method for ensuring design circuits comply with their architectural specifications, which are typically described in natural language. This process often requires human interpretation by verification engineers to convert these specifications into functional verification assertions. Existing methods for generating assertions from natural language specifications are limited to sentences extracted by engineers, discouraging its practical application. In this work, we present AssertLLM, an automatic assertion generation framework that processes complete specification document files. AssertLLM breaks down the complex task into three phases, incorporating three customized Large Language Models (LLMs) for extracting structural specifications, mapping signal definitions, and generating assertions. Our evaluation of AssertLLM on a full design, encompassing 23 I/O signals, demonstrates that 89% of the generated assertions are both syntactically and functionally accurate.

## Dataset Structure
### 1. Specification document files (folder 'spec')
Contains the complete natural language specifications for the 20 designs. 

### 2. Golden RTL implementations (folder 'rtl')
RTL designs implemented according to the specifications, and have been verified as functional correct.
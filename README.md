# RSA-accelerator
Intel FPGA RSA crypto-engine
RSA encryption engine

A low-resource, serial RSA engine for Intel FPGA Cyclone V. Mainly suitable for public key operations, implements RSAEP from PKCS #1. Private key operations also work when the key is defined as a pair. This is suboptimal, however, since this engine does not use CRT.

Inspired by: https://ieeexplore.ieee.org/document/1253671 with a few improvements. Unlike the paper, there is no need to precompute the R^2modN whenever a new key is used. A slightly more optimal add/sub structure is also used, which does not require computing the full 2s complement representation of the second term. 

Top level module of the IP block is RSA.sv. This is instantiated inside RSA_tb.sv for verification and RSA_wrapper.sv for running on a Cyclone V. Communication is caried out via a register interface. Valid must be asserted for any request to occur. 

RSA.sv signals
| Signal    | I/O    | Width | Function                                                                                                        |
| --------- | ------ | ----- | --------------------------------------------------------------------------------------------------------------- |
| clk       | input  | 1     | clock                                                                                                           |
| reset\_n  | input  | 1     | synchronous negative edge reset                                                                                 |
| data\_in  | input  | 8     | data input to pass to internal register                                                                         |
| data\_out | output | 8     | outputs data inside selected internal register                                                                  |
| addr      | input  | 1     | specifies internal register:  0=control\_reg, 1= data\_reg                                                       |
| valid     | input  | 1     | Read or write requests only proceed when valid=1. When valid=0, inputs on data\_in, addr and write are ignored. |
| write     | input  | 1     | Select between read or write operation:  0=read, 1=write                                                        |

 
Registers:

control_reg 0x0
| Bit   | 7   | 6   | 5     | 4       | 3       | 2       | 1       | 0     |
| ----- | --  | --  | ----- | ------- | ------- | ------- | ------- | ----- |
| R/W   |  R  |  R  |   R   |   R/W   |   R/W   |   R/W   |   R/W   |  R/W  |
| Field | \-  | \-  | ready | read\_u | load\_n | load\_e | load\_x | start |

data_reg 0x1
| Bit   | 7 -0      |
| ----- | ---------  |
| R/W   |                   R/W                 |
| Field |                data\_reg              |

Ready – when asserted, indicates engine is ready to accept new data or start the next operation. If an operation had previously been started, indicates said operation is complete and result is ready.
Load_n – when set, allows N (modulus) to be inserted/overwritten. 
Load_e – when set, allows E (exponent) to be inserted/overwritten. 
Load_x – when set, allows X (plaintext) to be inserted/overwritten. 
Read_u – when set, begins read back of operation result. 
Start – when set, begins RSA operation. Automatically reset by module, is not a status indicator. When operation completes ready is asserted.

Procedure for passing X, E, N
1. Write to ctrl_reg setting load_n, load_e or load_x bits. Must not be set simultaneously.
2. On the next cycle or any cycle after, write first (least significant) word (8 bits) of X, E or N.
3. Further words can be written on any successive cycle.


Procedure for reading result
1. Write to ctrl_reg setting read_u bits. load_n, load_e or load_x must not be set simultaneously.
2. Wait 4 cycles.
3. Read data_reg register. Contains first (least significant) word (8 bits) of result.
4. Wait one cycle.
5. Read data_reg for next word.
6. Repeat, leaving one cycle between reads.

Simulation
Use Modelsim Intel FPGA edition or Questa Intel FPGA edition. Modify top two lines of /Sim/modelsim/sim.do depending on folder location.

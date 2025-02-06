
#####################################################
####### Configure the SCCB Master Controller ########
# 1. Configure SLV_DVC_ADDR register with value 0x23
    lui x5,0x60000
    addi x5, x5, 0x00
    addi x4, x0, 0x23
    sb x4, 0(x5)

# 2. Soft-reset
## Add sub-address of a SCCB transmission (0x12)
    lui x5,0x68000
    addi x5, x5, 0x01
    addi x4, x0, 0x12
    sb x4, 0(x5)
## Add write data of a SCCB transmission (0x80)
    lui x5,0x68000
    addi x5, x5, 0x02
    addi x4, x0, 0b10000000
    sb x4, 0(x5)
## Start a SCCB Master Controller with a 3-phase write transmission
    lui x5,0x68000
    addi x5, x5, 0x00
    addi x4, x0, 0b00000111
    sb x4, 0(x5)

# 3. Wait for 1 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25)
## 125Mhz: 0x1388 (0d5000)
    lui x7, 0x0010
FLAG0:
    addi x7, x7, -0x01
    bne x7, x0, FLAG0

# 4. COM7
## Add sub-address of a SCCB transmission (0x12)
    lui x5,0x68000
    addi x5, x5, 0x01
    addi x4, x0, 0x12
    sb x4, 0(x5)
## Add write data of a SCCB transmission (0x04)
    lui x5,0x68000
    addi x5, x5, 0x02
    addi x4, x0, 0b00000100
    sb x4, 0(x5)
## Start a SCCB Master Controller with a 3-phase write transmission
    lui x5,0x68000
    addi x5, x5, 0x00
    addi x4, x0, 0b00000111
    sb x4, 0(x5)

# 5. CLKRC
## Add sub-address of a SCCB transmission (0x11)
    lui x5,0x68000
    addi x5, x5, 0x01
    addi x4, x0, 0x11
    sb x4, 0(x5)
## Add write data of a SCCB transmission (0xC0)
    lui x5,0x68000
    addi x5, x5, 0x02
    addi x4, x0, 0b11000000
    sb x4, 0(x5)
## Start a SCCB Master Controller with a 3-phase write transmission
    lui x5,0x68000
    addi x5, x5, 0x00
    addi x4, x0, 0b00000111
    sb x4, 0(x5)

# 6. COM15
## Add sub-address of a SCCB transmission (0x40)
    lui x5,0x68000
    addi x5, x5, 0x01
    addi x4, x0, 0x40
    sb x4, 0(x5)
## Add write data of a SCCB transmission (0xD0)
    lui x5,0x68000
    addi x5, x5, 0x02
    addi x4, x0, 0b11010000
    sb x4, 0(x5)
## Start a SCCB Master Controller with a 3-phase write transmission
    lui x5,0x68000
    addi x4, x0, 0b00000111
    sb x4, 0(x5)

# 7. Wait for all SCCB transactions to send
FLAG_1:
    lb x4, 0(x5)
    bne x4, x0, FLAG_1
####### Configure the SCCB Master Controller ########
#####################################################

#####################################################
######### Configure the DBI TX Controller ###########
# 0.Change mode of the controller to CONFIG mode
    lui x5, 0x20000
    addi x4, x0, 0x01 
    sb x4, 0(x5)

# 1. HW-RST Command
    lui x5, 0x28000             # x5: 0x28000000
    addi x4, x0, 0b00000010    # x4: 0x02          (HW_RST) 
    sb x4, 0(x5)

# 2. Command: SW-RST
    lui x5, 0x28000             # x5: 0x28000000   (TX_TYPE Address)
    addi x4, x0, 0b00000000     # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_COM Address)
    addi x4, x0, 0x01           # x4: 0x02          (Soft_RST Command) 
    sb x4, 0(x5)

# 3. Wait for 6ms after Soft-reset transmission has been sent
    lui x5, 0x28000
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_TYPE Address)
FLAG_2:
    lb x4, 0(x5)                # x4: contain the number of remaining transmission
    bne x4, x0, FLAG_2          # Wait for Soft-reset transmission to send 
    lui x7, 0x0060              # Wait for 6 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25) 
FLAG_3:
    addi x7, x7, -0x01
    bne x7, x0, FLAG_3          # Time-out

# 4. Command: Memory Accress Control
    lui x5, 0x28000             # x5: 0x28000000   (TX_TYPE Address)
    addi x4, x0, 0b00000100     # x4: 0x04          (W-1DATA) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_COM Address)
    addi x4, x0, 0x36           # x4: 0x36          (MemAcs Command) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000002   (TX_DATA Address)
    addi x4, x0, 0x20           # x4: 0x02          (MemAcs Data 1) 
    sb x4, 0(x5)
# 5. Command: Set Column
    lui x5, 0x28000             # x5: 0x28000000   (TX_TYPE Address)
    addi x4, x0, 0b00010000    # x4: 0x10          (W-4DATA) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_COM Address)
    addi x4, x0, 0x2A           # x4: 0x2A          (SetCol Command) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000002   (TX_DATA Address)
    addi x4, x0, 0x00           # x4: 0x00          (SetCol Data 1 - SC[H]) 
    sb x4, 0(x5)
    addi x4, x0, 0x00           # x4: 0x00          (SetCol Data 2 - SC[L]) 
    sb x4, 0(x5)
    addi x4, x0, 0x01           # x4: 0x01          (SetCol Data 3 - EC[H]) 
    sb x4, 0(x5)
    addi x4, x0, 0x3F           # x4: 0x3F          (SetCol Data 4 - EC[L]) 
    sb x4, 0(x5)
# 6. Command: Set Row
    lui x5, 0x28000             # x5: 0x28000000   (TX_TYPE Address)
    addi x4, x0, 0b00010000    # x4: 0x10          (W-4DATA) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_COM Address)
    addi x4, x0, 0x2B           # x4: 0x2B          (SetRow Command) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000002   (TX_DATA Address)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 1 - SR[H]) 
    sb x4, 0(x5)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 2 - SR[L]) 
    sb x4, 0(x5)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 3 - ER[H]) 
    sb x4, 0(x5)
    addi x4, x0, 0xEF           # x4: 0xEF          (SetRow Data 4 - ER[L]) 
    sb x4, 0(x5)
# 7. Command: Display ON
    lui x5, 0x28000             # x5: 0x28000000   (TX_TYPE Address)
    addi x4, x0, 0b00000000    # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_COM Address)
    addi x4, x0, 0x29           # x4: 0x29          (DISP_ON Command)
    sb x4, 0(x5)
# 8. Command: Sleep OUT
    lui x5, 0x28000             # x5: 0x28000000   (TX_TYPE Address)
    addi x4, x0, 0b00000000    # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_COM Address)
    addi x4, x0, 0x11           # x4: 0x11          (SLEEP_OUT Command)
    sb x4, 0(x5)
# 9. Wait for 6ms after Sleep-out transmission has been sent
    lui x5, 0x28000
    addi x5, x5, 0x01           # x5: 0x28000001   (TX_TYPE Address)
FLAG_4:
    lb x4, 0(x5)                # x4: contain the number of remaining transmission
    bne x4, x0, FLAG_4          # Wait for Sleep-out transmission to send 
    lui x7, 0x0060              # Wait for 6 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25) 
FLAG_5:
    addi x7, x7, -0x01
    bne x7, x0, FLAG_5          # Time-out
# 10. Configure: Memory write command
    lui x5, 0x20000
    addi x5, x5, 0x01
    addi x4, x0, 0x2C   # x4: 0x2C - Memory Write command
    sb x4, 0(x5)
# 11. Change mode of the display controller to STREAM mode
    lui x5, 0x20000
    addi x4, x0, 0x02   # x4: 0x02 - STREAM mode encode
    sb x4, 0(x5)
#####################################################
######### Configure the DVP RX Controller ###########
# 1. PXL_MEM_BASE_REG
    lui x5,0x40000
    addi x5, x5, 0x08
    lui x4, 0x20000
    sw x4, 0(x5)

# 2. Start the DVP RX Controller (DVP_STATUS_REG)
    lui x5,0x40000
    addi x5, x5, 0x0
    addi x4, x0, 0b00000001
    sw x4, 0(x5)

EXIT:
    beq x0, x0, EXIT
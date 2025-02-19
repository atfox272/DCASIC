
#####################################################
####### Configure the SCCB Master Controller ########
# 0. Configure SLV_DVC_ADDR register with value 0x23
    lui x5,0x60000
    addi x5, x5, 0x00
    addi x4, x0, 0x23
    sb x4, 0(x5)
# 1. Setup address value
    lui x5,0x68000      # x5: 0x6800_0000 (CONTROL_BUF address)
    lui x6, 0x68000
    addi x6, x6, 0x01   # x6: 0x6800_0001 (SUB_ADDR_BUF address)
    lui x7,0x68000
    addi x7, x7, 0x02   # x7: 0x6800_0002 (WRITE_DATA_BUF address)
# 2. Soft-reset
    addi x4, x0, 0x12
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0b10000000
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x80)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 3. Wait for 1 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25)
    lui x8, 0x0010  # 125Mhz: 0x1388 (0d5000)
FLAG0:
    addi x8, x8, -0x01
    bne x8, x0, FLAG0
# 4. COM7
    addi x4, x0, 0x12
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x12)
    addi x4, x0, 0b00000100
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x04)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 5. CLKRC
    addi x4, x0, 0x11
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x11)
    addi x4, x0, 0b11000000
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0xC0)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 6. COM15
    addi x4, x0, 0x40
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x40)
    addi x4, x0, 0b11010000
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0xD0)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 7. COM13 (0x3D)
    addi x4, x0, 0x3D
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x3D)
    addi x4, x0, 0x81
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x81)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 8. AWBCTR0 (0x6F)
    addi x4, x0, 0x6F
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x6F)
    addi x4, x0, 0x9F
    sb x4, 0(x7)        # Add write data of a SCCB transmission (0x9F)
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 9. RSVD (0xB0 - 0x84)
#     addi x4, x0, 0xB0
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0xB0)
#     addi x4, x0, 0x84
#     sb x4, 0(x7)        # Add write data of a SCCB transmission (0x84)
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 10. CHLF (0x33 - 0x0B)
#     addi x4, x0, 0x33
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission (0x33)
#     addi x4, x0, 0x0B
#     sb x4, 0(x7)        # Add write data of a SCCB transmission (0x0B)
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 11. COM8 -> Enable AGC / AEC
    addi x4, x0, 0x13
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
    addi x4, x0, 0xe5
    sb x4, 0(x7)        # Add write data of a SCCB transmission
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 12. NALG -> Select Histogram-based AEC algorithm
    addi x4, x0, 0xAA
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
    addi x4, x0, 0x94
    sb x4, 0(x7)        # Add write data of a SCCB transmission
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 13. GAIN -> Set gain reg to 0 for AGC
#     addi x4, x0, 0x00
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x00
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 14. AECH
#     addi x4, x0, 0x10
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x00
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 15. Magic configuration (from a recommandation on Github)
#     addi x4, x0, 0x0D
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x40
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# 16. COM9 -> 4x gain AEC
    addi x4, x0, 0x14
    sb x4, 0(x6)        # Add sub-address of a SCCB transmission
    addi x4, x0, 0x18
    sb x4, 0(x7)        # Add write data of a SCCB transmission
    addi x4, x0, 0b00000111
    sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 17. AECGMAX
#     addi x4, x0, 0xA5
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x05
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 18. GFIX
#     addi x4, x0, 0x69
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x06
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission
# # 19. COM11 -> Set [1] to reduce light effect
#     addi x4, x0, 0x3B
#     sb x4, 0(x6)        # Add sub-address of a SCCB transmission
#     addi x4, x0, 0x02
#     sb x4, 0(x7)        # Add write data of a SCCB transmission
#     addi x4, x0, 0b00000111
#     sb x4, 0(x5)        # Start a SCCB Master Controller with a 3-phase write transmission

# 11. Wait for all SCCB transactions to send
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
# Setup address value
    lui x5, 0x28000             # x5: 0x2800_0000 (TX_TYPE address)
    addi x6, x5, 0x01           # x6: 0x2800_0001 (TX_COM Address)
    addi x7, x5, 0x02           # x5: 0x2800_0002 (TX_DATA Address)
# 1. HW-RST Command
    addi x4, x0, 0b00000010     # x4: 0x02          (HW_RST) 
    sb x4, 0(x5)                # Add HW-RST Command
# 2. Command: SW-RST
    addi x4, x0, 0b00000000     # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)                # Add TX_TYPE 
    addi x4, x0, 0x01            
    sb x4, 0(x6)                # Add Soft_RST Command
# 3. Wait for 6ms after Soft-reset transmission has been sent
FLAG_2:
    lb x4, 0(x5)                # x4: contain the number of remaining transmission
    bne x4, x0, FLAG_2          # Wait for Soft-reset transmission to send 
    lui x8, 0x0060              # Wait for 6 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25) 
FLAG_3:
    addi x8, x8, -0x01
    bne x8, x0, FLAG_3          # Time-out
# 4. Command: Memory Accress Control
    addi x4, x0, 0b00000100     # x4: 0x04          (W-1DATA) 
    sb x4, 0(x5)                # Add W-1DATA to TX_TYPE
    addi x4, x0, 0x36           # x4: 0x36          (MemAcs Command) 
    sb x4, 0(x6)                # Add MemAcs Command to TX_TYPE
    addi x4, x0, 0x20           # x4: 0x20          (MemAcs Data 1) 
    sb x4, 0(x7)                # Add WrData to TX_DATA
# 5. Command: Interface Pixel Format
    addi x4, x0, 0b00000100     # x4: 0x04          (W-1DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x3A           # x4: 0x3A          (Command) 
    sb x4, 0(x6)
    addi x4, x0, 0x55           # x4: 0x05          (Data 1: 16bit pxl) 
    sb x4, 0(x7)
# 5. Command: Set Column
    addi x4, x0, 0b00010000    # x4: 0x10          (W-4DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x2A           # x4: 0x2A          (SetCol Command) 
    sb x4, 0(x6)
    addi x4, x0, 0x00           # x4: 0x00          (SetCol Data 1 - SC[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0x00           # x4: 0x50          (SetCol Data 2 - SC[L]) 
    sb x4, 0(x7)
    addi x4, x0, 0x01           # x4: 0x01          (SetCol Data 3 - EC[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0x3F           # x4: 0x3F          (SetCol Data 4 - EC[L]) 
    sb x4, 0(x7)
# 6. Command: Set Row
    addi x4, x0, 0b00010000    # x4: 0x10          (W-4DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x2B           # x4: 0x2B          (SetRow Command) 
    sb x4, 0(x6)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 1 - SR[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 2 - SR[L]) 
    sb x4, 0(x7)
    addi x4, x0, 0x00           # x4: 0x00          (SetRow Data 3 - ER[H]) 
    sb x4, 0(x7)
    addi x4, x0, 0xEF           # x4: 0xEF          (SetRow Data 4 - ER[L]) 
    sb x4, 0(x7)
# 7. Command: Sleep OUT
    addi x4, x0, 0b00000000    # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x11           # x4: 0x11          (SLEEP_OUT Command)
    sb x4, 0(x6)
# 8. Wait for 6ms after Sleep-out transmission has been sent
FLAG_4:
    lb x4, 0(x5)                # x4: contain the number of remaining transmission
    bne x4, x0, FLAG_4          # Wait for Sleep-out transmission to send 
    lui x8, 0x0060              # Wait for 6 ms (BOUNDARY = CLK_FREQ/(1/(10^(-3))) / 25) 
FLAG_5:
    addi x8, x8, -0x01
    bne x8, x0, FLAG_5          # Time-out
# 9. Command: Display ON
    addi x4, x0, 0b00000000     # x4: 0x02          (W-0DATA) 
    sb x4, 0(x5)
    addi x4, x0, 0x29           # x4: 0x29          (DISP_ON Command)
    sb x4, 0(x6)
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

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
FLAG_0:
addi x7, x7, -0x01
bne x7, x0, FLAG_0

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
# 0.HW-RST Command
lui x5, 0x21000 
# 1. DBI_ADDR_SOFT_RST_REG (addr: 0x2000_0001)
lui x5,0x20000
addi x5, x5, 0x01
addi x4, x0, 0x01
sb x4, 0(x5)

# 2. DBI_ADDR_DISP_ON_REG (addr: 0x2000_0002)
addi x5, x5, 0x01
addi x4, x0, 0x29
sb x4, 0(x5)

# 3. DBI_ADDR_SET_COL_REG(addr: 0x2000_0003)
addi x5, x5, 0x01
addi x4, x0, 0x2A
sb x4, 0(x5)

# 4. DBI_ADDR_SET_ROW_REG(addr: 0x2000_0004)
addi x5, x5, 0x01
addi x4, x0, 0x2B
sb x4, 0(x5)

# 5. DBI_ADDR_SET_PIXEL_REG(addr: 0x2000_0005)
addi x5, x5, 0x01
addi x4, x0, 0x2C
sb x4, 0(x5)

# 6. DBI_CMD_START_COLUMN_H_REG(addr: 0x2000_0006)
addi x5, x5, 0x01
addi x4, x0, 0x00
sb x4, 0(x5)

# 7. DBI_CMD_START_COLUMN_L_REG(addr: 0x2000_0007)
addi x5, x5, 0x01
addi x4, x0, 0x00
sb x4, 0(x5)

# 8. DBI_CMD_END_COLUMN_H_REG(addr: 0x2000_0008)
addi x5, x5, 0x01
addi x4, x0, 0x01
sb x4, 0(x5)

# 9. DBI_CMD_END_COLUMN_L_REG(addr: 0x2000_0009)
addi x5, x5, 0x01
addi x4, x0, 0x3F
sb x4, 0(x5)

# A. DBI_CMD_START_ROW_H_REG(addr: 0x2000_000A)
addi x5, x5, 0x01
addi x4, x0, 0x00
sb x4, 0(x5)

# B. DBI_CMD_START_ROW_L_REG(addr: 0x2000_000B)
addi x5, x5, 0x01
addi x4, x0, 0x00
sb x4, 0(x5)

# C. DBI_CMD_END_ROW_H_REG(addr: 0x2000_000C)
addi x5, x5, 0x01
addi x4, x0, 0x00
sb x4, 0(x5)

# D. DBI_CMD_END_ROW_L_REG(addr: 0x2000_000D)
addi x5, x5, 0x01
addi x4, x0, 0xEF
sb x4, 0(x5)

# E. DBI_ADDR_MEM_ACS_CTRL_REG(addr: 0x2000_000E)
addi x5, x5, 0x01
addi x4, x0, 0x36
sb x4, 0(x5)

# F. DBI_CMD_MEM_ACS_CTRL_REG(addr: 0x2000_000F)
addi x5, x5, 0x01
addi x4, x0, 0x00
sb x4, 0(x5)

# 10. Start DBI TX Controller 
lui x5,0x20000
addi x4, x0, 0x01
sb x4, 0(x5)

# 11. Waiting for 120ms (BOUNDARY = CLK_FREQ/(1/(120*10^(-3))) / 25)
# 125Mhz: 600_000 (0x0009_27C0)
# 
lui x7, 0x11
FLAG_2:
addi x7, x7, -0x01
bne x7, x0, FLAG_2
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
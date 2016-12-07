  .code16

  .text
  .globl _start
_start:
  jmp _boot
data:  .byte 'X'
data1:  .byte 'Z'

_boot:
  movw $0x07c0, %ax
  movw %ax, %ds           # set ds = 16 * 0x07c0 = 0x7c00

  # Now we will copy the data at position 3 from 0x7c00:0x0000 and then print
  # it onto the screen.
  movb 0x02, %al
  movb $0x0e, %ah
  int $0x10

  # Now we will copy the data at position 4 from 0x7c00:0x0000 and then print
  # it onto the screen.
  movb 0x03, %al
  movb $0x0e, %ah
  int $0x10

_freeze:
  jmp _freeze
  . = _start + 510         # move to 510th byte from 0 pos.
  .byte 0x55               # append boot signature
  .byte 0xaa               # append boot signature

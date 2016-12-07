  .code16

  .text
  .globl _start
_start:
  jmp _boot
data: .asciz "This is boot loader"

  # Calls the printString function which starts printing string from the
  # position.
  .macro mprintString start_pos
  pushw %si
  movw \start_pos, %si
  call printString
  popw %si
  .endm

printString:
printStringIn:
  lodsb
  orb %al, %al
  jz printStringOut
  movb $0x0e, %ah
  int $0x10
  jmp printStringIn
printStringOut:
  ret

_boot:
  movw $0x07c0, %ax
  movw %ax, %ds           # set ds = 16 * 0x07c0 = 0x7c00

  mprintString $0x02

_freeze:
  jmp _freeze
  . = _start + 510         # move to 510th byte from 0 pos.
  .byte 0x55               # append boot signature
  .byte 0xaa               # append boot signature

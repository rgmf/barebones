  .code16

  .section .text
  .globl _start
_start:
  movl $0x5, %edx

_freeze:
  jmp _freeze

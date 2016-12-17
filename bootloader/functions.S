  .equ PBIOS,           0x10       # BIOS interrupt vector for print services.
  .equ print_service,   0x0e       # BIOS print service.

  .section .text
  .globl print_string
  .type print_string, @function
  # Function to print null terminated string.
print_string:
  lodsb
  orb %al, %al
  jz print_string_out
  movb $print_service, %ah
  int $PBIOS
  jmp print_string
print_string_out:
  ret

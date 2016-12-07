  .code16

  .text
  .globl _start
_start:
  jmp _boot         # jump to the boot code to start execution.

msg_fail:
  .asciz "Something has gone wrong..."

  # Macro to print null terminated string this macro calls function
  # print_string.
  .macro m_print_string str
  leaw \str, %si
  call print_string
  .endm

  # Function to print null terminated string.
print_string:
  lodsb
  orb %al, %al
  jz print_string_out
  movb $0x0e, %ah
  int $0x10
  jmp print_string
print_string_out:
  ret

  # Macro to read a sector from a floppy disk and load it at extended segment.
  .macro m_read_sector_from_floppy num
  movb $0x02, %ah       # read disk function.
  movb $0x01, %al       # total sectors to read.
  movb $0x00, %ch       # select cylinder zero.
  movb $0x00, %dh       # select head zero.
  movb \num, %cl        # start reading from this sector.
  movb $0x00, %dl       # drive number
  int $0x13             # interrupt cpu to et this job done now.
  jc _failure           # if fails then throw error.
  cmpb $0x01, %al       # if total sectors read != 1.
  jne _failure          # then throw error.
  .endm

  # Display the string that we have inserted as the identifier of the sector.
display_data:
display_data_in:
  movb %es:(%bx), %al
  orb %al, %al
  jz display_data_out
  movb $0x0e, %ah
  int $0x10
  incw %bx
  jmp display_data_in
display_data_out:
  ret


_boot:
  movw $0x07c0, %ax             # initialize the data segment.
  movw %ax, %ds                 # to 0x7c00 location.
  movw $0x1000, %ax             # set ax = 0x1000.
  movw %ax, %es                 # set es = 0x1000 = ax.
  xorw %bx, %bx                 # set bx = 0.
  m_read_sector_from_floppy $2  # read sector from floppy disk.

  # Far jump. with this instruction it modifies cs segment register with the
  # first value. The other one is an offset.
  ljmp $0x1000, $0x0000
  #call display_data             # display the label of the sector.
  #m_read_sector_from_floppy $3  # read 3rd sector from floppy disk.
  #call display_data             # display the label of the sector.

_freeze:
  jmp _freeze

_failure:
  m_print_string msg_fail
  jmp _freeze

  . = _start + 510              # mov to 510th byte from 0 pos.
  .byte 0x55                    # first signature's part.
  .byte 0xaa                    # second signature's part.

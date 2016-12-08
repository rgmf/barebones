  # Names to all the magic numbers I am using.
  .equ stage2_base,     0x1000  # where os will be load.
  .equ stage2_offset,   0x0000

  .equ DBIOS,           0x13    # BIOS interrupt vector for disk services.
  .equ disk_read,       0x02    # disk read service.

  .equ PBIOS,           0x10    # BIOS interrupt vector for print services.
  .equ print_service,   0x0e    # BIOS print service.

  
  # Begin the code after the definitions.
  .code16

  .text
  .globl _start
_start:
  jmp _boot         # jump to the boot code to start execution.
  

msg_fail:
  .asciz "Something was wrong..."

  # Macro to print null terminated string. This macro calls function
  # print_string.
  .macro m_print_string str
  leaw \str, %si
  call print_string
  .endm


  # Macro to read a sector from a floppy disk and load it at extended segment.
  .macro m_read_sector_from_floppy num
  movb $disk_read, %ah  # read disk function.
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

  
_boot:
  movw $0x07c0, %ax             # initialize the data segment.
  movw %ax, %ds                 # to 0x7c00 location.
  movw $stage2_base, %ax        # set ax = 0x1000.
  movw %ax, %es                 # set es = 0x1000 = ax.
  xorw %bx, %bx                 # set bx = 0.
  m_read_sector_from_floppy $2  # read sector from floppy disk.

  # Far jump. With this instruction it modifies cs segment register with the
  # first value. The other one is an offset.
  ljmp $stage2_base, $stage2_offset

_freeze:
  jmp _freeze

_failure:
  m_print_string msg_fail
  jmp _freeze

  . = _start + 510              # mov to 510th byte from 0 pos.
  .byte 0x55                    # first signature's part.
  .byte 0xaa                    # second signature's part.

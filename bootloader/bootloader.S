################################################################################
## Names to all the magic numbers I am using.
##############################################################################*/
  .equ stage2_base,     0x1000     # where os will be load. Base and
  .equ stage2_offset,   0x0000     # offset.

  .equ PBIOS,           0x10       # BIOS interrupt vector for print services.
  .equ print_service,   0x0e       # BIOS print service.

  .equ DBIOS,           0x13       # BIOS interrupt vector for disk services.
  .equ disk_read,       0x02       # disk read service.

  .equ MBIOS,           0x15       # BIOS upper memory detection interrupt.
  .equ mem_detection,   0xe820     # upper memory detection service.

  .equ md_begin_buffer, 0x0800     # buffer list memory detection.
                                   # I put this list here because this RAM is
                                   # guaranteed free. This is the value that
                                   # will be load in ES register. When use
                                   # ES:DI then the phisical address will be:
                                   # ES * 0x10 + BX. See:
                                   # http://wiki.osdev.org/Memory_Map_(x86))

  .equ vesa_begin_buffer, 0x07e0   # The begin of the 512 bytes buffer for
                                   # VASA BIOS information structure.

  .equ BVESAINF,          0x10     # VESA BIOS information functions.
  .equ vesa_service,      0x4f00   # VESA function information.


################################################################################
## Begin the code after the definitions.
##############################################################################*/
  .code16

################################################################################
## MACROS.
##############################################################################*/
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

################################################################################
## START.
################################################################################
  .text
  .globl _start
_start:

######################## MEMORY DETECTION
_mem_detection:
  movw $md_begin_buffer, %ax
  movw %ax, %es
  movw $0x0, %di
  xorl %ebx, %ebx
_mem_detection_next:
  movw $1, %es:24(%di)          # sets that last uint64_t to 1 before each call,
                                # to make your map compatible with ACPI
  movl $0x534d4150, %edx
  movl $24, %ecx
  movl $mem_detection, %eax
  int $MBIOS
  jc _mem_detection_finish
  testl %ebx, %ebx
  je _mem_detection_finish
  
_mem_detection_ignore_test:
  # Is the second 64 bits 0? Then it ignores the entry.
  movl %es:8(%di), %ecx
  orl %es:12(%di), %ecx
  jecxz _mem_detection_next
  addw $24, %di
  jmp _mem_detection_next

_mem_detection_finish:  

######################## DETECTING AVAILABLE VIDEO MODES
  xorl %eax, %eax
  movw $vesa_begin_buffer, %ax
  movw %ax, %es
  movw $0x0, %di
  movw $vesa_service, %ax
  int $BVESAINF
  cmp $0x004f, %ax
  jne _failure


######################## LOAD THE SECOND SECTOR WHERE OS IS
_boot:
  clc
  xorw %bx, %bx
  
  movw $0x07c0, %ax             # initialize the data segment.
  movw %ax, %ds                 # to 0x7c00 location.
  movw $stage2_base, %ax        # set ax = 0x1000.
  movw %ax, %es                 # set es = 0x1000 = ax.
  xorw %bx, %bx                 # set bx = 0.
  m_read_sector_from_floppy $2  # read sector from floppy disk.

  # Far jump. With this instruction it modifies cs segment register with the
  # first value. The other one is an offset.
  ljmp $stage2_base, $stage2_offset


################################################################################
## FUNCTIONS.
##############################################################################*/
print_string:
  lodsb
  orb %al, %al
  jz print_string_out
  movb $print_service, %ah
  int $PBIOS
  jmp print_string
print_string_out:
  ret

  
_freeze:
  jmp _freeze


_failure:
  m_print_string msg_fail
  jmp _freeze
  

msg_fail:
  .asciz "Something was wrong..."

  . = _start + 510              # mov to 510th byte from 0 pos.
  .byte 0x55                    # first signature's part.
  .byte 0xaa                    # second signature's part.

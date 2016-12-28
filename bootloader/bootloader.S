################################################################################
## Names to all the magic numbers I am using.
################################################################################
  .equ stage2_base_rm,   0x1000     # where os will be load. Base and
  .equ stage2_offset_rm, 0x0000     # offset. (es=0x1000, bx=0x0 => 0x10000).
                                    # Don't forget: addr = segment * 16 + offset
                                    # In Real Mode.

  .equ stage2_offset,    0x10000    # offset where os is in the GDT in protected
                                    # mode.
  
  .equ code_selector,    0x08       # code selector in protected mode (GDT).
  .equ data_selector,    0x10       # data selector in protected mode (GDT).

  .equ PBIOS,            0x10       # BIOS interrupt vector for print services.
  .equ print_service,    0x0e       # BIOS print service.

  .equ DBIOS,            0x13       # BIOS interrupt vector for disk services.
  .equ disk_read,        0x02       # disk read service.

  .equ MBIOS,            0x15       # BIOS upper memory detection interrupt.
  .equ mem_detection,    0xe820     # upper memory detection service.
  .equ mem_a20_enable,   0x2401     # a20 gate enable BIOS service.

  .equ md_begin_buffer,  0x0800     # buffer list memory detection.
                                    # I put this list here because this RAM is
                                    # guaranteed free. This is the value that
                                    # will be load in ES register. When use
                                    # ES:DI then the phisical address will be:
                                    # ES * 0x10 + BX. See:
                                    # http://wiki.osdev.org/Memory_Map_(x86))

  .equ vesa_begin_buffer, 0x07e0    # The begin of the 512 bytes buffer for
                                    # VASA BIOS information structure.

  .equ BVESAINF,          0x10      # VESA BIOS information functions.
  .equ vesa_service,      0x4f00    # VESA function information.


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
  cli

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
  

######################## TODO: DETECTING AVAILABLE VIDEO MODES
  #xorl %eax, %eax
  #movw $vesa_begin_buffer, %ax
  #movw %ax, %es
  #movw $0x0, %di
  #movw $vesa_service, %ax
  #int $BVESAINF
  #cmp $0x004f, %ax
  #jne _failure

######################## TESTING A20 LINE AND ENABLED IT IF NEEDED
  # Turning on the 21st address line is unfortunately a bit arcane. There are
  # various ways to do it, and it’s necessary to implement them all since you
  # never know which processor (well, at least 80386 or better) you’re running
  # on. Here’s what you do, in order:
  #
  # 1.- Test if the A20 line is already enabled.
  # 2.- Use a BIOS function.
  # 3.- Use the keyboard controller.
  # 4.- The "Fast A20" method.
  call check_a20
  testw %ax, %ax        # if ax == 1 a20 is enabled so jmp to _end_a20
  jnz _end_a20
  call enable_a20       # else it going to enable it

  ####### 1.- TEST A 20 LINE
  # Check if a a20 gate is enable. It uses $0x500 and $0x510 addresses to test
  # it.
  #
  # return: ax = 0 if a20 is disabled.
  #         ax = 1 if a20 is enabled.
check_a20:
  pushf
  pushw %ds
  pushw %es
  pushw %di
  pushw %si

  xorw %ax, %ax         # ax = 0x0000
  movw %ax, %es

  notw %ax              # ax = 0xffff
  movw %ax, %ds

  movw $0x0500, %di
  movw $0x0510, %si

  movb %es:(%di), %al   # save byte 0000:0500 in stack
  pushw %ax

  movb %ds:(%si), %al   # save byte ffff:0510 in stack
  pushw %ax

  movb $0x00, %es:(%di) # vove 0x00 to 0000:0500
  movb $0xff, %ds:(%si) # vove 0xff to ffff:0510

  cmpb $0xff, %es:(%di) # if 0000:0500 have ff then the memory cannot address
                        # above 1MiB so the line is not enabled.

  popw %ax              # restore all stack values.
  movb %al, %ds:(%si)

  popw %ax
  movb %al, %es:(%di)

  movw $0x0, %ax        # if memory does wrapped around (a20 disabled)
  je _check_a20_exit
  
  movw $0x1, %ax        # else (a20 enabled)

_check_a20_exit:
  popw %si
  popw %di
  popw %es
  popw %ds
  popf
  ret

  # Enable the a20 gate. It tries with three methods.
enable_a20:
_enable_a20_bios:
  movw $mem_a20_enable, %ax
  int $MBIOS

  call check_a20
  testw %ax, %ax        # if ax == 1 a20 is enabled so jmp to _end_a20
  jnz _end_a20
                        # else it going to the next method.

_enable_a20_8042_keyboard:
  # The keyboard controller can sometimes be used to enable the A20 line (on
  # any chipset where the A20 line was routed through the keyboard controller).
  # Here’s the recipe to do it:
  #
  # - Disable the keyboard (send command 0xad to the keyboard controller)
  # - Tell controller that we want to read input (send command 0xd0)
  # - Read one byte of input
  # - Tell the controller that we want to write output (send command 0xd1)
  # - In the byte just read, enable bit #2 and write it to the controller
  # - Enable the keyboard (send command 0xae)
  call a20_wait
  movb $0xad, %al
  out %al, $0x64

  call a20_wait
  movb $0xd0, %al
  out %al, $0x64

  call a20_wait2
  in $0x60, %al
  pushl %eax

  call a20_wait
  movb $0xd1, %al
  out %al, $0x64

  call a20_wait
  popl %eax
  or $0x2, %al
  out %al, $0x60

  call a20_wait
  movb $0xae, %al
  out %al, $0x64

  call a20_wait

  call check_a20
  testw %ax, %ax        # if ax == 1 a20 is enabled so jmp to _end_a20
  jnz _end_a20
                        # else it going to the next method.
  jmp _enable_a20_fast

a20_wait:
  in $0x64, %al
  testb $2, %al
  jnz a20_wait
  ret

a20_wait2:
  in $0x64, %al
  testb $0x1, %al
  jz a20_wait2
  ret

_enable_a20_fast:
  in $0x92, %al
  orb $0x2, %al
  out %al, $0x92
  
_end_a20:

######################## LOAD THE SECOND SECTOR WHERE OS IS
_boot:
  clc
  xorw %bx, %bx

  # Load the OS at 0x1000 * 0x10 + 0x0 = 0x10000 address.
  movw $stage2_base_rm, %ax     # set ax = 0x1000.
  movw %ax, %es                 # set es = 0x1000 = ax.
  xorw %bx, %bx                 # set bx = 0.
  m_read_sector_from_floppy $2  # read sector from floppy disk.

######################## ENTER TO PROTECTED MODE
_protected_mode:
  #xchgw %bx, %bx
  lgdt gdt_ptr
  
  movl %cr0, %eax
  orl $1, %eax
  movl %eax, %cr0

  mov $data_selector, %ax
  mov %ax, %ds
  mov %ax, %es
  mov %ax, %fs
  mov %ax, %gs
  mov %ax, %ss

  # Far jump. With this instruction it modifies cs segment register with the
  # first value. The other one is an offset.
  ljmp $code_selector, $_code32

######################## JUMP TO THE OS CODE
  # Here it is in protected mode. It can to jump to OS that is at 0x10000
  # address.
  .code32
_code32:
  ljmp $code_selector, $stage2_offset


################################################################################
## GENERAL FUNCTIONS.
################################################################################
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
  

#gdt:
#  .quad 0x0000000000000000
#  .quad 0x00CF9A000000FFFF
#  .quad 0x00CF92000000FFFF
#  .quad 0x00CFFA000000FFFF
#  .quad 0x00CFF2000000FFFF
#gdt_ptr:
#  .word . - gdt - 1
#  .long gdt
  
gdt:
  .quad 0x0000000000000000  # empty entry
  .quad 0x00cf9a000000ffff  # code entry
  .quad 0x00cf92000000ffff  # data entry

gdt_ptr:
  .word gdt_ptr - gdt - 1       # Length of gdt
  .long gdt                     # Base address of gdt
  
msg_fail:
  .asciz "Something was wrong..."

  . = _start + 510              # mov to 510th byte from 0 pos.
  .byte 0x55                    # first signature's part.
  .byte 0xaa                    # second signature's part.

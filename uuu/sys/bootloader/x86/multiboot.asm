; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/multiboot.asm,v 1.1 2003/11/18 18:35:18 bitglue Exp $
;---------------------------------------------------------------------------==|
; stage2 bootloader for Unununium
; multiboot related functions
;
; This provides the glue needed to use boot images loaded as modules from a
; multiboot compliant bootloader. For information on the multiboot standard,
; see http://www.uruk.org/orig-grub/boot-proposal.html
;---------------------------------------------------------------------------==|
; Contributors:
;
; 2003-11-18	Phil Frost	Initial version



;---------------===============\             /===============---------------
;				configuration
;---------------===============/             \===============---------------

%include "stage2-config.asm"



;---------------===============\                /===============---------------
;				external symbols
;---------------===============/                \===============---------------

extern print_string
extern print_nul_string
extern print_hex



;---------------===============\              /===============---------------
;				global symbols
;---------------===============/              \===============---------------

global multiboot_setup
global builtin_mbinfo



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------




;-----------------------------------------------------------------------.
						multiboot_setup:	;
  cmp eax, MULTIBOOTED
  jnz .no_mboot

  mov [info], ebx

.no_mboot:
  retn



;-----------------------------------------------------------------------.
						builtin_mbinfo:		;
  mov bl, VGA_WHITE
  mov ebp, [info]
  test ebp, ebp
  jnz .mboot

  printstr "Not loaded from multiboot bootloader",0xa
  retn

.mboot:
  printstr "Flags:"

  test dword[ebp+mboot_info.flags], MBOOT_INFO_MEM
  jz .no_mem

  printstr " MEM"
.no_mem:
  test dword[ebp+mboot_info.flags], MBOOT_INFO_BOOT_DEVICE
  jz .no_boot_device

  printstr " BOOT_DEVICE"
.no_boot_device:
  test dword[ebp+mboot_info.flags], MBOOT_INFO_CMDLINE
  jz .no_cmdline

  printstr " CMDLINE"
.no_cmdline:

  test dword[ebp+mboot_info.flags], MBOOT_INFO_MODULES
  jz .no_modules

  printstr " MODULES"
.no_modules:
  test dword[ebp+mboot_info.flags], MBOOT_INFO_AOUT_SYMS
  jz .no_aout_syms

  printstr " AOUT_SYMS"
.no_aout_syms:
  test dword[ebp+mboot_info.flags], MBOOT_INFO_ELF_SYMS
  jz .no_elf_syms

  printstr " ELF_SYMS"
.no_elf_syms:
  test dword[ebp+mboot_info.flags], MBOOT_INFO_MMAP
  jz .no_mmap

  printstr " MMAP"
.no_mmap:
  printstr 0xa


  test dword[ebp+mboot_info.flags], MBOOT_INFO_MEM
  jz .no_mem2

  printstr "memory lower/upper: "
  mov edx, [ebp+mboot_info.mem_lower]
  call print_hex
  printstr "/"
  mov edx, [ebp+mboot_info.mem_upper]
  call print_hex
  printstr 0xa
.no_mem2:
  test dword[ebp+mboot_info.flags], MBOOT_INFO_BOOT_DEVICE
  jz .no_boot_device2

  printstr "boot device: "
  mov bh, 2
  mov edx, [ebp+mboot_info.boot_device]
  call print_hex
  printstr 0xa

.no_boot_device2:
  test dword[ebp+mboot_info.flags], MBOOT_INFO_CMDLINE
  jz .no_cmdline2

  printstr "kernel command line: "
  mov esi, [ebp+mboot_info.cmdline]
  call print_nul_string
  printstr 0xa
.no_cmdline2:

  test dword[ebp+mboot_info.flags], MBOOT_INFO_MODULES
  jz .no_modules2

  printstr "modules:",0xa

  push ebp

  mov ecx, [ebp+mboot_info.mods_count]
  test ecx, ecx
  jz .modules_done
  mov ebp, [ebp+mboot_info.mods_addr]
.print_mod:
  printstr "  "
  mov edx, [ebp+mboot_module.mod_start]
  call print_hex
  printstr "-"
  mov edx, [ebp+mboot_module.mod_end]
  call print_hex
  printstr ": "
  mov esi, [ebp+mboot_module.string]
  call print_nul_string
  printstr 0xa

  add ebp, byte mboot_module_size
  dec ecx
  jnz .print_mod
.modules_done:

  pop ebp
.no_modules2:

  test dword[ebp+mboot_info.flags], MBOOT_INFO_MMAP
  jz .no_mmap2

  printstr "memory map:",0xa
  mov ecx, [ebp+mboot_info.mmap_length]
  mov ebp, [ebp+mboot_info.mmap_addr]
  add ecx, ebp
.print_mmap:
  printstr "  at "
  mov edx, [ebp+mboot_mmap.base_high]
  call print_hex
  mov edx, [ebp+mboot_mmap.base_low]
  call print_hex
  printstr ", "
  mov edx, [ebp+mboot_mmap.length_high]
  call print_hex
  mov edx, [ebp+mboot_mmap.length_low]
  call print_hex
  printstr " bytes "

  cmp dword[ebp+mboot_mmap.type], byte 1
  jnz .reserved
  printstr "availible",0xa
  jmp short .next_mmap
.reserved:
  printstr "reserved",0xa
.next_mmap:
  mov eax, [ebp-4]
  cmp eax, 20
  jb .insane_mmap
  add ebp, eax
  cmp ebp, ecx
  jb .print_mmap
.no_mmap2:

  retn

.insane_mmap:
  mov bl, VGA_RED
  printstr "  insane memory map detected",0xa
  retn


  
;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

info:	resd 1

global _start
_start:
  mov esi, moo_str
  mov edi, 0xb8000
  mov ah, 0x07

  mov ecx, 80*25

.print_char:
  lodsb
  stosw
  loop .print_char

  cli
  jmp $

moo_str: incbin "uuu-logov2.txt"

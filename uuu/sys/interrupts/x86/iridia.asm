; Iridia IRQ channels
; Copyright(C) 2002-2004, Dave Poirier
; Distributed under the BSD License
;
;
; IRQ channels allow multiple clients to receive IRQ notification without
; requiring those clients to keep track of the previous handler.  They simply
; care to connect and disconnect themselves from the channels.
;
;
; IRQ related functions:
;-----------------------
; irq.connect
; irq.disconnect
; irq.relocate_table
;--
;
; GDT related functions:
;-----------------------
; gdt.add_descriptor
; gdt.remove_descriptor
; gdt.relocate_table
;--
;
; CPU Exception/Fault related functions:
;---------------------------------------
; int.set_handler
; int.unset_handler
;--
;
; Note: Some parts of the code use Self-Modifying Code, the instructions being
; modified are identified with a [SMC] at the start of the comments.

%include "thread.asm"
%include "interrupts.asm"
%include "ring_queue.asm"

%include "bochs.asm"

extern ring_queue.prepend
extern ring_queue.unlink


section .text

global __interrupt_init
__interrupt_init:

;----------------------------------------------------------------[ _start ]--
					; setup GDT
					;------------------------------------
  mov edi, 0x30 * 8			; size of IDT
  mov esi, gdt				;
  times 4 movsd				;
  sub edi, (gdt.end - gdt) + 8		;
  push edi				;
  push word (gdt.end - gdt) + 7		;
  lgdt [esp]				;
  add esp, byte 6			;
					;
  mov eax, 0x20	-1			; 32 reserved interrupts by Intel
.set_unhandled:				;--
  push eax
  mov ebx, _unhandled_interrupt		; get pointer to unhandled handler
  ecall int.set_handler, CONT, CONT	; set interrupt handler address
  pop eax
  dec eax				; select previous interrupt number
  jnl .set_unhandled			; loop for all reserved interrupts
					;--
  mov esi, 0x0000000F			; number of IRQ supported by chipset
.set_irq_handlers:			;--
  lea eax, [esi + 0x20]			; get int number associated to IRQ
  lea ebx, [esi*4 + _irq_0]		; get last IRQ handler's address
  mov ecx, _irq_0
  ecall int.set_handler, CONT, CONT	; set the interrupt handler
  dec esi				;
  jns short .set_irq_handlers		;
					;--
ENTER_CRITICAL_SECTION			;
  lidt [idtr]				; load IDTR with size/address of IDT
					;--
  lea edx, [ecx + 0x20]			; load edx with 0x00000020
  mov esi, pic.sequence.master		; set initialization sequence
  call send_pic_sequence		; initialize Master PIC
  					; esi now points to pic.sequence.slave
  add edx, byte 0xA0-0x21		; set edx to 0x000000A0
  call send_pic_sequence		; initialize Slave PIC
					;
LEAVE_CRITICAL_SECTION			;
  sti					;
  retn					; end of initialization
;-----------------------------------------------------------------------------
idtr: dw 0x30 * 8 - 1			; 0x30 entries, IDTR.size is 0x17F
      dd 0				; physical address 0
					;
					; PIC 82C59A Initialization Sequence
pic.sequence.master:			;-----------------------------------
db 0x11, 0x20, 0x04, 0x1D, 0xFB		; Master PIC
pic.sequence.slave:			;
db 0x11, 0x28, 0x02, 0x19, 0xFF		; Slave PIC
					;
					; Default Initial GDT
gdt:					;-------------------------------------
dd 0x0000FFFF, 0x00CF9B00		; code segment, 4GB r/x
dd 0x0000FFFF, 0x00CF9300		; data segment, 4GB r/w
.end:					;
					;
send_pic_sequence:			;
  lodsb					; load icw0
  out dx, al				; send icw0 to pic address+0
  inc edx				; select pic address+1
  lodsb					; load icw1
  out dx, al				; send icw1 to pic address+1
  lodsb					; load icw2
  out dx, al				; send icw2 to pic address+1
  lodsb					; load icw3
  out dx, al				; send icw3 to pic address+1
  lodsb					; load irq mask
  out dx, al				; send irq mask to pic address+1
  retn					;
;------------------------------------------------------------------------------


section .text



gproc int.set_handler
;--------------------------------------------------[ Interrupt: Set Handler ]--
;!<proc>
;! Set the pointer to an interrupt handler routine
;! (note: overwrites whatever handler is currently set)
;! <p reg="eax" type="uinteger8" brief="interrupt number"/>
;! <p reg="ebx" type="pointer" brief="interrupt handler code"/>
;! <ret fatal="0" brief="success"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
					; check IDT limit
					;--------------------------------------
  cmp eax, byte 0x30			; check for IDT limit
  jae short .invalid_interrupt_number	;
					;
  mov edx, 0				; [SMC] load IDT offset
idt_offset EQU $-4			; set in-SMC variable
  lea edx, [eax*8 + edx]		; compute offset to IDT entry
  					;
  mov eax, ebx				; copy pointer to interrupt handler
  mov ecx, cs				; get code segment value
  and ebx, 0x0000FFFF			; keep bits 15-0 of handler address
  shl ecx, 16				; shift code selector to bits 23-16
  and eax, 0xFFFF0000			; keep bits 31-16 of handler address
  or  ebx, ecx				; merge in shifted code selector
  or  eax, 0x00008E00			; select present 32bit GATE, DPL=0
ENTER_CRITICAL_SECTION			;
  mov [edx], ebx			; write bits 31-0 of descriptor
  mov [edx + 4], eax			; write bits 63-32 of descriptor
LEAVE_CRITICAL_SECTION			;
					;
  return				; return to caller without error
					;
.invalid_interrupt_number:		;
  xor ebx, ebx				; TODO: set error message/code
  xor eax, eax				;
  ret_other				;
;------------------------------------------------------------------------------



gproc int.unset_handler
;-----------------------------------------------[ Interrupts: Unset Handler ]--
;!<proc>
;! Unset the handler of a specified interrupts.  Next interruptions will
;! trigger an unhandled interrupt panic.
;! <p reg="eax" type="uinteger8" brief="interrupt number"/>
;! <ret fatal="0" brief="success"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
  mov ebx, _unhandled_interrupt			; set int handler to use
  ecall int.set_handler, CONT, .unexpected	; update its entry
  return					;
						;
.unexpected:					;
  ret_other					;
;------------------------------------------------------------------------------




gproc irq.connect
;------------------------------------------------------------[ IRQ: connect ]--
;!<proc>
;! Connects an IRQ client to an IRQ channel.  The client will be called for
;! every IRQ received for which it is connected.
;! <p reg="eax" type="uinteger8" brief="irq number"/>
;! <p reg="ebx" type="pointer" brief="irq client procedure"/>
;! <ret fatal="0" brief="success"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
						; validate IRQ number
						;------------------------------
  cmp eax, byte 0x10				;
  jae short .invalid_irq_number			;
						; validate IRQ client
%ifdef SANITY_CHECKS				;------------------------------
 cmp [ebx + _irq_client_t.magic], dword __IRQ_CLIENT_MAGIC__
 jnz short .sanity_check_failed_magic		;
%endif						;
						; link irq client to irq ring
						;------------------------------
ENTER_CRITICAL_SECTION				;
  push eax					; save irq number
  lea edx, [eax*8 + irq_clients]		;
  mov eax, ebx					;
  mov ebx, edx					;
  ecall ring_queue.prepend, CONT, .unexpected	;
						;
						; set PIC port and irq mask
						;------------------------------
  pop ecx					; restore irq number
  mov edx, ecx					;
  and cl, 0x07					; 8 irq per PIC
  and dl, 0x08					; keep only bit 3 of irq number
  mov bl, 0xFE					; set bitmask
  shl dl, 0x04					; set bit 7 to irq # bit 3
  rol bl, cl					; set PIC interrupt mask
  or  dl, 0x21					; get PIC port
						;
						; enable IRQ
						;------------------------------
  in al, dx					; read current mask
  and al, bl					; enable the irq
  out dx, al					; write back new mask
						;
LEAVE_CRITICAL_SECTION				;
  return					;
						; Unexpected error
.unexpected:					;------------------------------
  pop ecx					; clear irq number from stack
.invalid_irq_number:				;
.sanity_check_failed_magic:			;
  xor ebx, ebx					; TODO: set error code/message
  xor eax, eax					;
  ret_other					;
;------------------------------------------------------------------------------




gproc irq.disconnect
;---------------------------------------------------------[ IRQ: disconnect ]--
;!<proc>
;! Disconnects a client from an IRQ channel.
;! ** DO NOT CALL FROM THE IRQ HANDLER **
;! <p reg="eax" type="uinteger8" brief="irq number"/>
;! <p reg="ebx" type="pointer" brief="irq client procedure"/>
;! <ret fatal="0" brief="success"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
						; validate IRQ number
						;------------------------------
  cmp eax, byte 0x10				;
  jae short .invalid_irq_number			;
						;
						; valid IRQ client pointer
%ifdef SANITY_CHECKS				;------------------------------
 cmp [ebx + _irq_client_t.magic], dword __IRQ_CLIENT_MAGIC__
 jnz short .sanity_check_failed_magic		;
%endif						;
						; unlink client from ring
						;------------------------------
  push eax					; save irq number
  mov eax, ebx					;
  ecall ring_queue.unlink, CONT, .unexpected	;
						; check irq ring for clients
						;------------------------------
  pop ecx					; restore irq number
  lea eax, [ecx*8 + irq_clients]		;
  cmp [eax], dword eax				; empty ring queue?
  jnz short .keep_irq_enabled			; no? some clients left
						;
						; set PIC port and irq mask
						;------------------------------
  mov edx, ecx					;
  and cl, 0x07					;
  and dl, 0x08					;
  mov bl, 0x01					;
  shl dl, 0x04					;
  rol bl, cl					;
  or  dl, 0x21					;
						; disable IRQ
						;------------------------------
  in al, dx					; read current mask
  or al, bl					; disable the irq
  out dx, al					; write back new mask
						;
.keep_irq_enabled:				;
  return					;
						;
.unexpected:					;
  pop ecx					;
.invalid_irq_number:				;
.sanity_check_failed_magic:			;
  xor ebx, ebx					;
  xor eax, eax					;
  ret_other					;
;---------------------------------------------------------[/IRQ: disconnect ]--




;------------------------------------------------------------[ IRQ CHANNELS ]--
  align 8, db 0					; align interruption handlers
						;
_irq_0:						;--------: IRQ 0 Handler
 push byte 0x00					;
 jmp short _irq_common				;
_irq_1:						;--------: IRQ 1 Handler
 push byte 0x01					;
 jmp short _irq_common				;
_irq_2:						;--------: IRQ 2 Handler
 push byte 0x02					;
 jmp short _irq_common				;
_irq_3:						;--------: IRQ 3 Handler
 push byte 0x03					;
 jmp short _irq_common				;
_irq_4:						;--------: IRQ 4 Handler
 push byte 0x04					;
 jmp short _irq_common				;
_irq_5:						;--------: IRQ 5 Handler
 push byte 0x05					;
 jmp short _irq_common				;
_irq_6:						;--------: IRQ 6 Handler
 push byte 0x06					;
 jmp short _irq_common				;
_irq_7:						;--------: IRQ 7 Handler
 push byte 0x07					;
 jmp short _irq_common				;
_irq_8:						;--------: IRQ 8 Handler
 push byte 0x08					;
 jmp short _irq_common				;
_irq_9:						;--------: IRQ 9 Handler
 push byte 0x09					;
 jmp short _irq_common				;
_irq_A:						;--------: IRQ A Handler
 push byte 0x0A					;
 jmp short _irq_common				;
_irq_B:						;--------: IRQ B Handler
 push byte 0x0B					;
 jmp short _irq_common				;
_irq_C:						;--------: IRQ C Handler
 push byte 0x0C					;
 jmp short _irq_common				;
_irq_D:						;--------: IRQ D Handler
 push byte 0x0D					;
 jmp short _irq_common				;
_irq_E:						;--------: IRQ E Handler
 push byte 0x0E					;
 jmp short _irq_common				;
_irq_F:						;--------: IRQ F Handler
 push byte 0x0F					;
;-------------------------------------------------------[ IRQ Client Router ]--
_irq_common:					; save current cpu state
						;------------------------------
  pushad					;
  mov [.original_top_of_stack], esp		;
						;
						; retrieve fired IRQ number
						;------------------------------
  mov eax, [esp + 32]				;
  test al, 0x08					;
  lea esi, [eax*8 + irq_clients]		;
  jz  short .primary_pic			;
						;
						; acknowledge slave PIC
						;------------------------------
  and al, 0x07					;
  or  al, 0x60					;
  out 0xA0, al					;
  mov al, 2					;
						;
						; acknowledge master PIC
.primary_pic:					;------------------------------
  or  al, 0x60					;
  out 0x20, al					;
						;
  						; call ringed IRQ clients
						;------------------------------
  mov edi, esi					;
.cycle:						;
  mov edi, [edi + _ring_queue_t.next]		;
  cmp edi, esi					;
  jz short .cycled_ring				;
						;
  mov esp, .internal_stack			;
  pushad					;
  call [edi + _irq_client_t.procedure]		;
  popad						;
  jmp short .cycle				;
						;
.cycled_ring:					;
						; restore cpu state
						;------------------------------
  mov esp, [.original_top_of_stack]		;
  popad						;
  add esp, byte 4				;
  iretd						; return from interruption
						;
[section .bss]					;
 .original_top_of_stack: resd 1			;
 .internal_stack: resb 512			;
__SECT__					;
;-------------------------------------------------------[/IRQ Client Router ]--






_unhandled_interrupt:
;-------------------------------------------[ Unhandled Interrupt Handlers ]--
  mov eax, 0xEEEE0006			; set error code, YAY Bochs!
  mov [0xB809C], dword 0x04210421	; display some indication on screen
  BOCHS_prompt
  jmp short $				; for now just lock
;-----------------------------------------------------------------------------





section .data

irq_clients:
.irq0: def_ring_queue
.irq1: def_ring_queue
.irq2: def_ring_queue
.irq3: def_ring_queue
.irq4: def_ring_queue
.irq5: def_ring_queue
.irq6: def_ring_queue
.irq7: def_ring_queue
.irq8: def_ring_queue
.irq9: def_ring_queue
.irqA: def_ring_queue
.irqB: def_ring_queue
.irqC: def_ring_queue
.irqD: def_ring_queue
.irqE: def_ring_queue
.irqF: def_ring_queue


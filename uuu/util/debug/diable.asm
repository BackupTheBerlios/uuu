;
; Diable
;
; Debugging cell, which present absolutely no dependencies.  Allow to easily
; dump information, either hexadecimal or string, directly to memory locations
; in vga text format.
;
; All of the functions in this cell do not destroy any register.  Two flavors
; of each function is provided, one is 'debug', which does its task and exits,
; while the other is 'debug_ack', which will do its task and waits for the
; <enter> key to be pressed and released.


global diable.dword_out
global diable.dword_out_wait
global diable.wait
global diable.print_string_wait
global diable.print_string
global diable.print_regs_wait
global diable.print_regs
global diable.print_stack
global diable.print_stack_wait



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						diable.dword_out:	;
;>
;; This function will display the content of the 'EDX' register on screen at
;; the indicated offset in 'EDI'. The content will be displayed using 8
;; hexadecimal characters and will be sent for color display
;;
;; parameters:
;;------------
;; edx = value to display
;; edi = Offset to videocard color text mode buffer
;;
;; returned values:
;;-----------------
;; eax = (unmodified)
;; ebx = (unmodified)
;; ecx = (unmodified)
;; edx = (unmodified)
;; esi = (unmodified)
;; edi = (unmodified)
;; esp = (unmodified)
;; ebp = (unmodified)
;; eflags = (unmodified)
;<
  push ecx					; Save Regs
  push edi					;
  push eax					;
  pushfd					;
  mov ecx, 8					;
  cld						;
  mov ah, 0x07					;
.displaying:					; Display EDX
  rol edx, 4					;
  mov al, dl					;
  and al, 0x0F					;
  add al, 0x90					;
  daa						;
  adc al, 0x40					;
  daa						;
  stosw						;
  dec ecx					;
  jnz .displaying				;
  popfd						;
  pop eax					;
  pop edi					;
  pop ecx					;
  retn						;



;-----------------------------------------------------------------------.
						diable.dword_out_wait:	;
;>
;; Same as __dword_out, but wait for the keyboard "Enter" key to be pressed and
;; released before resuming.
;;
;; parameters:
;;------------
;; edx = value to display
;; edi = Offset to videocard color text mode buffer
;;
;; returned values:
;;-----------------
;; eax = (unmodified)
;; ebx = (unmodified)
;; ecx = (unmodified)
;; edx = (unmodified)
;; esi = (unmodified)
;; edi = (unmodified)
;; esp = (unmodified)
;; ebp = (unmodified)
;; eflags = (unmodified)
;<
  call diable.dword_out				;
  call diable.wait				;
  retn						;



;-----------------------------------------------------------------------.
						diable.wait:		;
;>
;; Waits until the user press and release enter, then return control
;;
;; parameters:
;;------------
;; none
;;
;; returned values:
;;-----------------
;; eax = (unmodified)
;; ebx = (unmodified)
;; ecx = (unmodified)
;; edx = (unmodified)
;; esi = (unmodified)
;; edi = (unmodified)
;; esp = (unmodified)
;; ebp = (unmodified)
;; eflags = (unmodified)
;<
  pushfd			; save eflags
  push eax			; save eax
                                ;
  ; mask keyboard irq		;
  in al, 0x21			; get master pic irq mask
  push eax			; save original irq mask
  or al, 0x02			; mask of irq 1 - keyboard
  out 0x21, al			; send it to pic
				;
.wait_data_in:			;
  in al, 0x64			; get keyboard status byte
  test al, 0x01			; check for waiting keyboard data
  jz .wait_data_in		; no data, go wait
  in al, 0x60			; get data byte
  cmp al, 0x1C			; is the make code enter?
  jnz .wait_data_in		; nope, go wait again
.wait_data_in_release:		; enter make code received, wait for break code
  in al, 0x64			; get keyboard status byte
  test al, 0x01			; check for waiting keyboard data
  jz .wait_data_in_release	; no data, go wait
  in al, 0x60			; get data byte
  cmp al, 0x9C			; is the break code enter?
  jnz .wait_data_in_release	; nope, go wait again
				;
  pop eax			; restore original irq mask
  test al, 0x02			; was irq 1 set or cleared?
  jnz .bypass_irq_activate	; irq 1 was set (masked), don't touch
  in al, 0x21			; get current irq mask
  and al, 0xFD			; clear irq 1 mask
  out 0x21, al			; send to pic
.bypass_irq_activate:		;
  pop eax			; restore original eax
  popfd				; restore eflags
  retn				; give control back



;-----------------------------------------------------------------------.
						diable.print_string_wait:
;>
;; Displays a null terminated string at esi in the video buffer starting at edi
;; no registers modified, waits for enter to be pressed
;<
  call diable.print_string			;
  call diable.wait				;
  retn						;



;-----------------------------------------------------------------------.
						diable.print_string:	;
;>
;; Displays a null terminated string at esi in the video buffer starting at edi
;; no registers modified
;<
	pushfd					;
	push edi				;
	push esi				;
	push eax				;
.loop:						; Display each char
	cmp byte [esi], 0			;
	je .done				;
	mov ah, 0x07				;
	mov al, byte [esi]			;
	mov [edi], word ax			;
	inc esi					;
	inc edi					;
	inc edi					;
	jmp .loop				;
.done:						;
	pop eax					;
	pop esi					;
	pop edi					;
	popfd					;
	retn					;



;-----------------------------------------------------------------------.
						diable.print_regs_wait:	;
;>
;; Displays eax,ebx,ecx,edx, esi, edi to the screen and waits for [enter]
;;
;; out :
;; NO registers modified
;<
  call diable.print_regs			;
  call diable.wait				;
  retn						;

[section .data]
_sr_eax db 'eax:', 0
_sr_ebx db 'ebx:', 0
_sr_ecx db 'ecx:', 0
_sr_edx db 'edx:', 0
_sr_esi db 'esi:', 0
_sr_edi db 'edi:', 0
_sr_ebp db 'ebp:', 0
_sr_esp db 'esp:', 0
_sr_stack_border db '--------', 0
__SECT__



;-----------------------------------------------------------------------.
						diable.print_regs:	;
;>
;; Displays eax,ebx,ecx,edx, esi, edi to the screen
;;
;; out :
;; NO registers modified
;<
	pushfd					;
	push esi				;
	push edi 				;
	push edx				;
						;
	mov edi, dword 0xb8000			;
						;
	mov esi, _sr_eax			; Print EAX
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword eax			;
	call diable.dword_out			;
						;
	add edi, 152				; EBX
	mov esi, _sr_ebx			;
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword ebx			;
	call diable.dword_out			;
						;
	add edi, 152				; ECX
	mov esi, _sr_ecx			;
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword ecx			;
	call diable.dword_out			;
						;
	add edi, 152				; EDX
	mov esi, _sr_edx			;
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword [ss:esp]			;
	call diable.dword_out			;
						;
	add edi, 152				; ESI
	mov esi, _sr_esi			;
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword [ss:esp + 8]		;
	call diable.dword_out			;
						;
	add edi, 152				; EDI
	mov esi, _sr_edi			;
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword [ss:esp + 4]		;
	call diable.dword_out			;
						;
	add edi, 152				; EBP
	mov esi, _sr_ebp			;
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword ebp			;
	call diable.dword_out			;
						;
	add edi, 152				; ESP
	mov esi, _sr_esp			;
	call diable.print_string		;
	add edi, 8				;
	mov edx, dword esp			;
	call diable.dword_out			;
						;
	pop edx					;
	pop edi 				;
	pop esi					;
	popfd					;
						;
	retn					;



;-----------------------------------------------------------------------.
						diable.print_stack:	;
;>
;; Displays last 8 dwords pushed on stack.
;; no regs destroyed
;<
	pushfd					;
	push esi				;
	push edi 				;
	push edx				;
 						;
	mov edi, 0xb8000			;
						;
	mov esi, _sr_stack_border		; esp+4*4
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*4]		;
	call diable.dword_out			;
						;
	add edi, 160				; esp+4*5
	mov esi, _sr_stack_border		;
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*5]		;
	call diable.dword_out			;
						;
	add edi, 160				; esp+4*6
	mov esi, _sr_stack_border		;
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*6]		;
	call diable.dword_out			;
						;
	add edi, 160				; esp+4*7
	mov esi, _sr_stack_border		;
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*7]		;
	call diable.dword_out			;
						;
	add edi, 160				; esp+4*8
	mov esi, _sr_stack_border		;
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*8]		;
	call diable.dword_out			;
						;
	add edi, 160				; esp+4*9
	mov esi, _sr_stack_border		;
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*9]		;
	call diable.dword_out			;
						;
	add edi, 160				; esp+4*10
	mov esi, _sr_stack_border		;
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*10]		;
	call diable.dword_out			;
						;
	add edi, 160				; esp+4*11
	mov esi, _sr_stack_border		;
	call diable.print_string		;
	add edi, 160				;
	mov edx, dword [ss:esp+ 4*11]		;
	call diable.dword_out			;
						;
	add edi, 160				;
	mov esi, _sr_stack_border		;
	call diable.print_string		;
						;
	pop edx					;
	pop edi 				;
	pop esi					;
	popfd					;
	retn					;



;-----------------------------------------------------------------------.
						diable.print_stack_wait:;
;>
;; Displays last 8 dwords pushed on stack and waits for enter
;; no regs destroyed
;<
	call diable.print_stack			;
	call diable.wait			;
 	retn					;

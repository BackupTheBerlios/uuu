;; Hydro3d
;; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/Attic/test.asm,v 1.2 2003/11/12 15:51:16 bitglue Exp $
;; copyright (c) 2001 Phil Frost


;%define _RDTSC_

;---------------===============\         /===============---------------
;				constants
;---------------===============/         \===============---------------

%define SC_INDEX	0x3c4
%define MEMORY_MODE	4
%define GRAPHICS_MODE	5
%define MISCELLANEOUS	6
%define MAP_MASK	2
%define CRTC_INDEX	0x3d4
%define MAX_SCAN_LINE	9
%define UNDERLINE	0x14
%define MODE_CONTROL	0x17

%define XRES		360
%define YRES		480
%define F_HALF_XRES	180.0	; half of the res. as a float
%define F_HALF_YRES	240.0

%define VIDEO_RAM	0xa0000
%assign MISC_OUTPUT         0x03c2    ; VGA misc. output register
%assign SC_INDEX            0x03c4    ; VGA sequence controller
%assign SC_DATA             0x03c5
%assign PALETTE_INDEX       0x03c8    ; VGA digital-to-analog converter
%assign PALETTE_DATA        0x03c9
%assign CRTC_INDEX          0x03d4    ; VGA CRT controller

%assign MAP_MASK            0x02      ; Sequence controller registers
%assign MEMORY_MODE         0x04

%assign H_TOTAL			0x00      ; CRT controller registers
%assign H_DISPLAY_END		0x01
%assign H_BLANK_START		0x02
%assign H_BLANK_END		0x03
%assign H_RETRACE_START		0x04
%assign H_RETRACE_END		0x05
%assign V_TOTAL			0x06
%assign OVERFLOW		0x07
%assign MAX_SCAN_LINE		0x09
%assign HIGH_ADDRESS		0x0C
%assign LOW_ADDRESS		0x0D
%assign V_RETRACE_START		0x10
%assign V_RETRACE_END		0x11
%assign V_DISPLAY_END		0x12
%assign OFFSET			0x13
%assign UNDERLINE_LOCATION	0x14
%assign V_BLANK_START		0x15
%assign V_BLANK_END		0x16
%assign MODE_CONTROL		0x17


;; A note on the matricies:
;;
;; | xx yx zx | tx |
;; | xy yy zy | ty |
;; | xz yz zz | tz |
;; -----------------
;; | xw yw zw | tw |
;;
;; x? y? and z? are the x, y, and z unit vectors respectivly.
;; t? is the translation. tw is almost always 1,
;; xw, xy and xz are almost always 0.
;;
;; Keep in mind that the matrix is not stored left-right top-bottom in memory
;; but is stored top-bottom left-right much like as in opengl. This is done
;; because it allows easy isolation of the unit vectors and is easier to load
;; into SIMD registers.
;;
;; Everything uses a full 4x4 matrix even though some values might be assumed.
;; This makes things more flexible and the extra memory usage is negligible.

struc matrix44			; 4 by 4 matrix, full homogenous
  .xx:	resd 1	; 0
  .xy:	resd 1	; 4
  .xz:	resd 1	; 8
  .xw:	resd 1	; 12

  .yx:	resd 1	; 16
  .yy:	resd 1	; 20
  .yz:	resd 1	; 24
  .yw:	resd 1	; 28

  .zx:	resd 1	; 32
  .zy:	resd 1	; 36
  .zz:	resd 1	; 40
  .zw:	resd 1	; 44

  .tx:	resd 1	; 48
  .ty:	resd 1	; 52
  .tz:	resd 1	; 56
  .tw:	resd 1	; 60
endstruc

struc vect3			; 3 dimentional vector
  .x:	resd 1
  .y:	resd 1
  .z:	resd 1
endstruc

struc vect4			; 4 dimentional vector (homogenous)
  .x:	resd 1
  .y:	resd 1
  .z:	resd 1
  .w:	resd 1
endstruc

struc scene
  .objects:	resd 1		;pointer to object list (an ICS channel)
  .camera:	resd 1		;pointer to current camera
  .lights:	resd 1		;pointer to lights
  .res_x:	resw 1          ;X resloution
  .res_y:	resw 1          ;Y resloution
  .buffer:	resd 1		;pointer to output buffer
endstruc

struc camera
  .cmatrix:	resb matrix44_size	;camera matrix; does the orientation
  .pmatrix:	resb matrix44_size	;projection matrix; does the projection
  .tmatrix:	resb matrix44_size	;total matrix, proj*camera
endstruc

struc object
  .omatrix:	resb matrix44_size	;object matrix
  .ematrix:	resb matrix44_size	;eyespace matrix
  .mesh:	resd 1			;pointer to mesh
  .points:	resd 1			;pointer to 2-D points
  .material:	resd 1			;pointer to material (unused)
  .parrent:	resd 1			;pointer to parrent object (unused)
  .children:	resd 1		;pointer to children (an ICS channel) (unused)
endstruc

struc mesh
  .vert_count:	resd 1			;number of verticies
  .face_count:	resd 1			;number of faces (all triangles)
  .verts:	resd 1			;pointer to verts
  .faces:	resd 1			;pointer to faces
endstruc

;struc point		;2-D point
;  .x:		resw 1            ;The 2d cordinates (from __calc_points)
;  .z:		resw 1
;  .yprime:	resd 1          ;the transformed 3d Y cordinate
;endstruc

struc face
  .vert1:	resw 1          ;
  .vert2:	resw 1          ;Must be asigned clockwise
  .vert3:	resw 1          ;
  .norX:	resd 1    ;
  .norY:	resd 1    ;The normal vector (from __calc_normals, in object space)
  .norZ:	resd 1    ;
endstruc					



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

global _start
_start:

  call set_320x200x8bpp

;-----------------------------------------------------------------------.
						set_video_mode:		;
;
; sets whatever video mode is defined in the XRES/HEIGHT macros
;
; width can be 320 or 360
; height can be 200, 400, 240, or 480.

%macro word_out 2
  mov ax, (%2 << 8) + %1
  out dx, ax
%endmacro

  mov dx, SC_INDEX

  ; turn off chain-4 mode
  word_out MEMORY_MODE, 0x06

  ; set map mask to all 4 planes for screen clearing
  word_out MAP_MASK, 0xff

  ; clear all 256K of memory
  xor eax, eax
  mov edi, VIDEO_RAM
  mov ecx, 0x4000
  rep stosd

  mov dx, CRTC_INDEX

  ; turn off long mode
  word_out UNDERLINE_LOCATION, 0x00

  ; turn on byte mode
  word_out MODE_CONTROL, 0xe3


%if XRES = 360
    ; turn off write protect
    word_out V_RETRACE_END, 0x2c

    mov dx, MISC_OUTPUT
    mov al, 0xe7
    out dx, al
    mov dx, CRTC_INDEX

    word_out H_TOTAL, 0x6b
    word_out H_DISPLAY_END, 0x59
    word_out H_BLANK_START, 0x5a
    word_out H_BLANK_END, 0x8e
    word_out H_RETRACE_START, 0x5e
    word_out H_RETRACE_END, 0x8a
    word_out OFFSET, 0x2d

    ; set vertical retrace back to normal
    word_out V_RETRACE_END, 0x8e
%else
    mov dx, MISC_OUTPUT
    mov al, 0xe3
    out dx, al
    mov dx, CRTC_INDEX
%endif

%if YRES=240 || YRES=480
    ; turn off write protect
    word_out V_RETRACE_END, 0x2c

    word_out V_TOTAL, 0x0d
    word_out OVERFLOW, 0x3e
    word_out V_RETRACE_START, 0xea
    word_out V_RETRACE_END, 0xac
    word_out V_DISPLAY_END, 0xdf
    word_out V_BLANK_START, 0xe7
    word_out V_BLANK_END, 0x06
%endif

%if YRES=400 || YRES=480
    word_out MAX_SCAN_LINE, 0x40
%endif


create_mesh:
;-------------------------------------------------------------------------------
  mov ecx, vertcount
  mov edx, facecount
  mov eax, test_verts
  mov ebx, test_faces
  call _create_mesh
  ; edi = pointer to mesh



create_objects:
;-------------------------------------------------------------------------------
  mov esi, edi					;
  ;push edi
  call _create_object	;
  mov [data.object1], edi			;

  ;fld dword[edi+object.omatrix+matrix44.tx]
  ;fsub dword[data.object_back]
  ;fstp dword[edi+object.omatrix+matrix44.tx]
  
;  mov esi, [esp]
;  call _create_object	;
;  mov [data.object2], edi			;
;
;;  call _scale_matrix
;
;  pop esi
;  call _create_object	;
;  mov [data.object3], edi			;
;
;  call _scale_matrix
;
;  fld dword[edi+object.omatrix+matrix44.tx]
;  fadd dword[data.object_dis]
;  fstp dword[edi+object.omatrix+matrix44.tx]
  



create_camera:
;-------------------------------------------------------------------------------
  call _create_camera	;
  ; edi = pointer to camera			;

  mov dword[edi+camera.cmatrix+matrix44.tz], 0xC1200000	; -10.0
  
  push dword [data.far_clip]		; far clip plane
  push dword [data.near_clip]		; near clip plane
  push dword [data.fov]			; FOV
  push dword [data.aspect_ratio]	; aspect ratio
  add edi, byte camera.pmatrix
  call _create_camera_matrix
  sub edi, byte camera.pmatrix
  



create_scene:
;-------------------------------------------------------------------------------
  mov esi, edi					;
  call _create_scene	;
  ; edi = pointer to scene			;
  mov [data.scene], edi			;



add_objects_to_scene:
;-------------------------------------------------------------------------------
  ; edi = pointer to scene			;
  ;push edi
  mov esi, [data.object1]			;
  call _add_object_to_scene

  ;mov edi, [esp]
  ;mov esi, [data.object2]			;
  ;call _add_object_to_scene

  ;pop edi
  ;mov esi, [data.object3]			;
  ;call _add_object_to_scene




set_palette:	; makes a bluescale palette from 1 to 255
;-------------------------------------------------------------------------------
  mov ecx, 255	;
  xor ebx, ebx	;
  inc ebx	;
.loop:  	;
  mov dx, 0x3c8	;
  mov eax, ebx	;
  out dx, al	;
 		;
  inc edx	; 0x3c9 now
  mov eax, ecx	;
  shr eax, 3	;
  out dx, al	;red
  out dx, al	;green
  		;
  mov eax, ecx	;
  shr eax, 2	;
  out dx, al	;blue
		;
  inc ebx	;
  dec ecx	;
  jnl .loop	;


set_sane_floating_precision:
;-------------------------------------------------------------------------------
  fstcw [esp-2]
  and word[esp-2], 0xfcff	; clear bits 8 and 9 for single precision
  fldcw [esp-2]


;; Init stuff is done. We have the whole scene set up and a pointer to it
;; in [data.scene]. This should be all we need to draw it.



;                                                               frame loop here
;==============================================================================

frame:


%assign _KEYB_STATUS_PORT_	0x64
%assign _KEYB_DATA_PORT_	0x60
%assign _KEYB_OUTPUT_BUFFER_	0x01

  in al, _KEYB_STATUS_PORT_
  test al, _KEYB_OUTPUT_BUFFER_
  jz .no_key

  in al, _KEYB_DATA_PORT_
  call _keyboard_client
.no_key:


%ifdef _RDTSC_
jmp $
  xor eax, eax
  cpuid			; serialize
  rdtsc
  push eax
%endif

draw_scene_to_buffer:
;-------------------------------------------------------------------------------
  mov edi, [data.scene]
  call _draw_scene

%ifdef _RDTSC_
  xor eax, eax
  cpuid			; serialize
  rdtsc
  pop edx
  sub eax, edx
  push eax
%endif



wait_for_retrace:
;-------------------------------------------------------------------------------
  mov dx, 0x3da	;
.wait:		;
  in al, dx	;
  and al, 0x8	;
  jnz .wait	;
.waitmore:	;
  in al, dx	;
  and al, 0x8	;
  jz .waitmore	;



%ifdef _RDTSC_
display_tsc:
;-------------------------------------------------------------------------------
  mov edi, [data.scene]	;
  mov edi, [edi+scene.buffer]	;
  pop edx			;
  call _display_hex		;
%endif


draw_buffer:
;-------------------------------------------------------------------------------
  mov esi, [data.scene]	;
  mov edi, 0xa0000		;
  mov esi, [esi+scene.buffer]	;
  mov dx, SC_INDEX
  xor ecx, ecx
  mov al, 0x02

  mov ebx, YRES
.copy_scanline:
  
  mov ah, 0x01
  add ecx, byte XRES/4/4
  out dx, ax		; select write to plane 0
  rep movsd
%if XRES = 360
  movsw
%endif

  mov ah, 0x02
  sub edi, byte XRES/4
  add ecx, byte XRES/4/4
  out dx, ax		; select write to plane 1
  rep movsd
%if XRES = 360
  movsw
%endif

  mov ah, 0x04
  sub edi, byte XRES/4
  add ecx, byte XRES/4/4
  out dx, ax		; select write to plane 2
  rep movsd
%if XRES = 360
  movsw
%endif

  mov ah, 0x08
  sub edi, byte XRES/4
  add ecx, byte XRES/4/4
  out dx, ax		; select write to plane 3
  rep movsd
%if XRES = 360
  movsw
%endif

  dec ebx
  jnz .copy_scanline


  cmp byte[data.fade_count], 0
  jne near exit


rotate_n_translate:
  mov bx, [data.keys]			;
.slowdown:				;
  fld dword[data.Xrot_amount]	;
  fld dword[data.Yrot_amount]	;
  fld dword[data.Zrot_amount]	;
  fld dword[data.rot_decel]		;
  fmul st3, st0				;
  fmul st2, st0				;
  fmulp st1, st0			;
  fstp dword[data.Zrot_amount]	;
  fstp dword[data.Yrot_amount]	;
  fstp dword[data.Xrot_amount]	;
  					;
.up:					;
  test bx, 1b				;up arrow pressed?
  jz .down				;
  fld dword[data.Xrot_amount]	;
  fld dword[data.rot_accel]		;
  fchs					;
  faddp st1, st0			;
  fstp dword[data.Xrot_amount]	;
					;
.down:					;
  test bx, 10b				;
  jz .left				;
  fld dword[data.Xrot_amount]	;
  fld dword[data.rot_accel]		;
  faddp st1, st0			;
  fstp dword[data.Xrot_amount]	;
					;
.left:					;
  test bx, 100b				;
  jz .right				;
  fld dword[data.Yrot_amount]	;
  fld dword[data.rot_accel]		;
  faddp st1, st0			;
  fstp dword[data.Yrot_amount]	;
					;
.right:					;
  test bx, 1000b			;
  ;zooming disabled temp.		;
  ;jz .plus				;
  jz .done				;
  fld dword[data.Yrot_amount]	;
  fld dword[data.rot_accel]		;
  fchs					;
  faddp st1, st0			;
  fstp dword[data.Yrot_amount]	;
					;
;.plus:					;
;  mov ecx, [data.state_ptr]	;
;  test bx, 10000b			;
;  jz .minus				;
;  fld dword[ecx+client_state.cam_dis]	;
;  fld dword[data.zoom_speed]	;
;  faddp st1,st0			;
;  fstp dword[ecx+client_state.cam_dis]	;
;					;
;.minus:				;
;  test bx, 100000b			;
;  jz .done				;
;  fld dword[ecx+client_state.cam_dis]	;
;  fld dword[data.zoom_speed]	;
;  fsubp st1,st0			;
;  fstp dword[ecx+client_state.cam_dis]	;
.done:					;


rotate:
  mov eax, [data.object1]			;
  call _rotate_object
						;
  mov eax, [data.object2]			;
  call _rotate_object
						;
  mov eax, [data.object3]			;
  call _rotate_object



  jmp frame	; go do another frame



;                                           -----------------------------------
;                                                                          exit
;==============================================================================

exit:
  ; where are you going? This is an OS! :)
  mov al, 0xFE
  out 0x64, al
  mov al, 0x01
  out 0x92, al
  ; should have rebooted, but lock to be sure
  cli
  jmp short $



;                                           -----------------------------------
;                                                              _keyboard_client
;==============================================================================

_keyboard_client:
				;
  push ebx
  mov bx, [data.keys]
				;
  cmp al, 0x48			;up arrow
  je .up_pressed		;
  cmp al, 0xc8			;up arrow released
  je .up_released		;
  cmp al, 0x50			;
  je .down_pressed		;
  cmp al, 0xd0			;
  je .down_released		;
  cmp al, 0x4b			;
  je .left_pressed		;
  cmp al, 0xcb			;
  je .left_released		;
  cmp al, 0x4d			;
  je .right_pressed		;
  cmp al, 0xcd			;
  je .right_released		;
  cmp al, 0x0d			;
  je .plus_pressed		;
  cmp al, 0x8d			;
  je .plus_released		;
  cmp al, 0x0c			;
  je .minus_pressed		;
  cmp al, 0x8c			;
  je .minus_released		;
  cmp al, 0x10			;
  je .q_pressed			;
  cmp al, 0x1c			;
  je .enter_pressed		;
  cmp al, 0x9c			;
  je .enter_released		;
  
  pop ebx
  stc
  retn

.up_pressed:			;
  or bx, 1b			;
  jmp short .done
				;
.up_released:			;
  and bx, 0xfffe		;
  jmp short .done
				;
.down_pressed:			;
  or bx, 10b			;
  jmp short .done
				;
.down_released:			;
  and bx, 0xfffd		;
  jmp short .done
				;
.left_pressed:			;
  or bx, 100b			;
  jmp short .done
				;
.left_released:			;
  and bx, 0xfffb		;
  jmp short .done
				;
.right_pressed:			;
  or bx, 1000b			;
  jmp short .done
				;
.right_released:		;
  and bx, 0xfff7		;
  jmp short .done
				;
.plus_pressed:			;
  or bx, 10000b			;
  jmp short .done
				;
.plus_released:			;
  and bx, 0xffef		;
  jmp short .done
				;
.minus_pressed:			;
  or bx, 100000b		;
  jmp short .done
				;
.minus_released:		;
  and bx, 0xffdf		;
  jmp short .done
				;________
.q_pressed:				;
  ;save this for later, when we add fading again.
  mov byte[data.fade_count], 255	;
  jmp short .done
					;________
.enter_pressed:					;
  mov dword[data.rot_decel], 0x3f733333	;0.95
  jmp short .done
						;
.enter_released:				;
  mov dword[data.rot_decel], 0x3f7fbe77	;0.999
  jmp short .done
						;
.done:						;
  mov [data.keys], bx
  pop ebx
  clc
  retn


;                                           -----------------------------------
;                                                                 _scale_matrix
;==============================================================================

_scale_matrix:
; scales the matrix pointed to by edx by [data.object_scale]

; ** temp. disabled **
;  mov ecx, matrix33_size / 4 - 1
;
;.loop:
;  fld dword[edi+ecx*4]
;  fmul dword[data.object_scale]
;  fstp dword[edi+ecx*4]
;
;  dec ecx
;  jns .loop
  
  retn

;                                           -----------------------------------
;                                                                _rotate_object               
;==============================================================================

_rotate_object:
;; rotates the object pointed to by eax by the Xrot_ammount and Yrot...
  mov edx, eax
  mov ebx, eax
  add edx, byte object.omatrix+matrix44.yx
  add ebx, byte object.omatrix+matrix44.zx
  fld dword[data.Yrot_amount]
  call _rotate_matrix

  mov edx, eax
  mov ebx, eax
  add edx, byte object.omatrix+matrix44.zx
  fld dword[data.Xrot_amount]
  call _rotate_matrix
  retn



%ifdef _RDTSC_
;-----------------------------------------------------------------------.
						_display_hex:		;
;; parameters:
;; -----------
;; EDI = Pointer to buffer location where to start printing, a total of 64x8
;;       pixels will be required.
;; EDX = value to print out in hex
;;
;; returned values:
;; ----------------
;; EAX = (undefined)
;; EBX = (undefined)
;; ECX = 0
;; EDX = (unmodified)
;; ESI = (undefined)
;; EDI = EDI + 64
;; ESP = (unmodified)
;; EBP = (unmodified)

  lea ebx, [hex_conv]
  mov ecx, 8
.displaying:
  xor eax, eax
  rol edx, 4
  mov al, dl
  and al, 0x0F
  lea esi, [eax*8 + ebx]  
  push eax
  push ebx
  push edx
  call _display_char
  pop edx
  pop ebx
  pop eax
  loop .displaying
  retn

_display_char:
  push ecx
  push edi
  mov ch, 8
  mov ebx, XRES-8
.displaying_next8:
  mov dh, [esi]
  mov cl, 8
.displaying:
  xor eax, eax
  rcl dh, 1
  jnc .got_zero
  mov al, 0x3F
.got_zero:
  mov [edi], al
  inc edi
  dec cl
  jnz .displaying
  inc esi
  lea edi, [edi + ebx]
  dec ch
  jnz .displaying_next8
  pop edi
  lea edi, [edi + 8]
  pop ecx
  retn

hex_conv:
%include "numbers.inc"

%endif		; _RDTSC_

;                                           -----------------------------------
;                                                                          data
;==============================================================================

section .data

; misc. data ---===---

data:
  .scene:	dd 0		; pointer to scene
  .object1:	dd 0
  .object2:	dd 0
  .object3:	dd 0
  .object_dis:	dd 3.0		; space between each "U"
  .object_back:	dd 10.0		; how far back the Us are
  .Xrot_amount:	dd 0
  .Yrot_amount:	dd 0
  .Zrot_amount:	dd 0
  .rot_accel:	dd 0.0008
  .rot_decel:	dd 0.999
  .keys:	dw 0		; flags of what keys are currently pressed
  .far_clip:	dd 10.0		; far clip plane
  .near_clip:	dd 1.0		; near clip plane
  .fov:		dd 0.6		; FOV, in radians
  .aspect_ratio:dd 0.47		; aspect ratio - my calculations are somehow
  .fade_count:	db 0		;   screwed, so this was made by trial & error



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------



;-----------------------------------------------------------------------.
						mem.alloc:		;
  mov edi, [memory_frame]
  add [memory_frame], ecx
  retn



;-----------------------------------------------------------------------.
						_create_scene:		;
;>
;; This function creates a new, empty, useless scene. It's not initialized
;; in any way, and if you try to use without adding stuff to it you will
;; probally have problems.
;;
;; parameters:
;; -----------
;; ESI = pointer to camera
;;
;; returns:
;; --------
;; EDI = pointer to scene
;<

  push esi				; the camera
  
  mov ecx, scene_size			;
  xor edx,edx				;
  call mem.alloc		; get the memory
					;
  push edi				; the pointer to the memory
					;
  mov ecx, scene_size/4			;
  xor eax, eax				;
  rep stosd				; zero it out
  					;
  xor edx, edx
  mov ecx, XRES*YRES			; XXX use the real resloution here.
  call mem.alloc
  
  mov eax, edi
  xor ebx, ebx
  pop edi
  pop esi
  mov [edi+scene.objects], ebx		; put the pointer in the scene
  mov [edi+scene.buffer], eax
  mov [edi+scene.camera], esi

  retn					;

;                                           -----------------------------------
;                                                         hydro3d.create_object
;==============================================================================

_create_object:
;>
;;------------------------------------------------------------------------------
;; This creates a new object. However, the new object is not added to anything
;; yet...it must be linked to an object list
;;
;; parameters:
;; -----------
;; ESI = pointer to mesh to use
;;
;; returned values:
;; ----------------
;; EDI = pointer to object
;<

;; because we are using ICS channels to keep track of the objects we need 8
;; bytes before the object. Remember to sub 8 when deallocing this memory :)

  push esi
  
  mov ecx, object_size+8		; ATM we need 8 bytes before the
  xor edx, edx				; object because of the ICS channels.
  call mem.alloc		; In the future I will add ICS
  add edi, byte 8			; functions that don't require this

  push edi
  %if object_size % 4
  %error "object_size was assumed to be a multiple of 4 and it wasn't"
  %endif
  mov ecx, object_size / 4
  xor eax, eax
  rep stosd
  pop edi

  ;initialize the omatrix to identity
  mov eax, 0x3f800000			; 1.0
  mov [edi+object.omatrix+matrix44.xx], eax
  mov [edi+object.omatrix+matrix44.yy], eax
  mov [edi+object.omatrix+matrix44.zz], eax
  mov [edi+object.omatrix+matrix44.tw], eax

  pop esi			; pointer to mesh
  mov [edi+object.mesh], esi

  ; allocating memory for translated vectors
  mov ecx, [esi+mesh.vert_count]; ecx = number of verts
  %if vect4_size <> 16
  %error "vect4_size was assumed to be 8 and it wasn't"
  %endif
  shl ecx, 4			; now we mul by 16; ecx = vertcount*vect4_size
  xor edx, edx
  
  push edi
  call mem.alloc
  mov esi, edi
  pop edi
  mov [edi+object.points], esi

  retn

;                                           -----------------------------------
;                                                           hydro3d.create_mesh
;==============================================================================

_create_mesh:
;>
;; Creates a new mesh.
;; 
;; parameters:
;; -----------
;; EAX = pointer to verts
;; EBX = pointer to faces
;; ECX = number of verts
;; EDX = number of faces
;;
;; returned values:
;; ----------------
;; EDI = pointer to mesh
;<

  push eax	;i know this is bad... when i finalize the data structures
  push ebx	;the program would set these itself.
  push ecx
  push edx
  mov ecx, mesh_size
  xor edx, edx
  call mem.alloc
  pop edx
  pop ecx
  pop ebx
  pop eax

  mov [edi+mesh.vert_count], ecx
  mov [edi+mesh.face_count], edx
  mov [edi+mesh.verts], eax
  mov [edi+mesh.faces], ebx

  ;; ESI = pointer to verts
  ;; EDI = pointer to faces
  ;; ECX = number of faces
  pushad
  mov esi, eax
  mov edi, ebx
  mov ecx, edx
  call _calc_normals
  popad
  
  retn

;                                           -----------------------------------
;                                                   hydro3d.add_object_to_scene
;==============================================================================

_add_object_to_scene:
;>
;; This adds the object pointed to by ESI to the scene pointed to by EDI. It's
;; the program's responsibility to make sure objects are not added twice.
;;
;; parameters:
;; -----------
;; EDI = pointer to scene
;; ESI = pointer to object
;;
;; returned values:
;; ----------------
;; none
;<

  mov [edi+scene.objects], esi

  retn

;                                           -----------------------------------
;                                                         hydro3d.create_camera
;==============================================================================

_create_camera:
;>
;; Creates a new camera; imagine that! The camera matrix is initialized to
;; identity, but the program must initialise the projection to something sane,
;; possibly with create_camera_matrix.
;;
;; parameters:
;; -----------
;; none
;;
;; returned values:
;; ----------------
;; EDI = pointer to camera
;<

  mov ecx, camera_size
  xor edx, edx
  call mem.alloc
 
  ; zero out the memory
  push edi
  shr ecx, 2
  xor eax, eax
  rep stosd
  pop edi

  %if camera.cmatrix <> 0
  %error "camera.cmatrix was assumed to be 0 and it wasn't"
  %endif
  ;initialize cmatrix to identity
  mov eax, 0x3f800000			; 1.0
  mov [edi+camera.cmatrix+matrix44.xx], eax
  mov [edi+camera.cmatrix+matrix44.yy], eax
  mov [edi+camera.cmatrix+matrix44.zz], eax
  mov [edi+camera.cmatrix+matrix44.tw], eax

  retn

;                                           -----------------------------------
;                                                  hydro3d.create_camera_matrix
;==============================================================================

_create_camera_matrix:
;>
;; This is a function usefull for creating a camera projection matrix from usual
;; human parameters like FOV and near/far clipping planes. This function only
;; makes the matrix, one must still create a camera if he is to make much use of
;; it :)
;;
;; The parameters on the stack will be popped off.
;;
;; parameters:
;; -----------
;; +12 = far clipping plane (float)
;;  +8 = near clipping plane (float)
;;  +4 = field of view (radians, float)
;; tos = 1/aspect ratio: height/width (3/4 for std monitor, float)
;; EDI = destination for matrix
;;
;; status:
;; -------
;; working
;<

  xor eax, eax
  mov [edi+matrix44.yx], eax
  mov [edi+matrix44.zx], eax
  mov [edi+matrix44.tx], eax
  mov [edi+matrix44.xy], eax
  mov [edi+matrix44.zy], eax
  mov [edi+matrix44.ty], eax
  mov [edi+matrix44.xz], eax
  mov [edi+matrix44.yz], eax
  mov [edi+matrix44.xw], eax
  mov [edi+matrix44.yw], eax
  mov [edi+matrix44.tw], eax
  
  mov dword[edi+matrix44.zw], 0xBF800000	; -1.0
  
  ;; stack contains:
  ;; +16 = f
  ;; +12 = n
  ;;  +8 = fov
  ;;  +4 = w/h
  ;; tos = return point

  fld dword[.negone]		; -1
  fld dword[esp+8]		; fov	-1
  fscale			; fov/2	-1
  fst dword[esp-4]
  push edx
  mov edx, [esp-4]
  pop edx
  fsincos			; cos(fov/2)	sin(fov/2)	-1
  fdivrp st1			; tan(fov/2)	-1
  fdivrp st1			; -1/tan(fov/2)
  fst dword[edi+matrix44.xx]	;
  fmul dword[esp+4]
  fstp dword[edi+matrix44.yy]	; (empty)
  fld dword[esp+16]		; f
  fld dword[esp+12]		; n	f
  fchs				; -n	f
  fld st1			; f	-n	f
  fadd st1			; f-n	-n	f
  fdivp st2			; -n	f/(f-n)
  fmul st1			; -fn/(f-n)	f/(f-n)
  fstp dword[edi+matrix44.tz]	;
  fstp dword[edi+matrix44.zz]	;

  retn 16

[section .data]
.negone: dd -1.0
__SECT__



;-----------------------------------------------------------------------.
						_draw_scene:		;
;>
;; Draws a scene
;;
;; parameters:
;; -----------
;; EDI = pointer to scene to draw
;;
;; returned values:
;; ----------------
;; none
;;
;; Here we have 2 loops. One loops over each object, the other loops over the
;; faces of each object until we have a seperate function to do that.
;;
;; Throughout the function the camera distance sits on the fpu stack and is
;; popped off at the end. EAX is also used to store the resloution, and it
;; sits on the stack durring the face drawing. The resloution is divided by
;; 2 so it can be added to the points as they are calculated to bring them
;; to the center of the screen.
;<

; get a list of the objects ---===---

  mov ebx, edi			; save this --------------------.
  push dword [edi+scene.objects]	; get pointer to object channel |
  mov ecx, 1
  ; stack now has the objects on it, ECX has the number of them |
  mov edi, ebx			; restore pointer to scene    <-'

; load the camera distance and put the resloution in EAX ---===---

  mov edx, [edi+scene.camera]	; EDX = pointer to camera
  mov eax, 0x00c80140		; XXX: use the real resloution
  ;mov eax, [edi+scene.res_x]
  ;fld dword[edx+camera.dis]	; load this for __calc_points
  shr eax, 1			; this is for __calc_points too

; clear the buffer ---===---

  push ecx
  push edi

  mov edi, [edi+scene.buffer]
  
  fldz			; load 0
  mov ecx, XRES*YRES-0x80
.clearing_buffer:
  fst qword[edi+ecx]
  fst qword[edi+ecx+0x8]
  fst qword[edi+ecx+0x10]
  fst qword[edi+ecx+0x18]
  fst qword[edi+ecx+0x20]
  fst qword[edi+ecx+0x28]
  fst qword[edi+ecx+0x30]
  fst qword[edi+ecx+0x38]
  fst qword[edi+ecx+0x40]
  fst qword[edi+ecx+0x48]
  fst qword[edi+ecx+0x50]
  fst qword[edi+ecx+0x58]
  fst qword[edi+ecx+0x60]
  fst qword[edi+ecx+0x68]
  fst qword[edi+ecx+0x70]
  fst qword[edi+ecx+0x78]
  add ecx, byte -128
  jns .clearing_buffer

  fstp st0

  pop edi
  pop ecx



; check to see if we have any objects. Return if we don't. ---===---

  test ecx, ecx
  jz near .done			; if we have no objects

.object:

;; We have now set up all the stuff that dosn't change between objects.
;; Here starts the object-level loop. First we calculate all the points, then
;; we draw the faces.
;;
;; Calculating the points involves calculating the matrix for the object,
;; taking into account the camera and parrent objects. Right now we just fake
;; it by copying the object's matrix and moving it back 10 units.
  
; get an object off the stack ---===---
  
  pop esi			; pop pointer to object

  push ecx			; save number of objects

;; ESI = pointer to current object
;; ECX = number of objects left to draw (including current one)
;; EAX = resloutions
;; EDI = pointer to scene


; calculate the ematrix ---===---

  pushad
  
  ; step 1: calculate [cmatrix] * [pmatrix] = [tmatrix] for the camera
  
  %if camera.cmatrix <> 0
  %error "camera.cmatrix was assumed to be 0 and it wasn't"
  %endif
  mov edi, [edi+scene.camera]
  lea ebx, [edi+camera.pmatrix]
  lea edx, [edi+camera.tmatrix]
  call _mul_matrix	; calculate the total matrix for the camera

  ; step 2: calculate [camera.tmatrix] * [object.omatrix] = [object.ematrix]
  
  mov ebx, edx
  %if object.omatrix <> 0
  %error "object.omatrix was assumed to be 0 and it wasn't"
  %endif
  mov edi, esi
  lea edx, [esi+object.ematrix]
  call _mul_matrix	; calculate the ematrix for the object

  popad
  
  push edi		;still pointer to scene (hopefully)
  call _calc_points
  pop edi

  ;; ESI EAX = unchanged --
  ;; ESI = pointer to object
  ;; EAX = resloutions, we need to save this
  ;; EDI = pointer to scene

  push eax			; save those resloutions
  push edi			; save the pointer to the scene

  mov ecx, [esi+object.mesh]
  mov edi, [edi+scene.buffer]
  mov ebp, [esi+object.points]
  mov edx, [ecx+mesh.faces]
  mov ecx, [ecx+mesh.face_count]

  ;; EDX = pointer to faces
  ;; ECX = number of faces
  ;; EBP = pointer to points
  ;; EDI = pointer to buffer
  ;; ESI = pointer to object still

;;XXX: use the real resloution in here. This code assumes mode 13h.
;;
;; We are now ready to draw the faces. Right now we just draw the first
;; vert of each one, and this works fine for meshes generated by blender.

.face:

; translate the normal vector from object to world cordinates ---===---

  fld dword[esi+object.omatrix+matrix44.xz]	; XXX really a dot product
  fmul dword[edx+face.norX]			; should be done here
  fld dword[esi+object.omatrix+matrix44.yz]	;
  fmul dword[edx+face.norY]			;
  fld dword[esi+object.omatrix+matrix44.zz]	;
  fmul dword[edx+face.norZ]			; Z Y X
  fxch						;
  faddp st2					;
  faddp st1					;
  fchs
  
  push edx
  fst dword[esp]			; this is poped of in .skip
  cmp dword[esp], byte 0
  pop eax
  jns near .skip			;and skip the face if norZ is negitive
  
pushad
  movzx eax, word[edx+face.vert1]	; EAX = index to first point
  call _get_vert

  cmp ebx, YRES			; XXX the real res. should be used here
  jae near .out0
  cmp eax, XRES
  jae near .out0

  push eax
  push ebx

  movzx eax, word[edx+face.vert2]	; EAX = index to 2nd point
  call _get_vert

  cmp ebx, YRES			; XXX the real res. should be used here
  jae near .out8
  cmp eax, XRES
  jae near .out8

  push eax
  push ebx

  movzx eax, word[edx+face.vert3]	; EAX = index to 2nd point
  call _get_vert

  cmp ebx, YRES			; XXX the real res. should be used here
  jae .out16
  cmp eax, XRES
  jae .out16

  push eax
  push ebx

  fmul dword[.num_colors]
  push eax
  fist dword[esp]
  pop edx

;; stack:
;; y2		+0
;; x2		+4
;; y1		+8
;; x1		+12
;; y0		+16
;; x1		+20
;;
;; EAX = x2
;; EBX = y2

  mov esi, [esp+8]
  mov ecx, [esp+12]
  call _draw_line
  
  mov esi, [esp+8]
  mov ecx, [esp+12]
  mov ebx, [esp]
  mov eax, [esp+4]
  mov edi, [esp+24]
  call _draw_line
  
  mov esi, [esp+16]
  mov ecx, [esp+20]
  mov ebx, [esp]
  mov eax, [esp+4]
  mov edi, [esp+24]
  call _draw_line
  
  add esp, byte 24

popad

; advance the pointers ---===---
.skip:
  add edx, byte face_size
  fstp st0
  dec ecx
  jnz .face

;; We have drawn all the faces of that object. Here's the end of the object
;; loop:

  pop edi		; pointer to scene
  pop eax		; the resloutions
  pop ecx		; the number of objects.
  dec ecx
  jnz .object

.done:
  retn

.out16:
  add esp, byte 8
.out8:
  add esp, byte 8
.out0:
  popad
  jmp short .skip

[section .data]
.num_colors: dd 255.0		; XXX this isn't thread safe
resx: dd F_HALF_XRES
resy: dd F_HALF_YRES
__SECT__



;-----------------------------------------------------------------------.
						_get_vert:		;
;>
;; returns the screen cords of a vertex
;;
;; parameters:
;; -----------
;; ECX = index of vert to get
;; EBP = ptr to verts
;;
;; returned values:
;; ----------------
;; EAX = x
;; EBX = y
;; all other registers unmodified
;<

  %if vect4_size <> 16
  %error "vect4_size was assumed to be 16 and it wasn't"
  %endif
  shl eax, 4
  add eax, ebp			; EAX = offset to first vector of the triangle
  
  fld dword[eax+vect4.x]	; x
  fld dword[eax+vect4.y]	; y x
  fld dword[eax+vect4.w]	; w y x
  fdiv to st2			; w y x/w
  fdivp st1			; y/w x/w

  ;; we now have our point in the range [-1,1]. This makes it easy to map to
  ;; screen cordinates and do clipping and such and stuff.

  fmul dword[resx]		; XXX CHEAT!!!
  push edx
  fistp dword[esp]
  pop eax
  fmul dword[resy]
  push edx
  fistp dword[esp]
  pop ebx

  add eax, XRES/2
  add ebx, YRES/2
  
  dec eax
  dec ebx

  retn



;-----------------------------------------------------------------------.
						_draw_line:		;

;>
;; draws (x0, y0)------(x1, y1); no clipping performed
;; 
;; parameters:
;; -----------
;; EAX = x0
;; EBX = y0
;; ECX = x1
;; ESI = y1
;; DL = color
;;
;; returned values:
;; ----------------
;; all registers except EDX destroyed
;;
;;
;; 
;; About the Bresenham implementation:
;; -----------------------------------
;; there are 8 possible cases for a line. We first arrange the points by
;; possibly swapping them so that the point with the lower Y value is always
;; first; this reduces the cases to 4:
;;
;;     dx > 0           dx < 0
;;  line goes ->      line goes <-
;; .--------------------------------.
;; |1)        ... |3) ...           |
;; |       ...    |      ...        |        dx > dy       |
;; |    ...       |         ...     | one pixel per column |
;; | ...          |            ...  |                      |
;; |*             |               * |
;; |--------------+-----------------|
;; |2)     .      |4)    .          |
;; |       .      |      .          |
;; |      .       |       .         |        dx < dy
;; |      .       |       .         | one pixel per row  -----
;; |     .        |        .        |
;; |     .        |        .        |
;; |    .         |         .       |
;; |    *         |         *       |
;; `--------------------------------'
;;
;; This routine does not have any special cases for horizontal, vertical, or
;; diagonal lines. I haven't done any tests yet, but I have a hunch that there
;; may be some very slight speed gain by doing that, so I'll save it for
;; another day.
;; 
;; Most Bresenham implementations I have seen make use of some variables to
;; keep track of which direction X and Y are going (to dec, or to inc). It all
;; looks good in C, but then you realise that there arn't that many registers
;; on an ia32 box when you do it in ASM, so the inner-most loop of your 3d
;; engine is shelling variables to memory and replacing "inc eax" with "add
;; eax, [esp+4]" which is a mere 4 times slower on an athlon. Consider that
;; 75% of hydro3d's time is spent in this loop, and suddenly you realise that
;; using that variable from memory has a 20% framerate hit. Gee...
;;
;; Anyway, this implementation has 4 seperate cases, where most have only 2
;; (they group 1&3 and 2&4, using that variable in memory to change the
;; direction of the line). I think it's pretty fast, but I have not checked
;; it with any other hardcore gfx programers; this was derived from my own two
;; frontal lobes using a mathamatical description of the algorithm.
;;
;;
;;
;; About the planar VGA memory implementation:
;; -------------------------------------------
;; Currently I'm playing with tweaked VGA modes, which have the funny property
;; of being a royal pain in the ass. Right now I use a resloution of 320x400,
;; which is basicly 13h without the doubled scanlines. In this mode the memory
;; is planar. There are 4 planes. Using the notation plane:byte_in_plane, the
;; pixels across the screen go like this:
;;
;; 0:0  1:0  2:0  3:0  0:1  1:1  2:1  3:1  0:2  1:2  3:2  4:2 ...
;;  ^                   ^                   ^
;; 
;; If I were to just write 3 bytes to 0xa0000 they would show up at the '^'
;; above.
;;
;; As you can imagine, it's quite a nightmare if I draw the scene to a
;; buffer in a linear manner and then want to copy it do display memory. So, I
;; draw to the buffer in a linear manner. By grouping all the pixels that will
;; go in each plane (in other words every 4th pixel) together I can avoid all
;; the messy unpacking and make use of rep movsd to copy rather than do it byte
;; per byte.
;;
;; If i grouped all of the bytes for each plane together and then copied all of
;; plane 0, then all of plane 1, etc. to the screen, I would get funny stripes
;; at the top of the display due to the scan. By the time the sweep comes back
;; to the top of the screen I may be 3/4 done with my copy, but that means I
;; have drawn planes 0, 1, and 2, but not 3. If you look at the figure above
;; you can see that every 4th pixel would not be drawn, and things would look
;; very, very bad.
;;
;; So, I only group the planes together for each scanline. Then I can easily
;; copy an entire scanline with only 4 plane changes, 4 rep movsd, and no
;; unpacking. The x-res is 320 and we have 4 planes, so one scanline in one
;; plane is 320/4 bytes; 80 bytes. Thus, in my buffer, the first 80 bytes go to
;; plane 0, the next 80 to plane 1, etc.
;;
;; To make this fast I use a macro to 'increment' the X cord when drawing. Just
;; INC alone would generate the sequence {0, 1, 2, 3, 4 ... 319} but because of my
;; planar layout I need {0, 80, 160, 240, 1, 81, 161, 241...79, 159, 239, 319}.
;; The macro inc_x does that. There is also a dec_x, which does the same sort
;; of thing but decrements.
;;
;; Lastly, the parameters are provided in a linear domain, not my planar one,
;; so I need to convert. If I am given 2 as a parameter, I need to convert that
;; to 160. The macro x_to_planar does this.
;<

; perhaps a better line drawing from vulture that could do antialiasing
;
;<vulture> I dunno about bresenham's, but when I draw lines I have a dy and a dx
;<vulture> and if dy>dx then draw along y
;<vulture> if dx>=dy then draw along x
;<vulture> and you do this....
;<vulture> edi = start memory offset
;<vulture> ebx = dy/dx
;<vulture> (.32 fixed point)
;<vulture> edx = start total
;<vulture> al = color
;<vulture> ecx = dx
;<vulture> then it'd look like:
;<vulture> drawline:
;<vulture>  mov [edi],al
;<vulture>  add edx,ebx
;<vulture>  sbb ebp,ebp
;<vulture>  and ebp,XRES
;<vulture>  add edi,ebp
;<vulture>  inc edi
;<vulture>  dec ecx
;<vulture>  jnz drawline

%macro inc_x 0		; effectivly increments X, except for a planar memory
  add eax, byte XRES/4	; model so that all the plane 0 pixels are the first 80
  cmp eax, XRES		; bytes in the buffer, plane 1 is the next 80, etc.
  jb %%no_wrap
  sub eax, XRES - 1	; we went past the scanline, so correct it
%%no_wrap:
%endmacro

%macro dec_x 0		; same as before, but decrement instead
  sub eax, byte XRES/4
  jns %%no_wrap
  add eax, XRES - 1
%%no_wrap:
%endmacro

  ; possibly swap points so that y0 =< y1; therefore dy =< 0
  cmp ebx, esi		; cmp y0, y1
  je near .possible_not_line
  jb .no_swap
  xchg eax, ecx		; flip the points
  xchg ebx, esi
.no_swap:
  
  sub ecx, eax		; ECX = dx
  sub esi, ebx		; EDX = dy ( always =< 0 )
  
  ;; now convert the linear X to the planar sort we need
  ;; the equation to do this is: newx = x / 4 + (x % 4) * 80
  ;; (x % 4) is the same as (x and 3)
  mov ebp, eax
  and eax, 3
  shr ebp, 2
%if XRES = 320
  lea eax, [eax*5]	;
  shl eax, 4		; eax * 80
%elif XRES = 360
  push edx
  lea edx, [eax+eax]
  shl eax, 5
  sub eax, edx
  lea eax, [eax+eax*2]
  pop edx
%else
  %error "cant multiply by XRES/4 here "
%endif
  add eax, ebp

  ;; and convert the Y to a memory offset to the scanline we want

%if XRES = 320
  lea ebx, [ebx*5]
  shl ebx, 6
%elif XRES = 360
  push edx
  lea edx, [ebx+ebx]
  shl ebx, 5
  sub ebx, edx
  lea ebx, [ebx+ebx*2]
  shl ebx, 2
  pop edx
%else
  %error "cant multiply by XRES here "
%endif
  add edi, ebx


  test ecx, ecx		; decide: case 1/2 or 3/4?
  js .case_3or4

  ; case is 1 or 2
  ; dy => 0, so we know the line goes to the left and we will be incrementing x

  ;; at this point:
  ;; EAX = x
  ;; EBX = y
  ;; ECX = dx \ both positive
  ;; EDX = dy /

  cmp ecx, esi	 ; decide: case 1 or 2?
  jb .case2

.case1:
  add esi, esi		; ESI = 2dy
  mov ebx, ecx
  mov ebp, esi
  sub ebp, ecx		; EBP = 2dy-dx, our decision variable (d)
  add ebx, ecx		; EDX = 2dx
.draw1:
  mov [edi+eax], dl
  test ebp, ebp
  js .no_step1		; skip if d < 0

  sub ebp, ebx		; d -= 2dx
  add edi, XRES
.no_step1:
  add ebp, esi		; d -= 2dy
  inc_x

  dec ecx
  jnz .draw1

  retn

.case2:
  add ecx, ecx
  mov ebx, esi
  mov ebp, ecx
  sub ebp, esi
  add ebx, esi
.draw2:
  mov [edi+eax], dl
  test ebp, ebp
  js .no_step2		; skip if d < 0

  sub ebp, ebx		; d -= 2dx
  inc_x
.no_step2:
  add ebp, ecx		; d -= 2dy
  add edi, XRES

  dec esi
  jnz .draw2

  retn



.case_3or4:

  neg ecx
  cmp ecx, esi	 ; decide: case 3 or 4?
  jb .case4

.case3:
  add esi, esi		; ESI = 2dy
  mov ebx, ecx
  mov ebp, esi
  sub ebp, ecx		; EBP = 2dy-dx, our decision variable (d)
  add ebx, ecx
.draw3:
  mov [edi+eax], dl
  test ebp, ebp
  js .no_step3		; skip if d < 0

  sub ebp, ebx		; d -= 2dx
  add edi, XRES
.no_step3:
  add ebp, esi		; d -= 2dy
  dec_x

  dec ecx
  jnz .draw3

  retn

.case4:
  add ecx, ecx		; EDX = 2dx
  mov ebx, esi
  mov ebp, ecx
  sub ebp, esi		; EBP = 2dx-dy, our decision variable (d)
  add ebx, esi
.draw4:
  mov [edi+eax], dl
  test ebp, ebp
  js .no_step4		; skip if d < 0

  sub ebp, ebx		; d -= 2dx
  dec_x
.no_step4:
  add ebp, ecx		; d -= 2dy
  add edi, XRES

  dec esi
  jnz .draw4

  retn

.possible_not_line:
  cmp eax, ecx
  jne .no_swap
  retn



;-----------------------------------------------------------------------.
						_calc_points:		;
;>
;; Runs through an object and generates coresponding 2dpoints.
;;
;; parameters:
;; -----------
;; ESI = pointer to object
;;
;; returned values:
;; ----------------
;; ESI = unchanged
;<

  mov edx, [esi+object.mesh]
  mov edi, [esi+object.points]
  mov ecx, [edx+mesh.vert_count]
  mov edx, [edx+mesh.verts]

  ;; esi = pointer to object
  ;; edx = pointer to verts
  ;; ecx = number of verts
  ;; edi = pointer to points
.point:
  fld dword[edx+vect3.x]
  fld dword[edx+vect3.y]
  fld dword[edx+vect3.z]	; z y x

  fld dword[esi+object.ematrix+matrix44.xx]	; xx z y x
  fmul st3					; x*xx z y x
  fld dword[esi+object.ematrix+matrix44.yx]	; yx x*xx z y x
  fmul st3					; y*yx x*xx z y x
  fld dword[esi+object.ematrix+matrix44.zx]	; ...
  fmul st3					; ...
  fld dword[esi+object.ematrix+matrix44.tx]	; tx z*zx y*yx x*xx z y x
  faddp st3					; z*zx y*yx x*xx+tx z y x
  faddp st2					; y*yx x*xx+tx+z*zx z y x
  faddp st1					; x*xx+tx+z*zx+y*yx z y x
  fstp dword[edi+vect4.x]

  fld dword[esi+object.ematrix+matrix44.xy]
  fmul st3
  fld dword[esi+object.ematrix+matrix44.yy]
  fmul st3
  fld dword[esi+object.ematrix+matrix44.zy]
  fmul st3
  fld dword[esi+object.ematrix+matrix44.ty]
  faddp st3
  faddp st2
  faddp st1
  fstp dword[edi+vect4.y]
  
  fld dword[esi+object.ematrix+matrix44.xz]
  fmul st3
  fld dword[esi+object.ematrix+matrix44.yz]
  fmul st3
  fld dword[esi+object.ematrix+matrix44.zz]
  fmul st3
  fld dword[esi+object.ematrix+matrix44.tz]
  faddp st3
  faddp st2
  faddp st1
  fstp dword[edi+vect4.z]
						; z y x
  fld dword[esi+object.ematrix+matrix44.xw]	; z y x*xw
  fmulp st3
  fld dword[esi+object.ematrix+matrix44.yw]
  fmulp st2					; z y*yw x*xw
  fld dword[esi+object.ematrix+matrix44.zw]
  fmulp st1					; z*zw y*yw x*xw
  fld dword[esi+object.ematrix+matrix44.tw]
  faddp st3
  faddp st2
  faddp st1
  fstp dword[edi+vect4.w]

  add edx, byte vect3_size	;move the pointers to the next cords
  add edi, byte vect4_size	;
  dec ecx			;
  jnz .point			;

  retn

; here's a 3dnow thing I started but never finished; I don't know if it works
; but someday I'll get around to testing it.
;
;  pushad
;
;  lea eax, [esi+object.ematrix]
;  mov ebx, edi
;
;  femms
;  align 16
;
;  .xform:
;  add ebx, 16
;  movq mm0, [edx]
;  movq mm1, [edx+8]
;  add edx, 16
;  movq mm2, mm0
;  movq mm3, [eax+matrix44.xx]
;  punpckldq mm0, mm0
;  movq mm4, [eax+matrix44.yx]
;  pfmul mm3, mm0
;  punpckhdq mm2, mm2
;  pfmul mm4, mm2
;  movq mm5, [eax+matrix44.xz]
;  movq mm7, [eax+matrix44.yz]
;  movq mm6, mm1
;  pfmul mm5, mm0
;  movq mm0, [eax+matrix44.zx]
;  punpckldq mm1, mm1
;  pfmul mm7, mm2
;  movq mm2, [eax+matrix44.zz]
;  pfmul mm0, mm1
;  pfadd mm3, mm4
;
;  movq mm4, [eax+matrix44.tx]
;  pfmul mm2, mm1
;  pfadd mm5, mm7
;
;  movq mm1, [eax+matrix44.tz]
;  punpckhdq mm6, mm6
;  pfadd mm3, mm4
;
;  pfmul mm4, mm6
;  pfmul mm1, mm6
;  pfadd mm5, mm2
;
;  pfadd mm3, mm4
;
;  movq [ebx-16], mm3
;  pfadd mm5, mm1
;
;  movq [ebx-8], mm5
;  dec ecx
;  jnz .xform
;
;  femms
;  
;  popad
;  retn



;-----------------------------------------------------------------------.
						_rotate_matrix:		;
;>
;; These functions modify the matrix to rotate the object. These are all in
;; radians, not degrees. There are 2pi radians in a circle, so to convert degree
;; to radians, multiply degrees by pi/180. These rotations are relitive to the
;; current orientaion of the object. If you need absloute rotations, you can set
;; the matrix to identiy first:
;;   dd 1.0, 0.0, 0.0
;;   dd 0.0, 1.0, 0.0
;;   dd 0.0, 0.0, 1.0
;;
;; (*) HOW TO SET THE EDX AND EBX REGISTERS
;; All the rotations are essentially the same code, only opperate on a diffrent
;; part of the matrix. By using these two pointers, I can combine 110
;; instructions down to about 20, with a speed loss of about 5 clocks per
;; rotation. The EDX and EBX registers should be a pointer to the matrix, then
;; a value must be added to them according to the following table:
;;
;;    X         Y         Z
;; --------  --------  --------
;; EDX: yx   EDX: zx   EDX: xx
;; EBX: zx   EBX: xx   EBX: yx
;;
;; Parameters:
;;------------
;; EDX EBX = pointers to matrix (^ see note)
;; ST0 = amount to rotate
;;
;; Returned values:
;;-----------------
;; All registers except EDX and EBX unchanged, fpu stack is clear.
;<

  fsincos			; [c] [sY]
				;
  fld     dword[edx]		;                 [12] [c] [s]
  fld     dword[ebx]		;            [24] [12] [c] [s]
  fld     st2			;        [c] [24] [12] [c] [s]
  fmul    st0,    st2		;      [c12] [24] [12] [c] [s]
  fld     st4			;  [s] [c12] [24] [12] [c] [s]
  fmul    st0,    st2		;[s24] [c12] [24] [12] [c] [s]
  fsubp   st1,    st0		;  [c12-s24] [24] [12] [c] [s]
  fstp    dword[edx]		;            [24] [12] [c] [s]
  fmul    st0,    st2		;           [c24] [12] [c] [s]
  fld     st3			;       [s] [c24] [12] [c] [s]
  fmulp   st2,    st0		;          [c24] [s12] [c] [s]
  faddp   st1,    st0		;            [s12+c24] [c] [s]
  fstp    dword[ebx]		;                      [c] [s]
				;
  add edx, byte 4		;
  add ebx, byte 4		;
				;
  fld     dword[edx]		; this is the same code
  fld     dword[ebx]		;
  fld     st2			;
  fmul    st0,    st2		;
  fld     st4			;
  fmul    st0,    st2		;
  fsubp   st1,    st0		;
  fstp    dword[edx]		;
  fmul    st0,    st2		;
  fld     st3			;
  fmulp   st2,    st0		;
  faddp   st1,    st0		;
  fstp    dword[ebx]		;
				;
  add edx, byte 4		;
  add ebx, byte 4		;
				;
  fld     dword[edx]		; this is the same except it clears the stack
  fld     dword[ebx]		;
  fld     st2			;
  fmul    st0,    st2		;
  fld     st4			;
  fmul    st0,    st2		;
  fsubp   st1,    st0		;
  fstp    dword[edx]		;
  fmulp   st2,    st0		;[Zy] [Zz*cY] [sY]
  fmulp   st2,    st0		;  [Zz*cY] [sY*Zy]
  faddp   st1,    st0		;
  fstp    dword[ebx]		;
				;
  retn				;



;-----------------------------------------------------------------------.
						_calc_normals:		;
;>
;; Runs through the faces and generates the normal vectors needed for lighting.
;;
;; Parameters:
;;------------
;; ESI = pointer to verts
;; EDI = pointer to faces
;; ECX = number of faces
;<

%define x1 dword[eax+vect3.x]
%define x2 dword[ebx+vect3.x]
%define x3 dword[edx+vect3.x]
%define y1 dword[eax+vect3.y]
%define y2 dword[ebx+vect3.y]
%define y3 dword[edx+vect3.y]
%define z1 dword[eax+vect3.z]
%define z2 dword[ebx+vect3.z]
%define z3 dword[edx+vect3.z]

.face:
;;normalX = y1 ( z2 - z3 ) + y2 ( z3 - z1 ) + y3 ( z1 - z2 )
;;normalY = z1 ( x2 - x3 ) + z2 ( x3 - x1 ) + z3 ( x1 - x2 )
;;normalZ = x1 ( y2 - y3 ) + x2 ( y3 - y1 ) + x3 ( y1 - y2 )

  movzx     eax,word[edi+face.vert1]		;
  movzx     ebx,word[edi+face.vert2]		;
  movzx     edx,word[edi+face.vert3]		;
  lea eax, [eax*3]
  lea ebx, [ebx*3]
  lea edx, [edx*3]
  lea eax, [esi+eax*4]
  lea ebx, [esi+ebx*4]
  lea edx, [esi+edx*4]


  fld z2			;z2
  fld z3			;z3     z2
  fsubp st1,st0			;z2-z3
  fld y1			;y1     z2-z3
  fmulp st1,st0			;y1(z2-z3)
  fld z3			;z3     y1(z2-z3)
  fld z1			;z1     z3      y1(z2-z3)
  fsubp st1,st0			;z3-z1  y1(z2-z3)
  fld y2			;y2     z3-z1   y1(z2-z3)
  fmulp st1,st0			;y2(z3-z1)      y1(z2-z3)
  fld z1			;z1     y2(z3-z1)       y1(z2-z3)
  fld z2			;z2     z1      y2(z3-z1)       y1(z2-z3)
  fsubp st1,st0			;z1-z2  y2(z3-z1)       y1(z2-z3)
  fld y3			;y3     z1-z2   y2(z3-z1)       y1(z2-z3)
  fmulp st1,st0			;y3(z1-z2)      y2(z3-z1)       y1(z2-z3)
  faddp st1,st0			;y3(z1-z2)+y2(z3-z1)    y1(z2-z3)
  faddp st1,st0			;y3(z1-z2)+y2(z3-z1)+y1(z2-z3)
  fstp dword[edi+face.norX]	;
				;
  fld x2			;z2
  fld x3			;z3     z2
  fsubp st1,st0			;z2-z3
  fld z1			;y1     z2-z3
  fmulp st1,st0			;y1(z2-z3)
  fld x3			;z3     y1(z2-z3)
  fld x1			;z1     z3      y1(z2-z3)
  fsubp st1,st0			;z3-z1  y1(z2-z3)
  fld z2			;y2     z3-z1   y1(z2-z3)
  fmulp st1,st0			;y2(z3-z1)      y1(z2-z3)
  fld x1			;z1     y2(z3-z1)       y1(z2-z3)
  fld x2			;z2     z1      y2(z3-z1)       y1(z2-z3)
  fsubp st1,st0			;z1-z2  y2(z3-z1)       y1(z2-z3)
  fld z3			;y3     z1-z2   y2(z3-z1)       y1(z2-z3)
  fmulp st1,st0			;y3(z1-z2)      y2(z3-z1)       y1(z2-z3)
  faddp st1,st0			;y3(z1-z2)+y2(z3-z1)    y1(z2-z3)
  faddp st1,st0			;y3(z1-z2)+y2(z3-z1)+y1(z2-z3)
  fstp dword[edi+face.norY]	;
				;
  fld y2			;z2
  fld y3			;z3     z2
  fsubp st1,st0			;z2-z3
  fld x1			;y1     z2-z3
  fmulp st1,st0			;y1(z2-z3)
  fld y3			;z3     y1(z2-z3)
  fld y1			;z1     z3      y1(z2-z3)
  fsubp st1,st0			;z3-z1  y1(z2-z3)
  fld x2			;y2     z3-z1   y1(z2-z3)
  fmulp st1,st0			;y2(z3-z1)      y1(z2-z3)
  fld y1			;z1     y2(z3-z1)       y1(z2-z3)
  fld y2			;z2     z1      y2(z3-z1)       y1(z2-z3)
  fsubp st1,st0			;z1-z2  y2(z3-z1)       y1(z2-z3)
  fld x3			;y3     z1-z2   y2(z3-z1)       y1(z2-z3)
  fmulp st1,st0			;y3(z1-z2)      y2(z3-z1)       y1(z2-z3)
  faddp st1,st0			;y3(z1-z2)+y2(z3-z1)    y1(z2-z3)
  faddp st1,st0			;y3(z1-z2)+y2(z3-z1)+y1(z2-z3)
  fstp dword[edi+face.norZ]	;

;we now have the vector, but it's not normalised.
  fld dword[edi+face.norZ]
  fld dword[edi+face.norY]
  fld dword[edi+face.norX]
			;x      z       y
  fld st0		;x      x       z       y
  fmul st0,st0		;x^2    x       z       y
  fld st2		;z      x^2     x       z       y
  fmul st0,st0		;z^2    x^2     x       z       y
  faddp st1,st0		;z^2+x^2        x       z       y
  fld st3		;y      z^2+x^2 x       z       y
  fmul st0,st0		;y^2    z^2+x^2 x       z       y
  faddp st1,st0		;y^2+z^2+x^2    x       z       y
  fsqrt			;legnth x       z       y
  fdiv st1,st0		;legnth X       z       y
  fdiv st2,st0		;legnth X       Z       y
  fdivp st3,st0		;X      Z       Y

  fstp    dword[edi+face.norX]
  fstp    dword[edi+face.norY]
  fstp    dword[edi+face.norZ]

  add edi, byte face_size

  dec ecx
  jnz near .face

  retn



;-----------------------------------------------------------------------.
						_mul_matrix:		;
;>
;; calculates 4x4 matrix multiplications
;; 
;; parameters:
;; -----------
;; EBX = ptr to first multiplicand
;; EDI = ptr to seccond multiplicand
;; EDX = ptr to place to put result matrix
;;
;; returned values:
;; ----------------
;; all regs except ECX = unmodified
;;
;; status:
;; -------
;; hellishly unoptimised, but working
;<

; [EBX] * [EDI] = [EDX]


  ;; we want to have 2 indicies, one for the X and one for the Y in the matrix.
  ;; The X index will go 0,16,32,48 and the Y index will go 0,4,8,12. To make
  ;; the counters easier to deal with we will go in reverse order so we can use
  ;; a js after the sub from the index rather than a sub + cmp.

  pushad

  mov eax, 12	; Y index
.outer_loop:
  mov esi, 48	; X index
.inner_loop:
  ; load row
  fld dword[ebx+eax+0]
  fld dword[ebx+eax+16]
  fld dword[ebx+eax+32]
  fld dword[ebx+eax+48]

  ; load col
  fld dword[edi+esi+0]
  fld dword[edi+esi+4]
  fld dword[edi+esi+8]
  fld dword[edi+esi+12]	; 12 8 4 0 48 32 16 0

  fmulp st4
  fmulp st4
  fmulp st4
  fmulp st4

  faddp st3
  faddp st2
  faddp st1

  lea ebp, [edx+eax]
  fstp dword[ebp+esi]

  sub esi, byte 16
  jns .inner_loop

  sub eax, byte 4
  jns .outer_loop

  popad
  retn



;-----------------------------------------------------------------------.
						_print_matrix:		;
;>
;; Dumps a 4x4 matrix to the system log, imagine that!
;;
;; parameters:
;; -----------
;; ESI = pointer to matrix
;;
;; returned values:
;; ----------------
;; all registers and flags unchanged.
;;
;; requires:
;; ---------
;; one fpu register
;;
;; status:
;; -------
;; working
;<

  pushad
  pushfd

  mov ebx, esi
  mov ecx, 4

  mov esi, .lf_str
;  externfunc sys_log.print_string

.loop:
  fld dword[ebx+matrix44.xx]
;  externfunc sys_log.print_float
  fstp st0
  mov esi, .space_str
;  externfunc sys_log.print_string
  
  fld dword[ebx+matrix44.yx]
;  externfunc sys_log.print_float
  fstp st0
  mov esi, .space_str
;  externfunc sys_log.print_string

  fld dword[ebx+matrix44.zx]
;  externfunc sys_log.print_float
  fstp st0
  mov esi, .space_str
;  externfunc sys_log.print_string

  fld dword[ebx+matrix44.tx]
;  externfunc sys_log.print_float
  fstp st0
  mov esi, .lf_str
;  externfunc sys_log.print_string

  add ebx, matrix44.xy
  dec ecx
  jnz .loop

;  externfunc sys_log.terminate

  popfd
  popad
  retn

[section .data]
.space_str: db " ",1
.lf_str: db 0x0a,1
__SECT__



;-----------------------------------------------------------------------.
;						vga stuff		;

MISC 		equ 		03c2h
SEQUENCER 	equ 		03c4h
CRTC 		equ 		03d4h
GRAPHICS 	equ	 	03ceh
FEATURE 	equ		03dah
ATTRIB 		equ		 03c0h
PELADDRESSWRITE	equ		03c8h
PELDATAREG	equ		03c9h
STATUS		equ		03dah

GRREGWRMODE	equ		5
GRREGMISC	equ		6
SQREGMAPMASK	equ		2
SQREGMEMORY	equ		4

BYTESPERFONT	equ		16
PALETTELEN	equ		256
NUMSEQUENCER	equ		5
NUMCRTC		equ		19h
NUMGRAPHICS	equ		9
NUMATTRIB	equ		15h

VREND		equ		011h
NOPROT		equ		07fh

ENABLEATTRIB	equ		020h

CURSORTOPDATA	equ		17
CURSORBOTTOMDATA	equ	18

BIOSMODE	equ		049h
COLUMNS		equ		04ah
CURSORTOP	equ		061h
CURSORBOTTOM	equ		060h
PAGESIZE	equ		04ch
PAGEOFFSET	equ		04eh
PAGENUM		equ		062h
MODESELVAL	equ		065h

%macro IODELAY 0
  times 8 nop
%endmacro


OutRegs:                                 ;Output CL registers to port DX
 xor al,al                              ;start at reg 0
.loop1:                                   ;
 mov ah,[esi]                            ;load data
 inc si                                 ;update source
 out dx,ax                              ;output data
IODELAY
 inc al                                 ;increase register number
 dec cl                                 ;decrease count
 jnz .loop1                 	        ;loop whilst still OK
 retn                                   ;and exit

SetModeRegs:	                        ;set VGA registers for mode data
                                        ;pointed to by SI
 mov dx,STATUS                          ;get retrace reg
.l1:                                      ;
 in al,dx                               ;get value
 IODELAY                                ;delay
 test al,8                              ;check for vertical retrace bit
 jnz .l1                                ;loop until clear
.l2:                                      ;
 in al,dx                               ;get value
IODELAY                                 ;delay
 test al,8                              ;check for retrace again
 jz .l2                                   ;loop until it's set this time
                                        ;so we get start of ret. to set mode
 xor ah,ah                              ;zero AH
 mov al,[esi]                            ;load BIOS mode number
 mov [BIOSMODE],al                ;store mode number
 inc si                                 ;update SI
 mov al,[esi]                            ;load number of columns
 mov [COLUMNS],al                 ;store number of columns
 inc si                                 ;update SI
 mov di,[esi]                            ;load Screen Seg
 add si,2                               ;update SI
 mov al,[esi+CURSORTOPDATA]              ;get cursor top data
 mov [CURSORTOP],al               ;store it
 mov al,[esi+CURSORBOTTOMDATA]           ;get cursor bottom data
 mov [CURSORBOTTOM],al            ;store it
 mov dx,MISC                            ;get VGA MISC reg num
 mov al,[esi]                            ;load AL
 inc si                                 ;update source
 out dx,al                              ;output to port
IODELAY
 mov dx,FEATURE                         ;get Feature controller number
 mov al,[esi]                            ;load data
 inc si                                 ;update source
 out dx,al                              ;output register data
IODELAY
 mov dx,SEQUENCER                       ;get sequencer port number
 mov cl,NUMSEQUENCER                    ;get number of regs to set
 call OutRegs                           ;do them
 mov ah,[esi+VREND]                      ;load CRTC VREND byte
 mov al,VREND                           ;load reg number
 and ah,NOPROT                          ;clear protection bit
 mov dx,CRTC                            ;CRTC port number
 out dx,ax                              ;no protection
 IODELAY
 mov cl,NUMCRTC                         ;number of CRTC regs
 call OutRegs                           ;output to port
 mov dx,GRAPHICS                        ;get graphics port number
 mov cl,NUMGRAPHICS                     ;get number of regs
 call OutRegs                           ;do it
 mov dx,FEATURE                         ;load feature controller port
 in al,dx                               ;reset attrib flip flop by reading
IODELAY
 mov dx,ATTRIB                          ;attribute controller port
 mov cl,NUMATTRIB                       ;number of regs
 xor al,al                              ;clear AL
.loop:                                 ;
 mov ah,[esi]                            ;load AH
 out dx,al                              ;output to port
IODELAY                                ;delay before register write
 xchg al,ah                             ;swap data/reg num
 out dx,al                              ;output to port
 xchg ah,al                             ;swap back
 inc al                                 ;next reg
 inc si                                 ;increase source
 cmp al,cl                              ;done yet?
 jb .loop                              ;loop until done
 mov al,ENABLEATTRIB                    ;enable attribute register reads
 out dx,al                              ;do it
IODELAY
 retn                                    ;and exit


set_320x200x8bpp:                                ;
;;Check 320x200x256
 pushad
 call clear_screen
 mov esi, MCGAMode                 ;get mode offset
 call SetModeRegs                       ;set registers
 popad
 retn

clear_screen:
 push edi
 push ecx
 push eax
 mov edi, 0xA0000
 mov ecx, 64000/4
 xor eax, eax
 rep stosd
 pop eax
 pop ecx
 pop edi
 retn



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

MCGAMode db 013h,40                     ;BIOS mode num, and num columns
 dw 0a000h
 db 063h,000h
 db 003h,001h,00fh,000h,00eh
 db 05fh,04fh,050h,082h,054h,080h,0bfh,01fh,000h,041h,000h,000h,000h,000h
 db 000h,000h,09ch,00eh,08fh,028h,040h,096h,0b9h,0a3h,0ffh
 db 000h,000h,000h,000h,000h,050h,007h,00fh,0ffh
 db 000h,001h,002h,003h,004h,005h,006h,007h,008h,009h,00ah,00bh,00ch,00dh
 db 00eh,00fh
 db 041h,000h,00fh,000h,000h

memory_frame:	dd memory_pool



;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

memory_pool:	resb 0x10000
.end:



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

test_verts:
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038102, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038101, 0.197130
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.738858, 1.038101, 0.197129
dd -0.823888, 1.164486, 0.091314
dd -0.858255, 1.108221, 0.095998
dd -0.879501, 1.053632, 0.101126
dd -0.890063, 1.012707, 0.105449
dd -0.894985, 0.984304, 0.109032
dd -0.897475, 0.963663, 0.112560
dd -0.896556, 0.946284, 0.116992
dd -0.888690, 0.931548, 0.122966
dd -0.870246, 0.923169, 0.129885
dd -0.844715, 0.925079, 0.135226
dd -0.821837, 0.932483, 0.137709
dd -0.804577, 0.939872, 0.138053
dd -0.790951, 0.944776, 0.137068
dd -0.777320, 0.946689, 0.134834
dd -0.759703, 0.948253, 0.130378
dd -0.735417, 0.953453, 0.122350
dd -0.706715, 0.966819, 0.110660
dd -0.683765, 0.987550, 0.098916
dd -0.671441, 1.007506, 0.090566
dd -0.666410, 1.023470, 0.085346
dd -0.664463, 1.036806, 0.081667
dd -0.663092, 1.050856, 0.078096
dd -0.662892, 1.069867, 0.074411
dd -0.666029, 1.097058, 0.071516
dd -0.675073, 1.130308, 0.071588
dd -0.688983, 1.158202, 0.075908
dd -0.702560, 1.174832, 0.081458
dd -0.713986, 1.183897, 0.085875
dd -0.724516, 1.190725, 0.088470
dd -0.737148, 1.198737, 0.089233
dd -0.756188, 1.204049, 0.089079
dd -0.785581, 1.196993, 0.089215
dd -0.914443, 1.284865, 0.001834
dd -0.985028, 1.165509, 0.013561
dd -1.028959, 1.051495, 0.025414
dd -1.050848, 0.967322, 0.034887
dd -1.060822, 0.910349, 0.042356
dd -1.065257, 0.871014, 0.049324
dd -1.062031, 0.840526, 0.057612
dd -1.043821, 0.817825, 0.068248
dd -1.003578, 0.809002, 0.079967
dd -0.949514, 0.818444, 0.088371
dd -0.901913, 0.835556, 0.091688
dd -0.866469, 0.850608, 0.091422
dd -0.838759, 0.859857, 0.088976
dd -0.811175, 0.862816, 0.084341
dd -0.775650, 0.864410, 0.075554
dd -0.726821, 0.871997, 0.060011
dd -0.669269, 0.894422, 0.037573
dd -0.623409, 0.931321, 0.015157
dd -0.598891, 0.968072, -0.000772
dd -0.588930, 0.998463, -0.010826
dd -0.585054, 1.024904, -0.018125
dd -0.582236, 1.053970, -0.025526
dd -0.581844, 1.094286, -0.033514
dd -0.588541, 1.152472, -0.040344
dd -0.607857, 1.223664, -0.041501
dd -0.637583, 1.283072, -0.033887
dd -0.666486, 1.318054, -0.023272
dd -0.690575, 1.336580, -0.014512
dd -0.712413, 1.349941, -0.009134
dd -0.738156, 1.365172, -0.007169
dd -0.776724, 1.373955, -0.006593
dd -0.836351, 1.356053, -0.004714
dd -1.008514, 1.394867, -0.066547
dd -1.116318, 1.206614, -0.045331
dd -1.183877, 1.029503, -0.025154
dd -1.217617, 0.900761, -0.009753
dd -1.232636, 0.815887, 0.001826
dd -1.238344, 0.760611, 0.012034
dd -1.231314, 0.722222, 0.023412
dd -1.200277, 0.699424, 0.037090
dd -1.135106, 0.699120, 0.051075
dd -1.049981, 0.722207, 0.059886
dd -0.976317, 0.751332, 0.062152
dd -0.922192, 0.774124, 0.060217
dd -0.880302, 0.786959, 0.055818
dd -0.838821, 0.789956, 0.048666
dd -0.785599, 0.789846, 0.035819
dd -0.712670, 0.796580, 0.013564
dd -0.626965, 0.822938, -0.018235
dd -0.558929, 0.870375, -0.049798
dd -0.522726, 0.919853, -0.072209
dd -0.508099, 0.962508, -0.086516
dd -0.502371, 1.001401, -0.097260
dd -0.498062, 1.046121, -0.108667
dd -0.497495, 1.109692, -0.121530
dd -0.508122, 1.202232, -0.133346
dd -0.538788, 1.315518, -0.137163
dd -0.586003, 1.409578, -0.127511
dd -0.631746, 1.464305, -0.112530
dd -0.669514, 1.492455, -0.099639
dd -0.703195, 1.511819, -0.091350
dd -0.742196, 1.533159, -0.087725
dd -0.800258, 1.543231, -0.085443
dd -0.890162, 1.510538, -0.080062
dd -1.103568, 1.490087, -0.109633
dd -1.248551, 1.228663, -0.076527
dd -1.340051, 0.986352, -0.046525
dd -1.385855, 0.812954, -0.024522
dd -1.405756, 0.701771, -0.008712
dd -1.411961, 0.634070, 0.004417
dd -1.399596, 0.593747, 0.017948
dd -1.353395, 0.579509, 0.032795
dd -1.260621, 0.597317, 0.046191
dd -1.142603, 0.640352, 0.052473
dd -1.042203, 0.683657, 0.051646
dd -0.969423, 0.714038, 0.046932
dd -0.913684, 0.729515, 0.040098
dd -0.858793, 0.731438, 0.030379
dd -0.788646, 0.727773, 0.013894
dd -0.692844, 0.730117, -0.013984
dd -0.580616, 0.754649, -0.053334
dd -0.491890, 0.806111, -0.092085
dd -0.444922, 0.863452, -0.119573
dd -0.426061, 0.915617, -0.137364
dd -0.418622, 0.965864, -0.151256
dd -0.412820, 1.026459, -0.166740
dd -0.412101, 1.114715, -0.184954
dd -0.426945, 1.244249, -0.202763
dd -0.469797, 1.402905, -0.210731
dd -0.535807, 1.534006, -0.200484
dd -0.599536, 1.609402, -0.182040
dd -0.651682, 1.647062, -0.165378
dd -0.697432, 1.671663, -0.154125
dd -0.749447, 1.697704, -0.148388
dd -0.826368, 1.706628, -0.143379
dd -0.945668, 1.655257, -0.132670
dd -1.196722, 1.566536, -0.124320
dd -1.377688, 1.229643, -0.077125
dd -1.492719, 0.921906, -0.035995
dd -1.550440, 0.705143, -0.006873
dd -1.574900, 0.570169, 0.013164
dd -1.580753, 0.494191, 0.028783
dd -1.561584, 0.458381, 0.043397
dd -1.498187, 0.461698, 0.057370
dd -1.375804, 0.507317, 0.067144
dd -1.223959, 0.576424, 0.067835
dd -1.096930, 0.635789, 0.061827
dd -1.006104, 0.673361, 0.053230
dd -0.937298, 0.690387, 0.043522
dd -0.869934, 0.690082, 0.031261
dd -0.784214, 0.680989, 0.011703
dd -0.667562, 0.675294, -0.020457
dd -0.531379, 0.691898, -0.065187
dd -0.424194, 0.740291, -0.108807
dd -0.367780, 0.800051, -0.139712
dd -0.345278, 0.858483, -0.160056
dd -0.336333, 0.918554, -0.176680
dd -0.329083, 0.994769, -0.196191
dd -0.328241, 1.108474, -0.220101
dd -0.347477, 1.276679, -0.244792
dd -0.403031, 1.482800, -0.258376
dd -0.488649, 1.652349, -0.249098
dd -0.571033, 1.748762, -0.228263
dd -0.637857, 1.795511, -0.208334
dd -0.695545, 1.824368, -0.194153
dd -0.759908, 1.853457, -0.185884
dd -0.854423, 1.858662, -0.177141
dd -1.001263, 1.785036, -0.159317
dd -1.285003, 1.621105, -0.109046
dd -1.499588, 1.208702, -0.045915
dd -1.636994, 0.837340, 0.007349
dd -1.706108, 0.579906, 0.043904
dd -1.734646, 0.424498, 0.068036
dd -1.739278, 0.344809, 0.085616
dd -1.711991, 0.320068, 0.100170
dd -1.629824, 0.349738, 0.111176
dd -1.476669, 0.432381, 0.114285
dd -1.291076, 0.533112, 0.106380
dd -1.138361, 0.609988, 0.093184
dd -1.030681, 0.654115, 0.079679
dd -0.950030, 0.671506, 0.066729
dd -0.871555, 0.667841, 0.052032
dd -0.772151, 0.651546, 0.030082
dd -0.637400, 0.634273, -0.004835
dd -0.480673, 0.636853, -0.052521
dd -0.357924, 0.674905, -0.098451
dd -0.293725, 0.731348, -0.130940
dd -0.268313, 0.792484, -0.152790
dd -0.258121, 0.860485, -0.171629
dd -0.249515, 0.951569, -0.194990
dd -0.248583, 1.090725, -0.224776
dd -0.272259, 1.298138, -0.257058
dd -0.340655, 1.552425, -0.277607
dd -0.446116, 1.760683, -0.270892
dd -0.547270, 1.877821, -0.248855
dd -0.628625, 1.932944, -0.226282
dd -0.697743, 1.964903, -0.209303
dd -0.773379, 1.995228, -0.198146
dd -0.883625, 1.994159, -0.184738
dd -1.055220, 1.895253, -0.158162
dd -1.365647, 1.651939, -0.064049
dd -1.610430, 1.166317, 0.016384
dd -1.768355, 0.735112, 0.082423
dd -1.847982, 0.440976, 0.126498
dd -1.879990, 0.269148, 0.154463
dd -1.882563, 0.190466, 0.173412
dd -1.846080, 0.183057, 0.186755
dd -1.744138, 0.247134, 0.192777
dd -1.559989, 0.374941, 0.186361
dd -1.341773, 0.511913, 0.167095
dd -1.165115, 0.607221, 0.144910
dd -1.042302, 0.657058, 0.125616
dd -0.951401, 0.673611, 0.109154
dd -0.863532, 0.665552, 0.092203
dd -0.752771, 0.640487, 0.068623
dd -0.603250, 0.608426, 0.032571
dd -0.430054, 0.591274, -0.015537
dd -0.295136, 0.611974, -0.061125
dd -0.225070, 0.659426, -0.093305
dd -0.197573, 0.719590, -0.115560
dd -0.186435, 0.793369, -0.136024
dd -0.176605, 0.898104, -0.162937
dd -0.175622, 1.061926, -0.198599
dd -0.203646, 1.307881, -0.238953
dd -0.284630, 1.609550, -0.267611
dd -0.409557, 1.855589, -0.264985
dd -0.529016, 1.992517, -0.242982
dd -0.624309, 2.055029, -0.218476
dd -0.703991, 2.088835, -0.198915
dd -0.789466, 2.118532, -0.184600
dd -0.913082, 2.108805, -0.165733
dd -1.105862, 1.982353, -0.129026
dd -1.436381, 1.658643, 0.008626
dd -1.707105, 1.104264, 0.107176
dd -1.883110, 0.618725, 0.186225
dd -1.972071, 0.292880, 0.237679
dd -2.006849, 0.109054, 0.269104
dd -2.006606, 0.035956, 0.288803
dd -1.960157, 0.051476, 0.299847
dd -1.838055, 0.156785, 0.299062
dd -1.623638, 0.336340, 0.280618
dd -1.374884, 0.512965, 0.247635
dd -1.176712, 0.627048, 0.214973
dd -1.040910, 0.681597, 0.189204
dd -0.941629, 0.696161, 0.169073
dd -0.846327, 0.682828, 0.150114
dd -0.726828, 0.647730, 0.125697
dd -0.566241, 0.598192, 0.090131
dd -0.381055, 0.556330, 0.044088
dd -0.237658, 0.553353, 0.001423
dd -0.163775, 0.586539, -0.028605
dd -0.135063, 0.642171, -0.050177
dd -0.123299, 0.719447, -0.071640
dd -0.112415, 0.836231, -0.101706
dd -0.111418, 1.023204, -0.143066
dd -0.143569, 1.305876, -0.191717
dd -0.236512, 1.652727, -0.229357
dd -0.379944, 1.934492, -0.232188
dd -0.516700, 2.089695, -0.211425
dd -0.624926, 2.158414, -0.185738
dd -0.714006, 2.192779, -0.163884
dd -0.807623, 2.220047, -0.146244
dd -0.941894, 2.199598, -0.121309
dd -1.151726, 2.044221, -0.073431
dd -1.495628, 1.642265, 0.105407
dd -1.787489, 1.025389, 0.222307
dd -1.978729, 0.492346, 0.314209
dd -2.075633, 0.140462, 0.372687
dd -2.112433, -0.050816, 0.407119
dd -2.108740, -0.114151, 0.426958
dd -2.051886, -0.071072, 0.434739
dd -1.909857, 0.080725, 0.425622
dd -1.666751, 0.316745, 0.393129
dd -1.390341, 0.535089, 0.344597
dd -1.173594, 0.667718, 0.300358
dd -1.027218, 0.725892, 0.267654
dd -0.921577, 0.737434, 0.243814
dd -0.820923, 0.718150, 0.223139
dd -0.695426, 0.672115, 0.198662
dd -0.527611, 0.603067, 0.165103
dd -0.335038, 0.532501, 0.123425
dd -0.186910, 0.500549, 0.086045
dd -0.111267, 0.514890, 0.059852
dd -0.082202, 0.562745, 0.039975
dd -0.070137, 0.641253, 0.018135
dd -0.058388, 0.768209, -0.014612
dd -0.057414, 0.976213, -0.061334
dd -0.093361, 1.292791, -0.118251
dd -0.197311, 1.681402, -0.165433
dd -0.357795, 1.995887, -0.174857
dd -0.510379, 2.167392, -0.156442
dd -0.630204, 2.241011, -0.130323
dd -0.727297, 2.274702, -0.106519
dd -0.827205, 2.297902, -0.085492
dd -0.969243, 2.265089, -0.054089
dd -1.191705, 2.080332, 0.005617
dd -1.542602, 1.605079, 0.221650
dd -1.850569, 0.933255, 0.356595
dd -2.053989, 0.360355, 0.460837
dd -2.157324, -0.011599, 0.525815
dd -2.195403, -0.205926, 0.562748
dd -2.187772, -0.255926, 0.582162
dd -2.120407, -0.181806, 0.585883
dd -1.959230, 0.020000, 0.567265
dd -1.689709, 0.315226, 0.519261
dd -1.389086, 0.576006, 0.453937
dd -1.157001, 0.726439, 0.397435
dd -1.002578, 0.787135, 0.357570
dd -0.892622, 0.794789, 0.330088
dd -0.788684, 0.769099, 0.308017
dd -0.659887, 0.711605, 0.284198
dd -0.488588, 0.621729, 0.253992
dd -0.293081, 0.519596, 0.218673
dd -0.143811, 0.454610, 0.188602
dd -0.068356, 0.446420, 0.167688
dd -0.039741, 0.483730, 0.150391
dd -0.027681, 0.561347, 0.128758
dd -0.015267, 0.696457, 0.093841
dd -0.014349, 0.922939, 0.042220
dd -0.053680, 1.269866, -0.022697
dd -0.167445, 1.695893, -0.079668
dd -0.343154, 2.039400, -0.096546
dd -0.509763, 2.224920, -0.081431
dd -0.639627, 2.302096, -0.055583
dd -0.743231, 2.333995, -0.030200
dd -0.847545, 2.351733, -0.005826
dd -0.994466, 2.305395, 0.032228
dd -1.225123, 2.091675, 0.104030
dd -1.577277, 1.550223, 0.352201
dd -1.896396, 0.831726, 0.504425
dd -2.108919, 0.226920, 0.620212
dd -2.217154, -0.159199, 0.691041
dd -2.255809, -0.352538, 0.729953
dd -2.243909, -0.386359, 0.748445
dd -2.166224, -0.278916, 0.747502
dd -1.987121, -0.025301, 0.718592
dd -1.693946, 0.329977, 0.654186
dd -1.372860, 0.632680, 0.571411
dd -1.128762, 0.799770, 0.502364
dd -0.968780, 0.861928, 0.455332
dd -0.856462, 0.865022, 0.424368
dd -0.751188, 0.832691, 0.401224
dd -0.621601, 0.763583, 0.378690
dd -0.450275, 0.652262, 0.352953
dd -0.255912, 0.516851, 0.325612
dd -0.108753, 0.416086, 0.304471
dd -0.035228, 0.382670, 0.289985
dd -0.007772, 0.407237, 0.275992
dd 0.004007, 0.482081, 0.255087
dd 0.016887, 0.623311, 0.218516
dd 0.017721, 0.865475, 0.162547
dd -0.024529, 1.238729, 0.090083
dd -0.146776, 1.697255, 0.023370
dd -0.335653, 2.065671, -0.001529
dd -0.514286, 2.262774, 0.009517
dd -0.652515, 2.342205, 0.034472
dd -0.761103, 2.371354, 0.061057
dd -0.868010, 2.382528, 0.088651
dd -1.017092, 2.321990, 0.133340
dd -1.251738, 2.080472, 0.217150
dd -1.558387, 1.571767, 0.471185
dd -1.872384, 0.867977, 0.627608
dd -2.080925, 0.278203, 0.745492
dd -2.186667, -0.096653, 0.817029
dd -2.223908, -0.282761, 0.856069
dd -2.211246, -0.312719, 0.874529
dd -2.133165, -0.204527, 0.873149
dd -1.953919, 0.045619, 0.842825
dd -1.660771, 0.392078, 0.775509
dd -1.339759, 0.683006, 0.688910
dd -1.095722, 0.840198, 0.616648
dd -0.935780, 0.895779, 0.567480
dd -0.823486, 0.894970, 0.535249
dd -0.718076, 0.860413, 0.511482
dd -0.587316, 0.789470, 0.489143
dd -0.412281, 0.675459, 0.465018
dd -0.210304, 0.535427, 0.441278
dd -0.053277, 0.428668, 0.424904
dd 0.027838, 0.390072, 0.414448
dd 0.058940, 0.410916, 0.403177
dd 0.070369, 0.483043, 0.383968
dd 0.078440, 0.621983, 0.348371
dd 0.069528, 0.862419, 0.292387
dd 0.012507, 1.235525, 0.218042
dd -0.126170, 1.697154, 0.146635
dd -0.325557, 2.071877, 0.115207
dd -0.507548, 2.275032, 0.120778
dd -0.645330, 2.358319, 0.142380
dd -0.752391, 2.388746, 0.167602
dd -0.857955, 2.398684, 0.195684
dd -1.005404, 2.336142, 0.242688
dd -1.237284, 2.094926, 0.330744
dd -1.486089, 1.674247, 0.573896
dd -1.779457, 1.044341, 0.720810
dd -1.971525, 0.514283, 0.831029
dd -2.067756, 0.174429, 0.898027
dd -2.101807, 0.000714, 0.935322
dd -2.092001, -0.038274, 0.954647
dd -2.023510, 0.037978, 0.957121
dd -1.861924, 0.229897, 0.934475
dd -1.592482, 0.499987, 0.878174
dd -1.292066, 0.727206, 0.801951
dd -1.060156, 0.849429, 0.736287
dd -0.905848, 0.891382, 0.690335
dd -0.795961, 0.887909, 0.659240
dd -0.691634, 0.855874, 0.635394
dd -0.559492, 0.793151, 0.612130
dd -0.377625, 0.695607, 0.586520
dd -0.160415, 0.580303, 0.561465
dd 0.016981, 0.498233, 0.544981
dd 0.114070, 0.475279, 0.535551
dd 0.153077, 0.501977, 0.526013
dd 0.164139, 0.571850, 0.509215
dd 0.162846, 0.700434, 0.477071
dd 0.135984, 0.921990, 0.425410
dd 0.054554, 1.268496, 0.355128
dd -0.106042, 1.703368, 0.284779
dd -0.311704, 2.064852, 0.249295
dd -0.487885, 2.267619, 0.248803
dd -0.616474, 2.355788, 0.265096
dd -0.715726, 2.391330, 0.286595
dd -0.816212, 2.405542, 0.312360
dd -0.958478, 2.353491, 0.357010
dd -1.181252, 2.140633, 0.440914
dd -1.402647, 1.764600, 0.678210
dd -1.671802, 1.212921, 0.813726
dd -1.845386, 0.746513, 0.914924
dd -1.931241, 0.444555, 0.976544
dd -1.961776, 0.285336, 1.011539
dd -1.954701, 0.239128, 1.031240
dd -1.896094, 0.285523, 1.037081
dd -1.753430, 0.421941, 1.021699
dd -1.510446, 0.618867, 0.976303
dd -1.234359, 0.785013, 0.910818
dd -1.017882, 0.873764, 0.852329
dd -0.871686, 0.902786, 0.810157
dd -0.766153, 0.897023, 0.780697
dd -0.664892, 0.867869, 0.757262
dd -0.534194, 0.813700, 0.733649
dd -0.349942, 0.732728, 0.707239
dd -0.123613, 0.641676, 0.681525
dd 0.068260, 0.583153, 0.665276
dd 0.177551, 0.574530, 0.656946
dd 0.222778, 0.605880, 0.649136
dd 0.233291, 0.672344, 0.634816
dd 0.223723, 0.789148, 0.606382
dd 0.181488, 0.989492, 0.559597
dd 0.080062, 1.305416, 0.494338
dd -0.096725, 1.707783, 0.426347
dd -0.303797, 2.050230, 0.387984
dd -0.471269, 2.248557, 0.382126
dd -0.589111, 2.339273, 0.393383
dd -0.679435, 2.378633, 0.411146
dd -0.773389, 2.396348, 0.434336
dd -0.908187, 2.354649, 0.475999
dd -1.118388, 2.171232, 0.554527
dd -1.309327, 1.838705, 0.781144
dd -1.551009, 1.367717, 0.903504
dd -1.704430, 0.967409, 0.994444
dd -1.779261, 0.705421, 1.049915
dd -1.806024, 0.562599, 1.082062
dd -1.801456, 0.511409, 1.101584
dd -1.752764, 0.531170, 1.110147
dd -1.629850, 0.616809, 1.101350
dd -1.415589, 0.746361, 1.066401
dd -1.167248, 0.856220, 1.011734
dd -0.969422, 0.914183, 0.960846
dd -0.833851, 0.931444, 0.922966
dd -0.734706, 0.923874, 0.895648
dd -0.638629, 0.897917, 0.873158
dd -0.512477, 0.852415, 0.849846
dd -0.330866, 0.787625, 0.823423
dd -0.102504, 0.719561, 0.797799
dd 0.096845, 0.682598, 0.782163
dd 0.213766, 0.686412, 0.774983
dd 0.263150, 0.720932, 0.768845
dd 0.272928, 0.782804, 0.756999
dd 0.256546, 0.886603, 0.732451
dd 0.202277, 1.063778, 0.691010
dd 0.086376, 1.345613, 0.631689
dd -0.099730, 1.710059, 0.567433
dd -0.302751, 2.027588, 0.527587
dd -0.458550, 2.217100, 0.517304
dd -0.564240, 2.307687, 0.523982
dd -0.644660, 2.349302, 0.538109
dd -0.730663, 2.369555, 0.558516
dd -0.855674, 2.337739, 0.596574
dd -1.049823, 2.184077, 0.668527
dd -1.208170, 1.892895, 0.879402
dd -1.419693, 1.502778, 0.987106
dd -1.551753, 1.169184, 1.066762
dd -1.615196, 0.948182, 1.115439
dd -1.638026, 0.823316, 1.144230
dd -1.635645, 0.769723, 1.162976
dd -1.596593, 0.767172, 1.173477
dd -1.493721, 0.808721, 1.170322
dd -1.309752, 0.879260, 1.145004
dd -1.092007, 0.939768, 1.100905
dd -0.915746, 0.970803, 1.057846
dd -0.793198, 0.977935, 1.024682
dd -0.702453, 0.969139, 0.999988
dd -0.613696, 0.946622, 0.978994
dd -0.495316, 0.909643, 0.956679
dd -0.321717, 0.860113, 0.931099
dd -0.099073, 0.812953, 0.906375
dd 0.099925, 0.794730, 0.891743
dd 0.219281, 0.808543, 0.885730
dd 0.270453, 0.844529, 0.881151
dd 0.279319, 0.900666, 0.871702
dd 0.257920, 0.990529, 0.851107
dd 0.195609, 1.143130, 0.815354
dd 0.071669, 1.388126, 0.762780
dd -0.116013, 1.709947, 0.703638
dd -0.309184, 1.996946, 0.663873
dd -0.450453, 2.173166, 0.650319
dd -0.542841, 2.260723, 0.653055
dd -0.612606, 2.302830, 0.663768
dd -0.689360, 2.324495, 0.681250
dd -0.802371, 2.301750, 0.715147
dd -0.977190, 2.177262, 0.779426
dd -1.101900, 1.924397, 0.969671
dd -1.281368, 1.612824, 1.061592
dd -1.391468, 1.344518, 1.129233
dd -1.443495, 1.164296, 1.170646
dd -1.462342, 1.058469, 1.195651
dd -1.461745, 1.005269, 1.213016
dd -1.431745, 0.985656, 1.224570
dd -1.348597, 0.991542, 1.225888
dd -1.195631, 1.013724, 1.209040
dd -1.010536, 1.033727, 1.174917
dd -0.858241, 1.042744, 1.139682
dd -0.750839, 1.041785, 1.111535
dd -0.670353, 1.032413, 1.089893
dd -0.590942, 1.013485, 1.070927
dd -0.483493, 0.984610, 1.050313
dd -0.323320, 0.948894, 1.026452
dd -0.114388, 0.919792, 1.003456
dd 0.076015, 0.916750, 0.990208
dd 0.192252, 0.937678, 0.985344
dd 0.242660, 0.973288, 0.982156
dd 0.250452, 1.022663, 0.974946
dd 0.226089, 1.098046, 0.958256
dd 0.160197, 1.225355, 0.928373
dd 0.035255, 1.431756, 0.883190
dd -0.145789, 1.707318, 0.830458
dd -0.323301, 1.958822, 0.792417
dd -0.447481, 2.117443, 0.776915
dd -0.525769, 2.199007, 0.776503
dd -0.584418, 2.239732, 0.784140
dd -0.650846, 2.261576, 0.798641
dd -0.749896, 2.246762, 0.827918
dd -0.902528, 2.149929, 0.883604
dd -0.993694, 1.931704, 1.048962
dd -1.140166, 1.693857, 1.124439
dd -1.228374, 1.487351, 1.179691
dd -1.269310, 1.346434, 1.213585
dd -1.284251, 1.260164, 1.234480
dd -1.284966, 1.210205, 1.249887
dd -1.263134, 1.179434, 1.261554
dd -1.198772, 1.159387, 1.266011
dd -1.076575, 1.145615, 1.256181
dd -0.925219, 1.135423, 1.231118
dd -0.798603, 1.128130, 1.203462
dd -0.708050, 1.121415, 1.180482
dd -0.639407, 1.112151, 1.162235
dd -0.571123, 1.096852, 1.145781
dd -0.477500, 1.075402, 1.127535
dd -0.335877, 1.051592, 1.106235
dd -0.148412, 1.037074, 1.085758
dd 0.025229, 1.045101, 1.074241
dd 0.132761, 1.069974, 1.070473
dd 0.179817, 1.103331, 1.068461
dd 0.186404, 1.145106, 1.063260
dd 0.161268, 1.205898, 1.050301
dd 0.096469, 1.307966, 1.026296
dd -0.022242, 1.475176, 0.988932
dd -0.188449, 1.702196, 0.943735
dd -0.344843, 1.914224, 0.909049
dd -0.449845, 2.051386, 0.893010
dd -0.513656, 2.124110, 0.890361
dd -0.561060, 2.161577, 0.895365
dd -0.616379, 2.182334, 0.906919
dd -0.699896, 2.174039, 0.931250
dd -0.828108, 2.102449, 0.977668
dd -0.886886, 1.914779, 1.114929
dd -1.000435, 1.743616, 1.173808
dd -1.067490, 1.593556, 1.216680
dd -1.097999, 1.489275, 1.243032
dd -1.109226, 1.422474, 1.259622
dd -1.110749, 1.378485, 1.272560
dd -1.095957, 1.342754, 1.283405
dd -1.048876, 1.307225, 1.289579
dd -0.956272, 1.270910, 1.285111
dd -0.838701, 1.241680, 1.267924
dd -0.738676, 1.224241, 1.247369
dd -0.666146, 1.214263, 1.229547
dd -0.610554, 1.205783, 1.214932
dd -0.554824, 1.194043, 1.201392
dd -0.477476, 1.179116, 1.186103
dd -0.358918, 1.164951, 1.168122
dd -0.199958, 1.161123, 1.150873
dd -0.050670, 1.175799, 1.141377
dd 0.042880, 1.201349, 1.138619
dd 0.084116, 1.230664, 1.137533
dd 0.089407, 1.264237, 1.134051
dd 0.065696, 1.310778, 1.124538
dd 0.006597, 1.388429, 1.106237
dd -0.098897, 1.517057, 1.076879
dd -0.242586, 1.694756, 1.040103
dd -0.373093, 1.864569, 1.010286
dd -0.457434, 1.977099, 0.995127
dd -0.506834, 2.038429, 0.991214
dd -0.543212, 2.070876, 0.994104
dd -0.586985, 2.089325, 1.002836
dd -0.653884, 2.085946, 1.022049
dd -0.756209, 2.036432, 1.058815
dd -0.784623, 1.875036, 1.166096
dd -0.866308, 1.761780, 1.208726
dd -0.913556, 1.661320, 1.239595
dd -0.934587, 1.590008, 1.258610
dd -0.942398, 1.542013, 1.270838
dd -0.944217, 1.506438, 1.280887
dd -0.935169, 1.471864, 1.290033
dd -0.903402, 1.431375, 1.296506
dd -0.838372, 1.386101, 1.295647
dd -0.753618, 1.349143, 1.284957
dd -0.680266, 1.327795, 1.270831
dd -0.626348, 1.317053, 1.258005
dd -0.584581, 1.309982, 1.247141
dd -0.542403, 1.301626, 1.236814
dd -0.483197, 1.292160, 1.224961
dd -0.391360, 1.285177, 1.210929
dd -0.266826, 1.287970, 1.197493
dd -0.148469, 1.304842, 1.190239
dd -0.073561, 1.327904, 1.188376
dd -0.040342, 1.351573, 1.187949
dd -0.036399, 1.376613, 1.185855
dd -0.056612, 1.409654, 1.179409
dd -0.105748, 1.464414, 1.166474
dd -0.191696, 1.556200, 1.145061
dd -0.306148, 1.685310, 1.117308
dd -0.406953, 1.811535, 1.093671
dd -0.469822, 1.897117, 1.080731
dd -0.505310, 1.944934, 1.076526
dd -0.531203, 1.970818, 1.077868
dd -0.563356, 1.985850, 1.083980
dd -0.613090, 1.985699, 1.098065
dd -0.688890, 1.954548, 1.125097
dd -0.689575, 1.815118, 1.201942
dd -0.741310, 1.749886, 1.229123
dd -0.770583, 1.691189, 1.248693
dd -0.783301, 1.648462, 1.260773
dd -0.788074, 1.618103, 1.268711
dd -0.789701, 1.592986, 1.275564
dd -0.785019, 1.565251, 1.282241
dd -0.766282, 1.529783, 1.287677
dd -0.726141, 1.488507, 1.288683
dd -0.672345, 1.454615, 1.283014
dd -0.624969, 1.435302, 1.274502
dd -0.589674, 1.426153, 1.266376
dd -0.562053, 1.421036, 1.259264
dd -0.533966, 1.415803, 1.252338
dd -0.494123, 1.410644, 1.244269
dd -0.431648, 1.408332, 1.234659
dd -0.346074, 1.413751, 1.225474
dd -0.263899, 1.428592, 1.220601
dd -0.211448, 1.446279, 1.219500
dd -0.188070, 1.462968, 1.219463
dd -0.185483, 1.479411, 1.218407
dd -0.200361, 1.500050, 1.214586
dd -0.235839, 1.534007, 1.206546
dd -0.296892, 1.591649, 1.192791
dd -0.376675, 1.674261, 1.174359
dd -0.445075, 1.756881, 1.157950
dd -0.486339, 1.814131, 1.148415
dd -0.508782, 1.846850, 1.144838
dd -0.524999, 1.864916, 1.145201
dd -0.545800, 1.875595, 1.148962
dd -0.578358, 1.877000, 1.158055
dd -0.627806, 1.860211, 1.175560
dd -0.603738, 1.738523, 1.222858
dd -0.628099, 1.710988, 1.235745
dd -0.641565, 1.685762, 1.244970
dd -0.647258, 1.666836, 1.250677
dd -0.649420, 1.652560, 1.254509
dd -0.650419, 1.639466, 1.257975
dd -0.648728, 1.623548, 1.261552
dd -0.640582, 1.602036, 1.264766
dd -0.622192, 1.576429, 1.265999
dd -0.596803, 1.555338, 1.263869
dd -0.574045, 1.543407, 1.260073
dd -0.556864, 1.537951, 1.256245
dd -0.543285, 1.535229, 1.252784
dd -0.529387, 1.532793, 1.249333
dd -0.509478, 1.530773, 1.245258
dd -0.477949, 1.530718, 1.240380
dd -0.434373, 1.535057, 1.235724
dd -0.392145, 1.544080, 1.233292
dd -0.364995, 1.553917, 1.232813
dd -0.352842, 1.562607, 1.232910
dd -0.351579, 1.570636, 1.232545
dd -0.359602, 1.580213, 1.230874
dd -0.378441, 1.595848, 1.227162
dd -0.410431, 1.622751, 1.220591
dd -0.451572, 1.662063, 1.211493
dd -0.486010, 1.702278, 1.203062
dd -0.506148, 1.730728, 1.197917
dd -0.516700, 1.747326, 1.195784
dd -0.524247, 1.756652, 1.195717
dd -0.534256, 1.762248, 1.197434
dd -0.550106, 1.763644, 1.201801
dd -0.574096, 1.757178, 1.210231
dd -0.528352, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649169, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649169, 1.229972
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649169, 1.229972
dd -0.528353, 1.649169, 1.229972
dd -0.528353, 1.649169, 1.229972
dd -0.528353, 1.649169, 1.229972
dd -0.528353, 1.649170, 1.229972
dd -0.528353, 1.649169, 1.229972
dd -0.528353, 1.649169, 1.229972
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528353, 1.649170, 1.229973
dd -0.528352, 1.649170, 1.229973
dd -0.528352, 1.649169, 1.229973
dd -0.528352, 1.649170, 1.229973
dd -0.528352, 1.649170, 1.229973
dd -0.528352, 1.649170, 1.229973
dd -1.147479, 0.248323, 0.435546
dd -1.153552, 0.247975, 0.438222
dd -1.159075, 0.243510, 0.438132
dd -1.162248, 0.231235, 0.432793
dd -1.162662, 0.206751, 0.419848
dd -1.159658, 0.162401, 0.395071
dd -1.151665, 0.095681, 0.356692
dd -1.136404, 0.012758, 0.307402
dd -1.114033, -0.056615, 0.263357
dd -1.092685, -0.070848, 0.249201
dd -1.082492, -0.045250, 0.258619
dd -1.085726, -0.010164, 0.275066
dd -1.103319, 0.018657, 0.289205
dd -1.139898, 0.036090, 0.297399
dd -1.197633, 0.045684, 0.300155
dd -1.272416, 0.049478, 0.296648
dd -1.339765, 0.048384, 0.285848
dd -1.362903, 0.044108, 0.271080
dd -1.354507, 0.036553, 0.257987
dd -1.342322, 0.024722, 0.247982
dd -1.344352, 0.005896, 0.239714
dd -1.371716, -0.024023, 0.231804
dd -1.417597, -0.059862, 0.227460
dd -1.463179, -0.085318, 0.234741
dd -1.469535, -0.069208, 0.264341
dd -1.408067, 0.003689, 0.313638
dd -1.321978, 0.090076, 0.360042
dd -1.248164, 0.159336, 0.393164
dd -1.196916, 0.205292, 0.413658
dd -1.167188, 0.230662, 0.424731
dd -1.151157, 0.243386, 0.430472
dd -1.145208, 0.248007, 0.433350
dd -1.118360, 0.203462, 0.357319
dd -1.096590, 0.202166, 0.370976
dd -1.081800, 0.191515, 0.382100
dd -1.072184, 0.172548, 0.386541
dd -1.063919, 0.142965, 0.382892
dd -1.053230, 0.095384, 0.369526
dd -1.038214, 0.025168, 0.348637
dd -1.018881, -0.064346, 0.326657
dd -1.000125, -0.145875, 0.318545
dd -0.991679, -0.175483, 0.337557
dd -0.995783, -0.160922, 0.370960
dd -1.009427, -0.129499, 0.406265
dd -1.032252, -0.096282, 0.441491
dd -1.069072, -0.064903, 0.480715
dd -1.125446, -0.032892, 0.524155
dd -1.202542, -0.002792, 0.561899
dd -1.283012, 0.013073, 0.568757
dd -1.331046, 0.002300, 0.526714
dd -1.347846, -0.023904, 0.465753
dd -1.355158, -0.052932, 0.411372
dd -1.371238, -0.081331, 0.370182
dd -1.409371, -0.110656, 0.340130
dd -1.464676, -0.137753, 0.315885
dd -1.518104, -0.149506, 0.297329
dd -1.527954, -0.122314, 0.290377
dd -1.463147, -0.050018, 0.299405
dd -1.370113, 0.028913, 0.315197
dd -1.289004, 0.090949, 0.329318
dd -1.231008, 0.133541, 0.338730
dd -1.194099, 0.161240, 0.343124
dd -1.167207, 0.181079, 0.345333
dd -1.142936, 0.195608, 0.348765
dd -1.092995, 0.140239, 0.274622
dd -1.041466, 0.137487, 0.297666
dd -1.005145, 0.121624, 0.317924
dd -0.982097, 0.097278, 0.330446
dd -0.964803, 0.063663, 0.335019
dd -0.946169, 0.013460, 0.332621
dd -0.923925, -0.060052, 0.329241
dd -0.900455, -0.156427, 0.334952
dd -0.885535, -0.250927, 0.363312
dd -0.890516, -0.297081, 0.415796
dd -0.909499, -0.294926, 0.473077
dd -0.934045, -0.268842, 0.526742
dd -0.962519, -0.233603, 0.582114
dd -1.000002, -0.191973, 0.650797
dd -1.055522, -0.142421, 0.732763
dd -1.135555, -0.090908, 0.809456
dd -1.229776, -0.060003, 0.832767
dd -1.303073, -0.073657, 0.764537
dd -1.345167, -0.112464, 0.657929
dd -1.371951, -0.153204, 0.561276
dd -1.402052, -0.187227, 0.488697
dd -1.451009, -0.213535, 0.437418
dd -1.515978, -0.230225, 0.393845
dd -1.577841, -0.226785, 0.349882
dd -1.592225, -0.186847, 0.306802
dd -1.525296, -0.113461, 0.276021
dd -1.426220, -0.040920, 0.261652
dd -1.338279, 0.014157, 0.257252
dd -1.273605, 0.052860, 0.256213
dd -1.229193, 0.081437, 0.254879
dd -1.190605, 0.106012, 0.254734
dd -1.146502, 0.127409, 0.259729
dd -1.072621, 0.058208, 0.189364
dd -0.990066, 0.053474, 0.219715
dd -0.931486, 0.033651, 0.246488
dd -0.894682, 0.005569, 0.264937
dd -0.868235, -0.030754, 0.276274
dd -0.841599, -0.082815, 0.284013
dd -0.812117, -0.159298, 0.297641
dd -0.784560, -0.262634, 0.330643
dd -0.773608, -0.370635, 0.394991
dd -0.792207, -0.434158, 0.480289
dd -0.826276, -0.445581, 0.560609
dd -0.861957, -0.426566, 0.631518
dd -0.896383, -0.392044, 0.705376
dd -0.934978, -0.344634, 0.800865
dd -0.990243, -0.283564, 0.917770
dd -1.073833, -0.216796, 1.029650
dd -1.182099, -0.173462, 1.067563
dd -1.280318, -0.185834, 0.975158
dd -1.347055, -0.230052, 0.826772
dd -1.392704, -0.275967, 0.691486
dd -1.436375, -0.310994, 0.590187
dd -1.495891, -0.331648, 0.519348
dd -1.570505, -0.336364, 0.457670
dd -1.641211, -0.316509, 0.389547
dd -1.661167, -0.262327, 0.311899
dd -1.593553, -0.185978, 0.243022
dd -1.489633, -0.118434, 0.199903
dd -1.395585, -0.069809, 0.178076
dd -1.324516, -0.035473, 0.167612
dd -1.272460, -0.007676, 0.161792
dd -1.221585, 0.018811, 0.160693
dd -1.156541, 0.043442, 0.168343
dd -1.058360, -0.041989, 0.103902
dd -0.944335, -0.049225, 0.139052
dd -0.863377, -0.071507, 0.169260
dd -0.812884, -0.101403, 0.191081
dd -0.777429, -0.138899, 0.207375
dd -0.742975, -0.191919, 0.224028
dd -0.706462, -0.270927, 0.253591
dd -0.674999, -0.381119, 0.312607
dd -0.668041, -0.502789, 0.411305
dd -0.700050, -0.584056, 0.527687
dd -0.748972, -0.609929, 0.629421
dd -0.795700, -0.599669, 0.715821
dd -0.836227, -0.568851, 0.805770
dd -0.876399, -0.520757, 0.924326
dd -0.932072, -0.455144, 1.071155
dd -1.019790, -0.380359, 1.213005
dd -1.141998, -0.327851, 1.263038
dd -1.263996, -0.334403, 1.149410
dd -1.353910, -0.375956, 0.964783
dd -1.417173, -0.419700, 0.796051
dd -1.473503, -0.450621, 0.669844
dd -1.542964, -0.462890, 0.581877
dd -1.626906, -0.454280, 0.503996
dd -1.706634, -0.417166, 0.413826
dd -1.733132, -0.347532, 0.304384
dd -1.666434, -0.266250, 0.200461
dd -1.559135, -0.202020, 0.131026
dd -1.459966, -0.159092, 0.093512
dd -1.383008, -0.129512, 0.075038
dd -1.323386, -0.104297, 0.066234
dd -1.259953, -0.079062, 0.065749
dd -1.173390, -0.055291, 0.077173
dd -1.051081, -0.158510, 0.020876
dd -0.906089, -0.168726, 0.057991
dd -0.803322, -0.191787, 0.088233
dd -0.739637, -0.221386, 0.110590
dd -0.695608, -0.258372, 0.129751
dd -0.653774, -0.311361, 0.153732
dd -0.610671, -0.392337, 0.197588
dd -0.575617, -0.509060, 0.280445
dd -0.572554, -0.644157, 0.410677
dd -0.617334, -0.743016, 0.555327
dd -0.680400, -0.783824, 0.676068
dd -0.737739, -0.783848, 0.775602
dd -0.784338, -0.759820, 0.878581
dd -0.826533, -0.716512, 1.015487
dd -0.883312, -0.653959, 1.185947
dd -0.975641, -0.579152, 1.351257
dd -1.111246, -0.521234, 1.410378
dd -1.255063, -0.517292, 1.279345
dd -1.365863, -0.547624, 1.065524
dd -1.444859, -0.581405, 0.869932
dd -1.512480, -0.602880, 0.723671
dd -1.590919, -0.604107, 0.621711
dd -1.683561, -0.581133, 0.530163
dd -1.772224, -0.526395, 0.420888
dd -1.806097, -0.440497, 0.283609
dd -1.741999, -0.352328, 0.148991
dd -1.632995, -0.289506, 0.056661
dd -1.529918, -0.251290, 0.005806
dd -1.447795, -0.226735, -0.018913
dd -1.380926, -0.205949, -0.028999
dd -1.305035, -0.185312, -0.027213
dd -1.197004, -0.166755, -0.010936
dd -1.051282, -0.288364, -0.057035
dd -0.876810, -0.301964, -0.020961
dd -0.753503, -0.324034, 0.005779
dd -0.677551, -0.351150, 0.025712
dd -0.625667, -0.385896, 0.045478
dd -0.577139, -0.437826, 0.074913
dd -0.528110, -0.520129, 0.130910
dd -0.489903, -0.642844, 0.234607
dd -0.490513, -0.790697, 0.392465
dd -0.547003, -0.906442, 0.561579
dd -0.623033, -0.962224, 0.698235
dd -0.690199, -0.973804, 0.808047
dd -0.742651, -0.959555, 0.920470
dd -0.787270, -0.926571, 1.070256
dd -0.845848, -0.874882, 1.257071
dd -0.943145, -0.808356, 1.438346
dd -1.091163, -0.749110, 1.503121
dd -1.254087, -0.730144, 1.359192
dd -1.382743, -0.740716, 1.124408
dd -1.475025, -0.756749, 0.909636
dd -1.552164, -0.763523, 0.748989
dd -1.638299, -0.751288, 0.636725
dd -1.738716, -0.713324, 0.534572
dd -1.835944, -0.641130, 0.409846
dd -1.877830, -0.538628, 0.249706
dd -1.818000, -0.441758, 0.089869
dd -1.709083, -0.378321, -0.021090
dd -1.603480, -0.343647, -0.082433
dd -1.517105, -0.324241, -0.111370
dd -1.443548, -0.309665, -0.120932
dd -1.355687, -0.296958, -0.115222
dd -1.226909, -0.287977, -0.093120
dd -1.059016, -0.427644, -0.127386
dd -0.857472, -0.444928, -0.095349
dd -0.715538, -0.464254, -0.075564
dd -0.628631, -0.486764, -0.060967
dd -0.569858, -0.517594, -0.042891
dd -0.515533, -0.567462, -0.010061
dd -0.461430, -0.650408, 0.055535
dd -0.420609, -0.778384, 0.176405
dd -0.424554, -0.937922, 0.357097
dd -0.491324, -1.069322, 0.546084
dd -0.578730, -1.139654, 0.695050
dd -0.654631, -1.163714, 0.811943
dd -0.712534, -1.161957, 0.929906
dd -0.759906, -1.144555, 1.086659
dd -0.820922, -1.111261, 1.281994
dd -0.923395, -1.061129, 1.471189
dd -1.082454, -1.004708, 1.537984
dd -1.261158, -0.966617, 1.386100
dd -1.404064, -0.949431, 1.139294
dd -1.506759, -0.940421, 0.913673
dd -1.591335, -0.927654, 0.744793
dd -1.683635, -0.899935, 0.626266
dd -1.790656, -0.846810, 0.516919
dd -1.895814, -0.757869, 0.380899
dd -1.946107, -0.638936, 0.203619
dd -1.892094, -0.531804, 0.024860
dd -1.785066, -0.465732, -0.099854
dd -1.678408, -0.433311, -0.168484
dd -1.588831, -0.419020, -0.199466
dd -1.509355, -0.412258, -0.206699
dd -1.410390, -0.410594, -0.195522
dd -1.262230, -0.415288, -0.166798
dd -1.073876, -0.571908, -0.188214
dd -0.848435, -0.593061, -0.163019
dd -0.690308, -0.608013, -0.153355
dd -0.594061, -0.623979, -0.146776
dd -0.529553, -0.649375, -0.132582
dd -0.470484, -0.696264, -0.098472
dd -0.412293, -0.779162, -0.026053
dd -0.369465, -0.911528, 0.107885
dd -0.376314, -1.081350, 0.306036
dd -0.451653, -1.226727, 0.509807
dd -0.548538, -1.310754, 0.667187
dd -0.631840, -1.347818, 0.787820
dd -0.694636, -1.360824, 0.907339
dd -0.744999, -1.363672, 1.065072
dd -0.809007, -1.355570, 1.261011
dd -0.916702, -1.329264, 1.450024
dd -1.085122, -1.279642, 1.515225
dd -1.275878, -1.218998, 1.360457
dd -1.429081, -1.167084, 1.110732
dd -1.539062, -1.126660, 0.882731
dd -1.628817, -1.090215, 0.711884
dd -1.725598, -1.045506, 0.591229
dd -1.837880, -0.977512, 0.478241
dd -1.950102, -0.873026, 0.335334
dd -2.008933, -0.738328, 0.147025
dd -1.962075, -0.619719, -0.043929
dd -1.858642, -0.549119, -0.177216
dd -1.752398, -0.517624, -0.249786
dd -1.660744, -0.508259, -0.280629
dd -1.576278, -0.510639, -0.283839
dd -1.467389, -0.522727, -0.265852
dd -1.301774, -0.544687, -0.229926
dd -1.095055, -0.716642, -0.238215
dd -0.849434, -0.741724, -0.222321
dd -0.677901, -0.750885, -0.225480
dd -0.574121, -0.758663, -0.229226
dd -0.505140, -0.777347, -0.220879
dd -0.442466, -0.820473, -0.187532
dd -0.381244, -0.902671, -0.111124
dd -0.337042, -1.038469, 0.031604
dd -0.346300, -1.216944, 0.241601
dd -0.428334, -1.374292, 0.454894
dd -0.532619, -1.470800, 0.616741
dd -0.621838, -1.520980, 0.737839
dd -0.688855, -1.550468, 0.855089
dd -0.742347, -1.577394, 1.008095
dd -0.809781, -1.600189, 1.197112
dd -0.922587, -1.604054, 1.378264
dd -1.098502, -1.564797, 1.438492
dd -1.297418, -1.479017, 1.285734
dd -1.456863, -1.386788, 1.041808
dd -1.570951, -1.309834, 0.819532
dd -1.663589, -1.246486, 0.652715
dd -1.763125, -1.183860, 0.533918
dd -1.879235, -1.101717, 0.420767
dd -1.997496, -0.983283, 0.275355
dd -2.064736, -0.833917, 0.082136
dd -2.026092, -0.703019, -0.114271
dd -1.927763, -0.626229, -0.250965
dd -1.823314, -0.594374, -0.324184
dd -1.730711, -0.589610, -0.352819
dd -1.642286, -0.602124, -0.350521
dd -1.524886, -0.630125, -0.324651
dd -1.344153, -0.672246, -0.281187
dd -1.121456, -0.857687, -0.276815
dd -0.859655, -0.886642, -0.272223
dd -0.677667, -0.888871, -0.290330
dd -0.568233, -0.887180, -0.306235
dd -0.496071, -0.898163, -0.305379
dd -0.430945, -0.936912, -0.274655
dd -0.367750, -1.017828, -0.196985
dd -0.322799, -1.156079, -0.049661
dd -0.333941, -1.341457, 0.166671
dd -0.420751, -1.508589, 0.384366
dd -0.530309, -1.616101, 0.546918
dd -0.623912, -1.679127, 0.665446
dd -0.694406, -1.726213, 0.776967
dd -0.751065, -1.780060, 0.920119
dd -0.822230, -1.838131, 1.095476
dd -0.939899, -1.877155, 1.261913
dd -1.121374, -1.851256, 1.314196
dd -1.324631, -1.738672, 1.167900
dd -1.486403, -1.602127, 0.937646
dd -1.601552, -1.484971, 0.728399
dd -1.694875, -1.392513, 0.571028
dd -1.795493, -1.311626, 0.457709
dd -1.914005, -1.216395, 0.347603
dd -2.037185, -1.085884, 0.203796
dd -2.112478, -0.923279, 0.011449
dd -2.082788, -0.779694, -0.184044
dd -1.990810, -0.695357, -0.319286
dd -1.889377, -0.661967, -0.390102
dd -1.796891, -0.661375, -0.414684
dd -1.705570, -0.684647, -0.405663
dd -1.581204, -0.730101, -0.371148
dd -1.387941, -0.794479, -0.320050
dd -1.151825, -0.991580, -0.304125
dd -0.877876, -1.024250, -0.312325
dd -0.688367, -1.018712, -0.346881
dd -0.575122, -1.006658, -0.376258
dd -0.501025, -1.009263, -0.384167
dd -0.434547, -1.043204, -0.357667
dd -0.370384, -1.122351, -0.281215
dd -0.325265, -1.262107, -0.133185
dd -0.337769, -1.452629, 0.084361
dd -0.427501, -1.627313, 0.301739
dd -0.540282, -1.744204, 0.461597
dd -0.636768, -1.819486, 0.574903
dd -0.709982, -1.884691, 0.677745
dd -0.769755, -1.967278, 0.806708
dd -0.844822, -2.063596, 0.962727
dd -0.966999, -2.141299, 1.108697
dd -1.152146, -2.131082, 1.150580
dd -1.356197, -1.990929, 1.014570
dd -1.516716, -1.807682, 0.804681
dd -1.630161, -1.648119, 0.614669
dd -1.722179, -1.525363, 0.471347
dd -1.822350, -1.426404, 0.366608
dd -1.941915, -1.319399, 0.262346
dd -2.068876, -1.178817, 0.123790
dd -2.151681, -1.004617, -0.062517
dd -2.131366, -0.848331, -0.251404
dd -2.046686, -0.755437, -0.380872
dd -1.949285, -0.719498, -0.446609
dd -1.857870, -0.722577, -0.465595
dd -1.764684, -0.756875, -0.448945
dd -1.634928, -0.820690, -0.405333
dd -1.431800, -0.908599, -0.346722
dd -1.063770, -1.079451, -0.400046
dd -0.743738, -1.124029, -0.412417
dd -0.525938, -1.127236, -0.446912
dd -0.401466, -1.120043, -0.474380
dd -0.328608, -1.124506, -0.480054
dd -0.274493, -1.157950, -0.451523
dd -0.235759, -1.234604, -0.373019
dd -0.231287, -1.370159, -0.222891
dd -0.293236, -1.556116, -0.003756
dd -0.421018, -1.728630, 0.213741
dd -0.552803, -1.846989, 0.371925
dd -0.656076, -1.927122, 0.481877
dd -0.731463, -2.001027, 0.579250
dd -0.793504, -2.097935, 0.699454
dd -0.871589, -2.213614, 0.843763
dd -0.996837, -2.311375, 0.977758
dd -1.183278, -2.310319, 1.014466
dd -1.385241, -2.157957, 0.886326
dd -1.542149, -1.952621, 0.690211
dd -1.652282, -1.772686, 0.512798
dd -1.741900, -1.635323, 0.378485
dd -1.840674, -1.527727, 0.279084
dd -1.959911, -1.415151, 0.178312
dd -2.088168, -1.269710, 0.042883
dd -2.174525, -1.089601, -0.139551
dd -2.158977, -0.926416, -0.323980
dd -2.077296, -0.828071, -0.450296
dd -1.979703, -0.788881, -0.514900
dd -1.884160, -0.790555, -0.534842
dd -1.780856, -0.825121, -0.521620
dd -1.630926, -0.891548, -0.484129
dd -1.392683, -0.985789, -0.434078
dd -0.874374, -1.136932, -0.564230
dd -0.481153, -1.199825, -0.571561
dd -0.218460, -1.226920, -0.589493
dd -0.076985, -1.238928, -0.599886
dd -0.008350, -1.254895, -0.592497
dd 0.021502, -1.291666, -0.555671
dd 0.012116, -1.364629, -0.471664
dd -0.058978, -1.489851, -0.317734
dd -0.211331, -1.661338, -0.096315
dd -0.406863, -1.822106, 0.121900
dd -0.570719, -1.934125, 0.279559
dd -0.683622, -2.011424, 0.388319
dd -0.760090, -2.083675, 0.484076
dd -0.822746, -2.178557, 0.602156
dd -0.901781, -2.291936, 0.744102
dd -1.027252, -2.388175, 0.876453
dd -1.211559, -2.388375, 0.914122
dd -1.408574, -2.240940, 0.790448
dd -1.560156, -2.041337, 0.599617
dd -1.666022, -1.865970, 0.426408
dd -1.752479, -1.731637, 0.294819
dd -1.848768, -1.625755, 0.196816
dd -1.965760, -1.514190, 0.096710
dd -2.092055, -1.369505, -0.038279
dd -2.177390, -1.190262, -0.219958
dd -2.162069, -1.027938, -0.403373
dd -2.079735, -0.929166, -0.530225
dd -1.978692, -0.887390, -0.598228
dd -1.875089, -0.883375, -0.625797
dd -1.755309, -0.907733, -0.626688
dd -1.573646, -0.960794, -0.609690
dd -1.280373, -1.043279, -0.583026
dd -0.718162, -1.205705, -0.711900
dd -0.267991, -1.283564, -0.714614
dd 0.029200, -1.331293, -0.717500
dd 0.182892, -1.360081, -0.712544
dd 0.246398, -1.385927, -0.693722
dd 0.254135, -1.424904, -0.650286
dd 0.202276, -1.493121, -0.563097
dd 0.065618, -1.606653, -0.408904
dd -0.163813, -1.761848, -0.189931
dd -0.415462, -1.908954, 0.024513
dd -0.604445, -2.013091, 0.178523
dd -0.723604, -2.086315, 0.284030
dd -0.799486, -2.155642, 0.376419
dd -0.861423, -2.246812, 0.490233
dd -0.939705, -2.355861, 0.627218
dd -1.062840, -2.448807, 0.755438
dd -1.241533, -2.450116, 0.793198
dd -1.430181, -2.310028, 0.675981
dd -1.573982, -2.119538, 0.493688
dd -1.673925, -1.951762, 0.327705
dd -1.755834, -1.822830, 0.201188
dd -1.847975, -1.720605, 0.106403
dd -1.960614, -1.612190, 0.008910
dd -2.082619, -1.471097, -0.122962
dd -2.165325, -1.296241, -0.300304
dd -2.150515, -1.137959, -0.479116
dd -2.069264, -1.040803, -0.603879
dd -1.967203, -0.997577, -0.673525
dd -1.858546, -0.988599, -0.707299
dd -1.726577, -1.003414, -0.720684
dd -1.520448, -1.043554, -0.722199
dd -1.184308, -1.113950, -0.716808
dd -0.603649, -1.284967, -0.836698
dd -0.116344, -1.373611, -0.835407
dd 0.202721, -1.437721, -0.825390
dd 0.362930, -1.480086, -0.807475
dd 0.420451, -1.513698, -0.779383
dd 0.409138, -1.553567, -0.731412
dd 0.322382, -1.616007, -0.643722
dd 0.133293, -1.716692, -0.493217
dd -0.156032, -1.854060, -0.281885
dd -0.449143, -1.985787, -0.076095
dd -0.654755, -2.080560, 0.070896
dd -0.776226, -2.148454, 0.170954
dd -0.849683, -2.213527, 0.258128
dd -0.909436, -2.299221, 0.365416
dd -0.985089, -2.401811, 0.494697
dd -1.103108, -2.489592, 0.616142
dd -1.272482, -2.491815, 0.653022
dd -1.449211, -2.361543, 0.544284
dd -1.582729, -2.183656, 0.373896
dd -1.675088, -2.026608, 0.218283
dd -1.751042, -1.905551, 0.099300
dd -1.837309, -1.809037, 0.009664
dd -1.943378, -1.706058, -0.083129
dd -2.058631, -1.571607, -0.208997
dd -2.136997, -1.404927, -0.378143
dd -2.122998, -1.254107, -0.548494
dd -2.044732, -1.160793, -0.668312
dd -1.944391, -1.117427, -0.737590
dd -1.834183, -1.104446, -0.775799
dd -1.695169, -1.110750, -0.799496
dd -1.473410, -1.138855, -0.816757
dd -1.109249, -1.197157, -0.829639
dd -0.537912, -1.373160, -0.932826
dd -0.036118, -1.467720, -0.928317
dd 0.290448, -1.543091, -0.908124
dd 0.450788, -1.595137, -0.880240
dd 0.501582, -1.633984, -0.845511
dd 0.475130, -1.673292, -0.795399
dd 0.362776, -1.729017, -0.710131
dd 0.137121, -1.815995, -0.567486
dd -0.191607, -1.934420, -0.369194
dd -0.508997, -2.049379, -0.177091
dd -0.721504, -2.133475, -0.040557
dd -0.840935, -2.194838, 0.051836
dd -0.910047, -2.254349, 0.131952
dd -0.966093, -2.332818, 0.230466
dd -1.037165, -2.426842, 0.349303
dd -1.147212, -2.507586, 0.461315
dd -1.303533, -2.510478, 0.496288
dd -1.464857, -2.392402, 0.397960
dd -1.585697, -2.230515, 0.242761
dd -1.668902, -2.087266, 0.100611
dd -1.737557, -1.976526, -0.008399
dd -1.816259, -1.887776, -0.090952
dd -1.913559, -1.792544, -0.176923
dd -2.019595, -1.667839, -0.293844
dd -2.091900, -1.513194, -0.450858
dd -2.079014, -1.373315, -0.608825
dd -2.005702, -1.286141, -0.720751
dd -1.910001, -1.244061, -0.787494
dd -1.802087, -1.228241, -0.828077
dd -1.661828, -1.227414, -0.859402
dd -1.434507, -1.244817, -0.888920
dd -1.059300, -1.291397, -0.916257
dd -0.525656, -1.468026, -0.995731
dd -0.033702, -1.563183, -0.988934
dd 0.284976, -1.644066, -0.961755
dd 0.438710, -1.701385, -0.927367
dd 0.482204, -1.742635, -0.888984
dd 0.445209, -1.779868, -0.839320
dd 0.317858, -1.828092, -0.759483
dd 0.073507, -1.900887, -0.628852
dd -0.271790, -1.999784, -0.448889
dd -0.594586, -2.097032, -0.275352
dd -0.803509, -2.169393, -0.152575
dd -0.916375, -2.223164, -0.069945
dd -0.979254, -2.275906, 0.001389
dd -1.030103, -2.345536, 0.089031
dd -1.094677, -2.429034, 0.194862
dd -1.193986, -2.500985, 0.294929
dd -1.333726, -2.504274, 0.326973
dd -1.476449, -2.400519, 0.240768
dd -1.582479, -2.257714, 0.103747
dd -1.655160, -2.131076, -0.022097
dd -1.715328, -2.032906, -0.118874
dd -1.784917, -1.953842, -0.192524
dd -1.871398, -1.868555, -0.269651
dd -1.965908, -1.756565, -0.374795
dd -2.030524, -1.617649, -0.515908
dd -2.019032, -1.492039, -0.657737
dd -1.952601, -1.413235, -0.758909
dd -1.864473, -1.373905, -0.820909
dd -1.762838, -1.356563, -0.861622
dd -1.627488, -1.350284, -0.897506
dd -1.405396, -1.358725, -0.935220
dd -1.037383, -1.394336, -0.972537
dd -0.568506, -1.566776, -1.022685
dd -0.110983, -1.657068, -1.014624
dd 0.184305, -1.737409, -0.983942
dd 0.324744, -1.795325, -0.946797
dd 0.360577, -1.836007, -0.907925
dd 0.318071, -1.869677, -0.861346
dd 0.187036, -1.909835, -0.789849
dd -0.057146, -1.968397, -0.675111
dd -0.395131, -2.047771, -0.518317
dd -0.703853, -2.126893, -0.367765
dd -0.898581, -2.186803, -0.261694
dd -1.000455, -2.232133, -0.190670
dd -1.055360, -2.277082, -0.129609
dd -1.099650, -2.336490, -0.054648
dd -1.155966, -2.407787, 0.035957
dd -1.242041, -2.469423, 0.121882
dd -1.362103, -2.472813, 0.150039
dd -1.483531, -2.385113, 0.077334
dd -1.573029, -2.263951, -0.039013
dd -1.634112, -2.156284, -0.146149
dd -1.684839, -2.072600, -0.228761
dd -1.744013, -2.004889, -0.291921
dd -1.817917, -1.931487, -0.358407
dd -1.898894, -1.834856, -0.449247
dd -1.954396, -1.714960, -0.571093
dd -1.944544, -1.606582, -0.693447
dd -1.886748, -1.538172, -0.781270
dd -1.808959, -1.503004, -0.836416
dd -1.717487, -1.485534, -0.874958
dd -1.593190, -1.475690, -0.912118
dd -1.387207, -1.477226, -0.953619
dd -1.044830, -1.502980, -0.996026
dd -0.664726, -1.666353, -1.013139
dd -0.264981, -1.746509, -1.004868
dd -0.007751, -1.820318, -0.974244
dd 0.113165, -1.874173, -0.938145
dd 0.141213, -1.911354, -0.901941
dd 0.098357, -1.940097, -0.860968
dd -0.025022, -1.971872, -0.800444
dd -0.250319, -2.016588, -0.704960
dd -0.557519, -2.077044, -0.575431
dd -0.833266, -2.138185, -0.451541
dd -1.003705, -2.185316, -0.364592
dd -1.090531, -2.221619, -0.306648
dd -1.135981, -2.257996, -0.257025
dd -1.172559, -2.306127, -0.196152
dd -1.219125, -2.363933, -0.122507
dd -1.289895, -2.414059, -0.052472
dd -1.387808, -2.417254, -0.029031
dd -1.485922, -2.346836, -0.087284
dd -1.557687, -2.249198, -0.181114
dd -1.606459, -2.162262, -0.267734
dd -1.647088, -2.094521, -0.334694
dd -1.694877, -2.039468, -0.386113
dd -1.754842, -1.979511, -0.440502
dd -1.820710, -1.900391, -0.514969
dd -1.865961, -1.802200, -0.614799
dd -1.857944, -1.713467, -0.714961
dd -1.810259, -1.657138, -0.787269
dd -1.745239, -1.627407, -0.833676
dd -1.667470, -1.611195, -0.867829
dd -1.559986, -1.599767, -0.902971
dd -1.380413, -1.596654, -0.943767
dd -1.081188, -1.613957, -0.986254
dd -0.809435, -1.763742, -0.968745
dd -0.488209, -1.828994, -0.961285
dd -0.282014, -1.890700, -0.934147
dd -0.186035, -1.936132, -0.902724
dd -0.165656, -1.967093, -0.872146
dd -0.203882, -1.989744, -0.839038
dd -0.308919, -2.013083, -0.791689
dd -0.497884, -2.044741, -0.718118
dd -0.752626, -2.087427, -0.618978
dd -0.978195, -2.131263, -0.524493
dd -1.115355, -2.165682, -0.458419
dd -1.183680, -2.192666, -0.414580
dd -1.218531, -2.219978, -0.377175
dd -1.246520, -2.256154, -0.331321
dd -1.282191, -2.299631, -0.275800
dd -1.336121, -2.337442, -0.222860
dd -1.410172, -2.340164, -0.204792
dd -1.483724, -2.287691, -0.248111
dd -1.537132, -2.214681, -0.318326
dd -1.573278, -2.149549, -0.383300
dd -1.603480, -2.098677, -0.433649
dd -1.639289, -2.057160, -0.472473
dd -1.684423, -2.011747, -0.513726
dd -1.734116, -1.951686, -0.570317
dd -1.768331, -1.877131, -0.646146
dd -1.762279, -1.809776, -0.722167
dd -1.725825, -1.766793, -0.777339
dd -1.675528, -1.743562, -0.813454
dd -1.614461, -1.729907, -0.841216
dd -1.528828, -1.718850, -0.871227
dd -1.384793, -1.713395, -0.907016
dd -1.144287, -1.723855, -0.944760
dd -0.995267, -1.856261, -0.893067
dd -0.769669, -1.902582, -0.887348
dd -0.625158, -1.947329, -0.866800
dd -0.558450, -1.980506, -0.843308
dd -0.545410, -2.002889, -0.820958
dd -0.574489, -2.018534, -0.797598
dd -0.651728, -2.033631, -0.765103
dd -0.789104, -2.053346, -0.715295
dd -0.972656, -2.079853, -0.648583
dd -1.133420, -2.107519, -0.585213
dd -1.229865, -2.129656, -0.541045
dd -1.276998, -2.147317, -0.511862
dd -1.300489, -2.165369, -0.487047
dd -1.319319, -2.189301, -0.456648
dd -1.343340, -2.218084, -0.419810
dd -1.379484, -2.243183, -0.384598
dd -1.428762, -2.245186, -0.372361
dd -1.477303, -2.210757, -0.400726
dd -1.512300, -2.162693, -0.446984
dd -1.535891, -2.119736, -0.489888
dd -1.555661, -2.086107, -0.523211
dd -1.579282, -2.058553, -0.549006
dd -1.609181, -2.028290, -0.576533
dd -1.642174, -1.988182, -0.614364
dd -1.664937, -1.938384, -0.665030
dd -1.660918, -1.893406, -0.715788
dd -1.636415, -1.864564, -0.752808
dd -1.602241, -1.848636, -0.777479
dd -1.560193, -1.838676, -0.797163
dd -1.500489, -1.829808, -0.819284
dd -1.399488, -1.824237, -0.846190
dd -1.230547, -1.829554, -0.874820
dd -1.213318, -1.941772, -0.791048
dd -1.096242, -1.966029, -0.787868
dd -1.021379, -1.989874, -0.776546
dd -0.987069, -2.007652, -0.763727
dd -0.980864, -2.019550, -0.751742
dd -0.996940, -2.027552, -0.739572
dd -1.038557, -2.034817, -0.723044
dd -1.111910, -2.043936, -0.698016
dd -1.209216, -2.056158, -0.664682
dd -1.293682, -2.069138, -0.633115
dd -1.343785, -2.079728, -0.611181
dd -1.367868, -2.088324, -0.596744
dd -1.379624, -2.097193, -0.584509
dd -1.389032, -2.108962, -0.569530
dd -1.401043, -2.123125, -0.551364
dd -1.419035, -2.135508, -0.533959
dd -1.443404, -2.136588, -0.527809
dd -1.467219, -2.119791, -0.541621
dd -1.484272, -2.096265, -0.564278
dd -1.495722, -2.075202, -0.585338
dd -1.505345, -2.058676, -0.601732
dd -1.516929, -2.045085, -0.614470
dd -1.531651, -2.030100, -0.628117
dd -1.547931, -2.010201, -0.646904
dd -1.559186, -1.985489, -0.672056
dd -1.557202, -1.963175, -0.697235
dd -1.544971, -1.948801, -0.715683
dd -1.527743, -1.940706, -0.728181
dd -1.506294, -1.935374, -0.738478
dd -1.475503, -1.930285, -0.750419
dd -1.423156, -1.926625, -0.765164
dd -1.335468, -1.928489, -0.780959
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd -1.454153, -2.018794, -0.668374
dd 0.671861, -0.050925, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671862, -0.050925, -0.255719
dd 0.671861, -0.050926, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671861, -0.050926, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.671861, -0.050925, -0.255719
dd 0.606030, 0.021506, -0.102472
dd 0.568528, -0.000383, -0.054937
dd 0.539316, -0.017436, -0.023884
dd 0.523148, -0.030222, -0.009766
dd 0.518801, -0.042226, -0.008257
dd 0.525982, -0.057870, -0.018047
dd 0.545962, -0.080560, -0.042645
dd 0.580731, -0.111687, -0.087620
dd 0.625254, -0.145529, -0.150770
dd 0.661607, -0.167743, -0.210368
dd 0.681455, -0.175379, -0.249834
dd 0.689893, -0.174750, -0.272394
dd 0.693530, -0.171157, -0.286781
dd 0.696762, -0.166544, -0.300464
dd 0.700806, -0.157899, -0.317216
dd 0.705737, -0.140339, -0.338178
dd 0.710386, -0.110862, -0.359565
dd 0.712568, -0.076552, -0.372454
dd 0.712414, -0.048939, -0.375752
dd 0.711198, -0.029715, -0.373942
dd 0.709703, -0.015282, -0.370428
dd 0.707981, -0.001093, -0.366103
dd 0.704971, 0.016207, -0.357911
dd 0.699176, 0.037772, -0.341145
dd 0.689784, 0.059672, -0.312860
dd 0.679174, 0.072728, -0.279813
dd 0.670980, 0.075845, -0.253130
dd 0.665707, 0.073626, -0.234479
dd 0.662337, 0.069505, -0.220402
dd 0.659221, 0.064447, -0.205966
dd 0.652425, 0.056342, -0.184826
dd 0.636233, 0.042305, -0.150629
dd 0.560054, 0.083174, 0.055078
dd 0.484204, 0.034829, 0.146139
dd 0.423161, -0.001756, 0.204488
dd 0.388455, -0.028125, 0.230206
dd 0.378586, -0.051882, 0.232010
dd 0.393421, -0.082112, 0.212465
dd 0.435286, -0.125456, 0.164470
dd 0.507728, -0.184493, 0.076904
dd 0.599407, -0.248243, -0.046318
dd 0.672703, -0.289587, -0.163127
dd 0.711477, -0.303281, -0.240903
dd 0.727072, -0.301447, -0.285704
dd 0.733316, -0.294101, -0.314550
dd 0.739217, -0.284754, -0.342153
dd 0.747072, -0.267225, -0.376047
dd 0.756926, -0.231621, -0.418521
dd 0.766328, -0.171847, -0.461884
dd 0.770753, -0.102272, -0.488021
dd 0.770440, -0.046280, -0.494709
dd 0.767974, -0.007298, -0.491038
dd 0.764944, 0.021970, -0.483912
dd 0.761411, 0.050744, -0.475143
dd 0.754999, 0.085843, -0.458525
dd 0.742277, 0.129624, -0.424510
dd 0.721237, 0.174140, -0.367120
dd 0.697156, 0.200729, -0.300056
dd 0.678655, 0.206994, -0.245868
dd 0.667255, 0.202163, -0.207921
dd 0.660980, 0.193075, -0.179169
dd 0.656707, 0.181414, -0.149627
dd 0.646377, 0.162516, -0.106890
dd 0.617886, 0.130188, -0.038939
dd 0.537841, 0.130861, 0.212761
dd 0.423835, 0.051704, 0.341520
dd 0.328965, -0.006622, 0.422113
dd 0.273603, -0.047068, 0.456244
dd 0.257054, -0.081943, 0.456968
dd 0.279848, -0.125128, 0.428000
dd 0.345086, -0.186211, 0.358664
dd 0.457347, -0.268693, 0.232469
dd 0.597739, -0.357020, 0.054445
dd 0.707538, -0.413446, -0.115170
dd 0.763629, -0.431239, -0.228807
dd 0.784720, -0.427587, -0.294821
dd 0.792333, -0.416418, -0.337776
dd 0.800190, -0.402342, -0.379148
dd 0.811478, -0.375930, -0.430110
dd 0.826098, -0.322272, -0.494072
dd 0.840231, -0.232186, -0.559417
dd 0.846899, -0.127328, -0.598809
dd 0.846428, -0.042941, -0.608889
dd 0.842712, 0.015811, -0.603355
dd 0.838144, 0.059921, -0.592616
dd 0.832758, 0.103291, -0.579398
dd 0.822602, 0.156215, -0.554345
dd 0.801883, 0.222282, -0.503054
dd 0.767002, 0.289544, -0.416506
dd 0.726626, 0.329796, -0.315352
dd 0.695748, 0.339152, -0.233556
dd 0.677441, 0.331341, -0.176164
dd 0.668872, 0.316483, -0.132501
dd 0.665681, 0.296676, -0.087551
dd 0.655604, 0.264276, -0.023348
dd 0.619572, 0.209410, 0.076845
dd 0.542438, 0.161713, 0.365756
dd 0.391659, 0.047899, 0.524651
dd 0.261802, -0.033932, 0.621251
dd 0.184090, -0.088563, 0.660034
dd 0.159790, -0.133519, 0.658197
dd 0.190633, -0.187468, 0.620460
dd 0.280166, -0.262541, 0.532698
dd 0.433386, -0.362844, 0.373416
dd 0.622709, -0.469131, 0.148062
dd 0.767408, -0.535727, -0.067895
dd 0.838516, -0.555337, -0.213602
dd 0.863111, -0.549249, -0.299050
dd 0.870690, -0.534298, -0.355294
dd 0.879655, -0.515644, -0.409847
dd 0.893858, -0.480619, -0.477271
dd 0.912925, -0.409453, -0.562038
dd 0.931618, -0.289966, -0.648698
dd 0.940463, -0.150885, -0.700946
dd 0.939838, -0.038956, -0.714315
dd 0.934909, 0.038969, -0.706976
dd 0.928850, 0.097476, -0.692732
dd 0.921619, 0.155005, -0.675198
dd 0.907459, 0.225239, -0.641958
dd 0.877812, 0.312985, -0.573890
dd 0.827101, 0.402439, -0.459021
dd 0.767827, 0.456080, -0.324738
dd 0.722671, 0.468366, -0.216068
dd 0.696812, 0.457266, -0.139663
dd 0.686690, 0.435933, -0.081286
dd 0.687014, 0.406530, -0.021069
dd 0.681344, 0.358064, 0.063797
dd 0.643233, 0.276679, 0.193584
dd 0.575574, 0.173596, 0.508986
dd 0.390642, 0.022086, 0.688993
dd 0.225644, -0.084405, 0.794428
dd 0.124463, -0.152899, 0.833694
dd 0.091509, -0.206511, 0.827792
dd 0.130249, -0.268547, 0.782258
dd 0.244309, -0.353167, 0.679759
dd 0.438434, -0.464718, 0.494346
dd 0.675403, -0.581329, 0.231128
dd 0.852203, -0.652520, -0.022817
dd 0.935403, -0.671452, -0.195541
dd 0.961259, -0.662342, -0.297916
dd 0.967304, -0.643771, -0.366161
dd 0.976439, -0.620842, -0.432858
dd 0.992910, -0.577762, -0.515586
dd 1.015945, -0.490213, -0.619778
dd 1.038873, -0.343214, -0.726377
dd 1.049755, -0.172108, -0.790657
dd 1.048986, -0.034405, -0.807104
dd 1.042922, 0.061464, -0.798075
dd 1.035468, 0.133442, -0.780551
dd 1.026458, 0.204224, -0.758978
dd 1.008140, 0.290679, -0.718068
dd 0.968846, 0.398781, -0.634279
dd 0.900671, 0.509145, -0.492863
dd 0.820297, 0.575465, -0.327512
dd 0.759277, 0.590422, -0.193586
dd 0.725409, 0.575801, -0.099219
dd 0.714577, 0.547437, -0.026798
dd 0.720907, 0.507187, 0.048062
dd 0.723951, 0.440411, 0.152092
dd 0.689671, 0.329072, 0.307718
dd 0.637329, 0.165403, 0.637613
dd 0.422029, -0.025786, 0.828697
dd 0.222825, -0.157372, 0.935243
dd 0.097741, -0.238962, 0.970647
dd 0.055465, -0.299482, 0.959244
dd 0.101696, -0.366570, 0.907165
dd 0.239761, -0.455824, 0.794222
dd 0.473464, -0.571442, 0.590718
dd 0.755259, -0.690124, 0.300647
dd 0.960253, -0.759980, 0.018574
dd 1.052129, -0.775659, -0.175076
dd 1.076880, -0.763013, -0.291246
dd 1.079879, -0.741102, -0.369781
dd 1.088203, -0.714345, -0.447165
dd 1.106199, -0.664042, -0.543518
dd 1.132581, -0.561790, -0.665098
dd 1.159276, -0.390096, -0.789587
dd 1.171986, -0.190244, -0.864665
dd 1.171088, -0.029407, -0.883876
dd 1.164005, 0.082567, -0.873330
dd 1.155298, 0.166638, -0.852862
dd 1.144634, 0.249319, -0.827663
dd 1.122128, 0.350357, -0.779861
dd 1.072741, 0.476809, -0.681937
dd 0.985945, 0.606099, -0.516641
dd 0.882842, 0.683966, -0.323328
dd 0.804801, 0.701240, -0.166615
dd 0.762700, 0.682969, -0.055939
dd 0.752055, 0.647216, 0.029394
dd 0.766793, 0.595157, 0.117795
dd 0.782755, 0.508310, 0.238834
dd 0.758325, 0.364380, 0.415595
dd 0.726016, 0.137231, 0.747552
dd 0.485102, -0.094409, 0.939259
dd 0.253688, -0.250753, 1.039099
dd 0.105005, -0.344262, 1.066380
dd 0.053018, -0.409714, 1.048198
dd 0.106103, -0.478641, 0.991037
dd 0.266904, -0.567432, 0.872299
dd 0.537624, -0.679760, 0.659365
dd 0.860021, -0.792131, 0.354368
dd 1.088402, -0.854712, 0.054973
dd 1.185243, -0.864649, -0.152821
dd 1.206535, -0.848056, -0.279204
dd 1.205061, -0.823192, -0.365986
dd 1.211609, -0.793177, -0.452259
dd 1.230336, -0.736709, -0.560123
dd 1.259337, -0.621901, -0.696503
dd 1.289209, -0.429115, -0.836263
dd 1.303480, -0.204710, -0.920565
dd 1.302472, -0.024114, -0.942136
dd 1.294519, 0.101618, -0.930295
dd 1.284743, 0.196016, -0.907312
dd 1.272600, 0.288865, -0.879014
dd 1.246004, 0.402388, -0.825317
dd 1.186385, 0.544598, -0.715292
dd 1.080381, 0.690233, -0.529545
dd 0.953609, 0.778149, -0.312262
dd 0.857908, 0.797312, -0.135953
dd 0.807601, 0.775372, -0.011137
dd 0.798041, 0.732098, 0.085569
dd 0.823348, 0.667624, 0.185979
dd 0.856066, 0.559550, 0.321330
dd 0.847247, 0.381380, 0.513833
dd 0.838332, 0.090390, 0.835892
dd 0.577224, -0.181230, 1.017987
dd 0.316531, -0.361249, 1.103685
dd 0.145260, -0.465167, 1.118925
dd 0.083480, -0.533469, 1.092921
dd 0.142585, -0.601041, 1.032266
dd 0.324193, -0.684403, 0.912449
dd 0.628305, -0.786348, 0.698835
dd 0.985943, -0.884408, 0.391019
dd 1.232303, -0.934134, 0.085387
dd 1.330332, -0.936067, -0.129492
dd 1.345973, -0.915248, -0.262277
dd 1.338764, -0.887896, -0.355059
dd 1.342650, -0.855279, -0.448195
dd 1.361308, -0.793869, -0.565155
dd 1.392135, -0.668984, -0.713355
dd 1.424514, -0.459266, -0.865365
dd 1.440038, -0.215150, -0.957072
dd 1.438941, -0.018691, -0.980537
dd 1.430290, 0.118083, -0.967656
dd 1.419655, 0.220774, -0.942654
dd 1.406250, 0.321788, -0.911868
dd 1.375786, 0.445365, -0.853429
dd 1.306110, 0.600326, -0.733658
dd 1.180903, 0.759285, -0.531429
dd 1.030264, 0.855483, -0.294808
dd 0.916813, 0.876058, -0.102615
dd 0.858577, 0.850543, 0.033792
dd 0.850946, 0.799846, 0.140023
dd 0.888614, 0.722743, 0.250581
dd 0.941329, 0.592959, 0.397175
dd 0.953279, 0.379974, 0.599673
dd 0.969741, 0.027226, 0.901141
dd 0.694177, -0.282746, 1.064204
dd 0.407846, -0.484717, 1.129122
dd 0.215614, -0.597300, 1.128963
dd 0.144251, -0.666397, 1.094380
dd 0.208409, -0.729622, 1.031835
dd 0.408381, -0.803008, 0.915447
dd 0.741460, -0.888149, 0.709471
dd 1.128216, -0.964734, 0.410402
dd 1.386895, -0.996692, 0.109229
dd 1.482496, -0.988713, -0.105832
dd 1.490572, -0.963526, -0.241218
dd 1.476603, -0.934204, -0.337691
dd 1.477063, -0.899682, -0.435566
dd 1.494897, -0.834635, -0.559064
dd 1.526745, -0.702323, -0.715909
dd 1.560918, -0.480118, -0.876942
dd 1.577367, -0.221465, -0.974110
dd 1.576205, -0.013307, -0.998972
dd 1.567038, 0.131612, -0.985325
dd 1.555770, 0.240418, -0.958834
dd 1.541347, 0.347459, -0.926210
dd 1.507337, 0.478488, -0.864262
dd 1.428068, 0.642970, -0.737267
dd 1.284232, 0.811996, -0.522808
dd 1.110239, 0.914554, -0.271809
dd 0.979478, 0.936049, -0.067723
dd 0.913808, 0.907153, 0.077517
dd 0.908852, 0.849347, 0.191237
dd 0.960213, 0.759783, 0.309880
dd 1.035410, 0.608468, 0.464474
dd 1.072406, 0.361153, 0.671220
dd 1.115008, -0.049183, 0.943250
dd 0.830688, -0.394916, 1.079137
dd 0.522805, -0.616624, 1.117753
dd 0.311707, -0.736022, 1.099536
dd 0.231228, -0.803995, 1.055919
dd 0.299403, -0.860240, 0.993019
dd 0.514965, -0.919741, 0.884115
dd 0.872109, -0.982641, 0.693226
dd 1.281509, -1.031759, 0.413315
dd 1.546940, -1.041926, 0.126335
dd 1.636849, -1.022558, -0.082541
dd 1.635812, -0.992998, -0.216948
dd 1.614329, -0.962236, -0.314882
dd 1.610757, -0.926508, -0.415403
dd 1.627094, -0.859132, -0.542894
dd 1.659191, -0.722044, -0.705212
dd 1.694453, -0.491804, -0.872036
dd 1.711497, -0.223797, -0.972718
dd 1.710293, -0.008112, -0.998480
dd 1.700795, 0.142049, -0.984339
dd 1.689119, 0.254789, -0.956890
dd 1.673932, 0.365715, -0.923082
dd 1.636774, 0.501585, -0.858861
dd 1.548611, 0.672341, -0.727172
dd 1.387205, 0.848145, -0.504749
dd 1.190998, 0.955111, -0.244355
dd 1.043825, 0.977046, -0.032392
dd 0.971390, 0.945043, 0.118887
dd 0.969718, 0.880618, 0.238006
dd 1.035612, 0.779106, 0.362603
dd 1.134940, 0.607040, 0.521980
dd 1.200212, 0.326816, 0.727556
dd 1.268759, -0.135405, 0.963435
dd 0.981038, -0.513597, 1.065575
dd 0.655862, -0.752516, 1.073645
dd 0.428293, -0.876881, 1.035477
dd 0.339364, -0.942037, 0.982664
dd 0.410519, -0.989129, 0.920796
dd 0.638753, -1.031614, 0.822815
dd 1.014906, -1.067995, 0.653290
dd 1.440521, -1.085016, 0.401362
dd 1.707522, -1.070372, 0.136926
dd 1.788963, -1.038600, -0.060216
dd 1.777671, -1.004780, -0.190458
dd 1.748202, -0.973096, -0.287808
dd 1.740164, -0.936822, -0.389024
dd 1.754440, -0.868352, -0.518115
dd 1.786088, -0.729000, -0.682909
dd 1.821775, -0.494942, -0.852466
dd 1.839101, -0.222490, -0.954818
dd 1.837877, -0.003226, -0.981007
dd 1.828221, 0.149425, -0.966631
dd 1.816352, 0.264036, -0.938727
dd 1.800647, 0.376816, -0.904354
dd 1.760787, 0.515052, -0.839032
dd 1.664600, 0.688993, -0.705048
dd 1.487054, 0.868439, -0.478708
dd 1.270261, 0.977940, -0.213650
dd 1.107929, 0.999871, 0.002371
dd 1.029513, 0.965094, 0.157015
dd 1.031583, 0.894672, 0.279512
dd 1.112368, 0.781993, 0.407984
dd 1.236651, 0.590442, 0.569126
dd 1.332328, 0.279484, 0.768702
dd 1.379731, -0.114682, 0.972078
dd 1.113245, -0.515140, 1.057665
dd 0.809819, -0.766905, 1.051743
dd 0.597667, -0.896636, 1.005182
dd 0.516682, -0.962968, 0.949476
dd 0.588354, -1.008931, 0.890166
dd 0.810312, -1.048178, 0.800407
dd 1.173471, -1.079025, 0.645202
dd 1.582214, -1.089195, 0.411083
dd 1.836199, -1.069305, 0.160301
dd 1.911296, -1.034975, -0.030187
dd 1.897986, -1.000342, -0.158313
dd 1.868261, -0.968554, -0.255393
dd 1.860223, -0.932280, -0.356610
dd 1.874498, -0.863810, -0.485701
dd 1.906147, -0.724459, -0.650496
dd 1.941834, -0.490401, -0.820052
dd 1.959160, -0.217948, -0.922404
dd 1.957936, 0.001315, -0.948593
dd 1.948280, 0.153967, -0.934217
dd 1.936411, 0.268577, -0.906313
dd 1.920702, 0.381663, -0.871968
dd 1.880811, 0.522309, -0.806869
dd 1.784527, 0.703826, -0.673585
dd 1.606781, 0.898816, -0.448680
dd 1.389616, 1.028595, -0.185491
dd 1.226388, 1.066840, 0.029051
dd 1.146221, 1.041454, 0.182893
dd 1.145169, 0.974001, 0.305239
dd 1.220875, 0.857990, 0.433957
dd 1.339816, 0.655955, 0.594177
dd 1.434074, 0.325860, 0.788951
dd 1.455809, 0.010809, 0.974501
dd 1.232011, -0.398389, 1.063210
dd 0.986122, -0.656707, 1.061944
dd 0.818965, -0.791403, 1.019807
dd 0.761129, -0.862724, 0.967943
dd 0.830777, -0.915753, 0.912333
dd 1.028451, -0.966027, 0.826867
dd 1.348561, -1.013150, 0.676790
dd 1.709874, -1.042745, 0.447639
dd 1.938203, -1.037955, 0.199576
dd 2.010031, -1.011298, 0.009664
dd 2.003243, -0.979420, -0.118711
dd 1.981030, -0.948363, -0.215878
dd 1.977458, -0.912636, -0.316400
dd 1.993794, -0.845260, -0.443891
dd 2.025892, -0.708172, -0.606209
dd 2.061154, -0.477931, -0.773033
dd 2.078198, -0.209925, -0.873715
dd 2.076994, 0.005760, -0.899477
dd 2.067496, 0.155921, -0.885335
dd 2.055820, 0.268662, -0.857886
dd 2.040621, 0.380459, -0.824159
dd 2.003376, 0.523197, -0.760573
dd 1.914935, 0.715542, -0.630878
dd 1.752961, 0.935652, -0.412548
dd 1.555693, 1.100413, -0.157480
dd 1.405966, 1.168847, 0.050267
dd 1.328538, 1.163612, 0.199260
dd 1.317971, 1.107649, 0.317951
dd 1.369386, 0.996640, 0.443248
dd 1.453491, 0.794692, 0.599996
dd 1.514716, 0.459924, 0.791888
dd 1.546396, 0.122298, 0.962326
dd 1.364966, -0.286385, 1.052010
dd 1.175054, -0.545297, 1.054900
dd 1.051167, -0.681673, 1.017537
dd 1.015022, -0.755980, 0.970125
dd 1.081469, -0.814201, 0.918920
dd 1.253621, -0.873236, 0.838984
dd 1.529099, -0.933839, 0.696485
dd 1.841063, -0.980058, 0.476366
dd 2.042034, -0.988753, 0.235723
dd 2.109514, -0.969438, 0.050158
dd 2.108646, -0.940645, -0.075845
dd 2.093541, -0.910865, -0.171128
dd 2.094001, -0.876343, -0.269003
dd 2.111835, -0.811297, -0.392501
dd 2.143682, -0.678985, -0.549346
dd 2.177856, -0.456779, -0.710379
dd 2.194305, -0.198127, -0.807546
dd 2.193143, 0.010031, -0.832409
dd 2.183976, 0.154951, -0.818762
dd 2.172708, 0.263756, -0.792270
dd 2.158268, 0.372154, -0.759772
dd 2.124120, 0.513863, -0.698810
dd 2.044420, 0.711926, -0.574918
dd 1.899700, 0.949863, -0.366824
dd 1.724057, 1.142311, -0.124109
dd 1.589324, 1.236130, 0.073419
dd 1.515888, 1.248865, 0.215105
dd 1.497097, 1.204220, 0.328157
dd 1.525939, 1.099888, 0.447890
dd 1.577459, 0.902096, 0.598396
dd 1.608160, 0.569944, 0.783856
dd 1.650395, 0.214809, 0.934262
dd 1.509688, -0.183067, 1.022503
dd 1.372321, -0.435918, 1.028862
dd 1.288467, -0.570267, 0.996515
dd 1.271733, -0.645232, 0.954103
dd 1.333766, -0.706404, 0.907952
dd 1.479789, -0.771411, 0.834760
dd 1.710227, -0.841969, 0.702338
dd 1.972202, -0.901190, 0.495503
dd 2.144751, -0.921162, 0.267291
dd 2.206811, -0.908594, 0.090139
dd 2.211013, -0.883164, -0.030646
dd 2.202351, -0.855227, -0.121904
dd 2.206237, -0.822609, -0.215040
dd 2.224895, -0.761199, -0.332000
dd 2.255721, -0.636315, -0.480200
dd 2.288100, -0.426597, -0.632210
dd 2.303624, -0.182481, -0.723917
dd 2.302528, 0.013978, -0.747382
dd 2.293876, 0.150753, -0.734502
dd 2.283241, 0.253443, -0.709500
dd 2.269814, 0.356192, -0.678873
dd 2.239175, 0.493430, -0.621696
dd 2.168948, 0.691343, -0.505893
dd 2.042610, 0.938442, -0.311806
dd 1.889860, 1.149614, -0.085780
dd 1.771328, 1.262695, 0.098024
dd 1.703159, 1.290429, 0.229885
dd 1.677833, 1.256566, 0.335263
dd 1.686698, 1.160573, 0.447214
dd 1.709129, 0.971342, 0.588580
dd 1.713027, 0.649846, 0.763852
dd 1.765731, 0.283874, 0.889825
dd 1.662709, -0.092363, 0.974043
dd 1.572537, -0.332119, 0.983020
dd 1.523970, -0.460481, 0.955801
dd 1.523573, -0.533563, 0.918827
dd 1.580011, -0.595161, 0.878278
dd 1.700058, -0.662930, 0.812937
dd 1.886401, -0.739311, 0.692990
dd 2.099238, -0.807201, 0.503642
dd 2.243086, -0.835706, 0.292915
dd 2.298733, -0.829037, 0.128329
dd 2.306923, -0.807162, 0.015689
dd 2.303785, -0.781627, -0.069348
dd 2.310333, -0.751612, -0.155621
dd 2.329060, -0.695144, -0.263485
dd 2.358060, -0.580337, -0.399865
dd 2.387933, -0.387550, -0.539625
dd 2.402204, -0.163146, -0.623927
dd 2.401196, 0.017451, -0.645498
dd 2.393243, 0.143182, -0.633657
dd 2.383466, 0.237581, -0.610674
dd 2.371297, 0.332416, -0.582559
dd 2.344502, 0.461584, -0.530308
dd 2.284251, 0.652986, -0.424827
dd 2.176952, 0.899565, -0.248405
dd 2.047763, 1.119159, -0.043256
dd 1.946243, 1.244264, 0.123446
dd 1.884561, 1.283310, 0.243054
dd 1.854734, 1.259314, 0.338785
dd 1.847055, 1.173206, 0.440790
dd 1.845089, 0.997050, 0.570153
dd 1.827048, 0.694606, 0.731476
dd 1.889434, 0.326065, 0.829508
dd 1.819717, -0.017784, 0.907107
dd 1.769632, -0.237435, 0.917724
dd 1.750247, -0.355821, 0.895589
dd 1.762437, -0.424397, 0.864345
dd 1.812209, -0.483748, 0.829803
dd 1.907247, -0.550807, 0.773236
dd 2.051868, -0.628474, 0.667904
dd 2.217992, -0.700194, 0.499934
dd 2.333738, -0.734072, 0.311473
dd 2.382123, -0.732220, 0.163440
dd 2.393040, -0.713997, 0.061780
dd 2.394284, -0.691378, -0.014913
dd 2.402607, -0.664621, -0.092296
dd 2.420603, -0.614318, -0.188650
dd 2.446986, -0.512066, -0.310230
dd 2.473680, -0.340372, -0.434719
dd 2.486390, -0.140521, -0.509797
dd 2.485492, 0.020316, -0.529008
dd 2.478409, 0.132291, -0.518462
dd 2.469702, 0.216361, -0.497994
dd 2.459011, 0.301140, -0.472989
dd 2.436293, 0.418697, -0.426713
dd 2.386240, 0.597082, -0.333585
dd 2.298077, 0.832947, -0.178135
dd 2.192422, 1.049835, 0.002368
dd 2.108238, 1.178961, 0.148938
dd 2.054127, 1.225076, 0.254115
dd 2.022085, 1.209676, 0.338418
dd 2.001997, 1.134777, 0.428503
dd 1.981342, 0.976050, 0.543220
dd 1.947174, 0.700916, 0.687062
dd 2.017857, 0.339448, 0.754813
dd 1.975931, 0.037979, 0.823344
dd 1.957413, -0.155018, 0.834546
dd 1.960059, -0.259657, 0.817292
dd 1.980609, -0.321183, 0.791901
dd 2.022826, -0.375618, 0.763594
dd 2.094620, -0.438437, 0.716473
dd 2.201241, -0.512707, 0.627495
dd 2.324586, -0.583188, 0.484215
dd 2.413717, -0.619039, 0.322226
dd 2.454196, -0.620748, 0.194312
dd 2.466464, -0.606161, 0.106190
dd 2.470784, -0.586895, 0.039754
dd 2.479919, -0.563965, -0.026942
dd 2.496389, -0.520886, -0.109671
dd 2.519424, -0.433337, -0.213863
dd 2.542352, -0.286338, -0.320462
dd 2.553234, -0.115231, -0.384741
dd 2.552465, 0.022471, -0.401189
dd 2.546401, 0.118340, -0.392160
dd 2.538947, 0.190318, -0.374636
dd 2.529910, 0.263161, -0.353253
dd 2.511384, 0.365841, -0.313842
dd 2.471437, 0.524959, -0.234765
dd 2.401918, 0.740010, -0.103019
dd 2.319036, 0.942890, 0.049747
dd 2.251982, 1.067719, 0.173710
dd 2.206317, 1.116345, 0.262676
dd 2.174467, 1.107975, 0.334084
dd 2.146587, 1.045289, 0.410600
dd 2.113662, 0.907906, 0.508420
dd 2.069818, 0.667684, 0.631709
dd 2.147028, 0.323832, 0.668139
dd 2.126569, 0.073362, 0.725448
dd 2.130197, -0.087301, 0.736174
dd 2.147102, -0.174870, 0.723451
dd 2.171559, -0.227038, 0.703854
dd 2.205571, -0.274060, 0.681816
dd 2.256588, -0.329266, 0.644519
dd 2.330066, -0.395596, 0.573116
dd 2.415845, -0.459845, 0.457061
dd 2.480652, -0.494235, 0.324903
dd 2.512829, -0.498151, 0.220031
dd 2.525041, -0.487072, 0.147571
dd 2.531048, -0.471487, 0.092976
dd 2.540013, -0.452833, 0.038423
dd 2.554215, -0.417808, -0.029001
dd 2.573282, -0.346642, -0.113768
dd 2.591975, -0.227156, -0.200428
dd 2.600820, -0.088075, -0.252676
dd 2.600195, 0.023855, -0.266045
dd 2.595266, 0.101780, -0.258706
dd 2.589207, 0.160286, -0.244462
dd 2.581952, 0.219694, -0.227102
dd 2.567602, 0.304714, -0.195227
dd 2.537359, 0.438949, -0.131453
dd 2.485425, 0.623804, -0.025397
dd 2.423865, 0.801891, 0.097417
dd 2.373211, 0.914302, 0.197008
dd 2.336601, 0.960838, 0.268492
dd 2.307326, 0.957725, 0.325946
dd 2.276474, 0.907876, 0.387671
dd 2.238026, 0.795067, 0.466878
dd 2.191199, 0.596233, 0.567197
dd 2.273049, 0.280771, 0.572532
dd 2.267326, 0.088067, 0.616882
dd 2.283368, -0.035761, 0.626123
dd 2.306624, -0.103574, 0.617458
dd 2.330586, -0.144442, 0.603425
dd 2.356013, -0.181872, 0.587501
dd 2.389249, -0.226447, 0.560097
dd 2.435251, -0.280701, 0.506921
dd 2.489609, -0.334098, 0.419713
dd 2.533026, -0.363765, 0.319727
dd 2.556768, -0.368518, 0.240019
dd 2.567570, -0.360718, 0.184797
dd 2.573878, -0.349022, 0.143212
dd 2.581734, -0.334947, 0.101841
dd 2.593022, -0.308535, 0.050879
dd 2.607642, -0.254877, -0.013084
dd 2.621775, -0.164791, -0.078429
dd 2.628443, -0.059933, -0.117821
dd 2.627972, 0.024455, -0.127900
dd 2.624256, 0.083206, -0.122367
dd 2.619688, 0.127316, -0.111628
dd 2.614282, 0.172246, -0.098554
dd 2.603968, 0.237456, -0.074636
dd 2.582754, 0.342151, -0.026913
dd 2.546856, 0.488682, 0.052313
dd 2.504583, 0.632337, 0.143938
dd 2.469135, 0.724886, 0.218190
dd 2.441896, 0.764965, 0.271492
dd 2.417412, 0.765247, 0.314390
dd 2.388318, 0.728450, 0.360592
dd 2.351005, 0.642587, 0.420093
dd 2.307731, 0.490133, 0.495802
dd 2.392468, 0.213307, 0.471349
dd 2.394763, 0.083018, 0.501494
dd 2.413763, -0.000838, 0.508350
dd 2.435793, -0.046958, 0.503183
dd 2.455160, -0.075039, 0.494338
dd 2.471896, -0.101116, 0.484207
dd 2.490664, -0.132546, 0.466473
dd 2.515290, -0.171211, 0.431602
dd 2.544880, -0.209753, 0.373921
dd 2.570270, -0.231786, 0.307360
dd 2.585699, -0.236070, 0.254070
dd 2.593868, -0.231243, 0.217058
dd 2.599169, -0.223516, 0.189201
dd 2.605071, -0.214170, 0.161598
dd 2.612925, -0.196641, 0.127703
dd 2.622779, -0.161036, 0.085229
dd 2.632182, -0.101262, 0.041867
dd 2.636606, -0.031688, 0.015729
dd 2.636293, 0.024305, 0.009041
dd 2.633827, 0.063287, 0.012713
dd 2.630797, 0.092555, 0.019838
dd 2.627250, 0.122455, 0.028504
dd 2.620723, 0.166419, 0.044302
dd 2.607644, 0.238078, 0.075743
dd 2.585871, 0.339801, 0.127848
dd 2.560420, 0.441012, 0.188035
dd 2.538622, 0.507316, 0.236779
dd 2.520776, 0.537045, 0.271775
dd 2.503016, 0.538883, 0.299974
dd 2.480048, 0.514962, 0.330420
dd 2.450064, 0.457481, 0.369764
dd 2.416346, 0.354726, 0.420045
dd 2.502556, 0.125531, 0.367917
dd 2.506535, 0.060146, 0.383118
dd 2.519810, 0.018001, 0.386838
dd 2.533758, -0.005269, 0.384562
dd 2.544930, -0.019568, 0.380417
dd 2.553120, -0.033008, 0.375624
dd 2.560841, -0.049374, 0.367089
dd 2.570228, -0.069688, 0.350085
dd 2.581793, -0.090150, 0.321725
dd 2.592716, -0.102112, 0.288799
dd 2.600173, -0.104753, 0.262331
dd 2.604670, -0.102535, 0.243905
dd 2.607806, -0.098740, 0.230043
dd 2.611038, -0.094128, 0.216360
dd 2.615082, -0.085482, 0.199608
dd 2.620013, -0.067923, 0.178646
dd 2.624662, -0.038446, 0.157259
dd 2.626843, -0.004135, 0.144370
dd 2.626689, 0.023477, 0.141071
dd 2.625473, 0.042701, 0.142882
dd 2.623979, 0.057134, 0.146396
dd 2.622249, 0.071920, 0.150665
dd 2.619178, 0.093928, 0.158423
dd 2.613194, 0.130290, 0.173822
dd 2.603412, 0.182555, 0.199302
dd 2.592076, 0.235222, 0.228699
dd 2.582132, 0.270208, 0.252492
dd 2.573437, 0.286335, 0.269577
dd 2.563971, 0.288012, 0.283360
dd 2.550932, 0.276447, 0.298276
dd 2.533703, 0.247861, 0.317614
dd 2.514736, 0.196442, 0.342432
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265237
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601440, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265237
dd 2.601441, 0.022070, 0.265236
dd 2.601441, 0.022070, 0.265237
dd 2.601441, 0.022070, 0.265237
vertcount equ ($ - test_verts) / 12
test_faces:

%macro face 3
  dw %1, %2, %3
  dd 0, 0, 0
%endmacro

face 0, 32, 63
face 0, 63, 31
face 32, 0, 1
face 32, 1, 33
face 2, 34, 33
face 2, 33, 1
face 3, 35, 34
face 3, 34, 2
face 4, 36, 35
face 4, 35, 3
face 5, 37, 36
face 5, 36, 4
face 6, 38, 37
face 6, 37, 5
face 7, 39, 38
face 7, 38, 6
face 8, 40, 39
face 8, 39, 7
face 9, 41, 40
face 9, 40, 8
face 10, 42, 41
face 10, 41, 9
face 11, 43, 42
face 11, 42, 10
face 12, 44, 43
face 12, 43, 11
face 13, 45, 44
face 13, 44, 12
face 14, 46, 45
face 14, 45, 13
face 15, 47, 46
face 15, 46, 14
face 16, 48, 47
face 16, 47, 15
face 17, 49, 48
face 17, 48, 16
face 18, 50, 49
face 18, 49, 17
face 19, 51, 50
face 19, 50, 18
face 20, 52, 51
face 20, 51, 19
face 21, 53, 52
face 21, 52, 20
face 22, 54, 53
face 22, 53, 21
face 23, 55, 54
face 23, 54, 22
face 24, 56, 55
face 24, 55, 23
face 25, 57, 56
face 25, 56, 24
face 26, 58, 57
face 26, 57, 25
face 27, 59, 58
face 27, 58, 26
face 28, 60, 59
face 28, 59, 27
face 29, 61, 60
face 29, 60, 28
face 30, 62, 61
face 30, 61, 29
face 31, 63, 62
face 31, 62, 30
face 32, 64, 95
face 32, 95, 63
face 33, 65, 64
face 33, 64, 32
face 34, 66, 65
face 34, 65, 33
face 35, 67, 66
face 35, 66, 34
face 36, 68, 67
face 36, 67, 35
face 37, 69, 68
face 37, 68, 36
face 38, 70, 69
face 38, 69, 37
face 39, 71, 70
face 39, 70, 38
face 40, 72, 71
face 40, 71, 39
face 41, 73, 72
face 41, 72, 40
face 42, 74, 73
face 42, 73, 41
face 43, 75, 74
face 43, 74, 42
face 44, 76, 75
face 44, 75, 43
face 45, 77, 76
face 45, 76, 44
face 46, 78, 77
face 46, 77, 45
face 47, 79, 78
face 47, 78, 46
face 48, 80, 79
face 48, 79, 47
face 49, 81, 80
face 49, 80, 48
face 50, 82, 81
face 50, 81, 49
face 51, 83, 82
face 51, 82, 50
face 52, 84, 83
face 52, 83, 51
face 53, 85, 84
face 53, 84, 52
face 54, 86, 85
face 54, 85, 53
face 55, 87, 86
face 55, 86, 54
face 56, 88, 87
face 56, 87, 55
face 57, 89, 88
face 57, 88, 56
face 58, 90, 89
face 58, 89, 57
face 59, 91, 90
face 59, 90, 58
face 60, 92, 91
face 60, 91, 59
face 61, 93, 92
face 61, 92, 60
face 62, 94, 93
face 62, 93, 61
face 63, 95, 94
face 63, 94, 62
face 64, 96, 127
face 64, 127, 95
face 65, 97, 96
face 65, 96, 64
face 66, 98, 97
face 66, 97, 65
face 67, 99, 98
face 67, 98, 66
face 68, 100, 99
face 68, 99, 67
face 69, 101, 100
face 69, 100, 68
face 70, 102, 101
face 70, 101, 69
face 71, 103, 102
face 71, 102, 70
face 72, 104, 103
face 72, 103, 71
face 73, 105, 104
face 73, 104, 72
face 74, 106, 105
face 74, 105, 73
face 75, 107, 106
face 75, 106, 74
face 76, 108, 107
face 76, 107, 75
face 77, 109, 108
face 77, 108, 76
face 78, 110, 109
face 78, 109, 77
face 79, 111, 110
face 79, 110, 78
face 80, 112, 111
face 80, 111, 79
face 81, 113, 112
face 81, 112, 80
face 82, 114, 113
face 82, 113, 81
face 83, 115, 114
face 83, 114, 82
face 84, 116, 115
face 84, 115, 83
face 85, 117, 116
face 85, 116, 84
face 86, 118, 117
face 86, 117, 85
face 87, 119, 118
face 87, 118, 86
face 88, 120, 119
face 88, 119, 87
face 89, 121, 120
face 89, 120, 88
face 90, 122, 121
face 90, 121, 89
face 91, 123, 122
face 91, 122, 90
face 92, 124, 123
face 92, 123, 91
face 93, 125, 124
face 93, 124, 92
face 94, 126, 125
face 94, 125, 93
face 95, 127, 126
face 95, 126, 94
face 96, 128, 159
face 96, 159, 127
face 97, 129, 128
face 97, 128, 96
face 98, 130, 129
face 98, 129, 97
face 99, 131, 130
face 99, 130, 98
face 100, 132, 131
face 100, 131, 99
face 101, 133, 132
face 101, 132, 100
face 102, 134, 133
face 102, 133, 101
face 103, 135, 134
face 103, 134, 102
face 104, 136, 135
face 104, 135, 103
face 105, 137, 136
face 105, 136, 104
face 106, 138, 137
face 106, 137, 105
face 107, 139, 138
face 107, 138, 106
face 108, 140, 139
face 108, 139, 107
face 109, 141, 140
face 109, 140, 108
face 110, 142, 141
face 110, 141, 109
face 111, 143, 142
face 111, 142, 110
face 112, 144, 143
face 112, 143, 111
face 113, 145, 144
face 113, 144, 112
face 114, 146, 145
face 114, 145, 113
face 115, 147, 146
face 115, 146, 114
face 116, 148, 147
face 116, 147, 115
face 117, 149, 148
face 117, 148, 116
face 118, 150, 149
face 118, 149, 117
face 119, 151, 150
face 119, 150, 118
face 120, 152, 151
face 120, 151, 119
face 121, 153, 152
face 121, 152, 120
face 122, 154, 153
face 122, 153, 121
face 123, 155, 154
face 123, 154, 122
face 124, 156, 155
face 124, 155, 123
face 125, 157, 156
face 125, 156, 124
face 126, 158, 157
face 126, 157, 125
face 127, 159, 158
face 127, 158, 126
face 128, 160, 191
face 128, 191, 159
face 129, 161, 160
face 129, 160, 128
face 130, 162, 161
face 130, 161, 129
face 131, 163, 162
face 131, 162, 130
face 132, 164, 163
face 132, 163, 131
face 133, 165, 164
face 133, 164, 132
face 134, 166, 165
face 134, 165, 133
face 135, 167, 166
face 135, 166, 134
face 136, 168, 167
face 136, 167, 135
face 137, 169, 168
face 137, 168, 136
face 138, 170, 169
face 138, 169, 137
face 139, 171, 170
face 139, 170, 138
face 140, 172, 171
face 140, 171, 139
face 141, 173, 172
face 141, 172, 140
face 142, 174, 173
face 142, 173, 141
face 143, 175, 174
face 143, 174, 142
face 144, 176, 175
face 144, 175, 143
face 145, 177, 176
face 145, 176, 144
face 146, 178, 177
face 146, 177, 145
face 147, 179, 178
face 147, 178, 146
face 148, 180, 179
face 148, 179, 147
face 149, 181, 180
face 149, 180, 148
face 150, 182, 181
face 150, 181, 149
face 151, 183, 182
face 151, 182, 150
face 152, 184, 183
face 152, 183, 151
face 153, 185, 184
face 153, 184, 152
face 154, 186, 185
face 154, 185, 153
face 155, 187, 186
face 155, 186, 154
face 156, 188, 187
face 156, 187, 155
face 157, 189, 188
face 157, 188, 156
face 158, 190, 189
face 158, 189, 157
face 159, 191, 190
face 159, 190, 158
face 160, 192, 223
face 160, 223, 191
face 161, 193, 192
face 161, 192, 160
face 162, 194, 193
face 162, 193, 161
face 163, 195, 194
face 163, 194, 162
face 164, 196, 195
face 164, 195, 163
face 165, 197, 196
face 165, 196, 164
face 166, 198, 197
face 166, 197, 165
face 167, 199, 198
face 167, 198, 166
face 168, 200, 199
face 168, 199, 167
face 169, 201, 200
face 169, 200, 168
face 170, 202, 201
face 170, 201, 169
face 171, 203, 202
face 171, 202, 170
face 172, 204, 203
face 172, 203, 171
face 173, 205, 204
face 173, 204, 172
face 174, 206, 205
face 174, 205, 173
face 175, 207, 206
face 175, 206, 174
face 176, 208, 207
face 176, 207, 175
face 177, 209, 208
face 177, 208, 176
face 178, 210, 209
face 178, 209, 177
face 179, 211, 210
face 179, 210, 178
face 180, 212, 211
face 180, 211, 179
face 181, 213, 212
face 181, 212, 180
face 182, 214, 213
face 182, 213, 181
face 183, 215, 214
face 183, 214, 182
face 184, 216, 215
face 184, 215, 183
face 185, 217, 216
face 185, 216, 184
face 186, 218, 217
face 186, 217, 185
face 187, 219, 218
face 187, 218, 186
face 188, 220, 219
face 188, 219, 187
face 189, 221, 220
face 189, 220, 188
face 190, 222, 221
face 190, 221, 189
face 191, 223, 222
face 191, 222, 190
face 192, 224, 255
face 192, 255, 223
face 193, 225, 224
face 193, 224, 192
face 194, 226, 225
face 194, 225, 193
face 195, 227, 226
face 195, 226, 194
face 196, 228, 227
face 196, 227, 195
face 197, 229, 228
face 197, 228, 196
face 198, 230, 229
face 198, 229, 197
face 199, 231, 230
face 199, 230, 198
face 200, 232, 231
face 200, 231, 199
face 201, 233, 232
face 201, 232, 200
face 202, 234, 233
face 202, 233, 201
face 203, 235, 234
face 203, 234, 202
face 204, 236, 235
face 204, 235, 203
face 205, 237, 236
face 205, 236, 204
face 206, 238, 237
face 206, 237, 205
face 207, 239, 238
face 207, 238, 206
face 208, 240, 239
face 208, 239, 207
face 209, 241, 240
face 209, 240, 208
face 210, 242, 241
face 210, 241, 209
face 211, 243, 242
face 211, 242, 210
face 212, 244, 243
face 212, 243, 211
face 213, 245, 244
face 213, 244, 212
face 214, 246, 245
face 214, 245, 213
face 215, 247, 246
face 215, 246, 214
face 216, 248, 247
face 216, 247, 215
face 217, 249, 248
face 217, 248, 216
face 218, 250, 249
face 218, 249, 217
face 219, 251, 250
face 219, 250, 218
face 220, 252, 251
face 220, 251, 219
face 221, 253, 252
face 221, 252, 220
face 222, 254, 253
face 222, 253, 221
face 223, 255, 254
face 223, 254, 222
face 224, 256, 287
face 224, 287, 255
face 225, 257, 256
face 225, 256, 224
face 226, 258, 257
face 226, 257, 225
face 227, 259, 258
face 227, 258, 226
face 228, 260, 259
face 228, 259, 227
face 229, 261, 260
face 229, 260, 228
face 230, 262, 261
face 230, 261, 229
face 231, 263, 262
face 231, 262, 230
face 232, 264, 263
face 232, 263, 231
face 233, 265, 264
face 233, 264, 232
face 234, 266, 265
face 234, 265, 233
face 235, 267, 266
face 235, 266, 234
face 236, 268, 267
face 236, 267, 235
face 237, 269, 268
face 237, 268, 236
face 238, 270, 269
face 238, 269, 237
face 239, 271, 270
face 239, 270, 238
face 240, 272, 271
face 240, 271, 239
face 241, 273, 272
face 241, 272, 240
face 242, 274, 273
face 242, 273, 241
face 243, 275, 274
face 243, 274, 242
face 244, 276, 275
face 244, 275, 243
face 245, 277, 276
face 245, 276, 244
face 246, 278, 277
face 246, 277, 245
face 247, 279, 278
face 247, 278, 246
face 248, 280, 279
face 248, 279, 247
face 249, 281, 280
face 249, 280, 248
face 250, 282, 281
face 250, 281, 249
face 251, 283, 282
face 251, 282, 250
face 252, 284, 283
face 252, 283, 251
face 253, 285, 284
face 253, 284, 252
face 254, 286, 285
face 254, 285, 253
face 255, 287, 286
face 255, 286, 254
face 256, 288, 319
face 256, 319, 287
face 257, 289, 288
face 257, 288, 256
face 258, 290, 289
face 258, 289, 257
face 259, 291, 290
face 259, 290, 258
face 260, 292, 291
face 260, 291, 259
face 261, 293, 292
face 261, 292, 260
face 262, 294, 293
face 262, 293, 261
face 263, 295, 294
face 263, 294, 262
face 264, 296, 295
face 264, 295, 263
face 265, 297, 296
face 265, 296, 264
face 266, 298, 297
face 266, 297, 265
face 267, 299, 298
face 267, 298, 266
face 268, 300, 299
face 268, 299, 267
face 269, 301, 300
face 269, 300, 268
face 270, 302, 301
face 270, 301, 269
face 271, 303, 302
face 271, 302, 270
face 272, 304, 303
face 272, 303, 271
face 273, 305, 304
face 273, 304, 272
face 274, 306, 305
face 274, 305, 273
face 275, 307, 306
face 275, 306, 274
face 276, 308, 307
face 276, 307, 275
face 277, 309, 308
face 277, 308, 276
face 278, 310, 309
face 278, 309, 277
face 279, 311, 310
face 279, 310, 278
face 280, 312, 311
face 280, 311, 279
face 281, 313, 312
face 281, 312, 280
face 282, 314, 313
face 282, 313, 281
face 283, 315, 314
face 283, 314, 282
face 284, 316, 315
face 284, 315, 283
face 285, 317, 316
face 285, 316, 284
face 286, 318, 317
face 286, 317, 285
face 287, 319, 318
face 287, 318, 286
face 288, 320, 351
face 288, 351, 319
face 289, 321, 320
face 289, 320, 288
face 290, 322, 321
face 290, 321, 289
face 291, 323, 322
face 291, 322, 290
face 292, 324, 323
face 292, 323, 291
face 293, 325, 324
face 293, 324, 292
face 294, 326, 325
face 294, 325, 293
face 295, 327, 326
face 295, 326, 294
face 296, 328, 327
face 296, 327, 295
face 297, 329, 328
face 297, 328, 296
face 298, 330, 329
face 298, 329, 297
face 299, 331, 330
face 299, 330, 298
face 300, 332, 331
face 300, 331, 299
face 301, 333, 332
face 301, 332, 300
face 302, 334, 333
face 302, 333, 301
face 303, 335, 334
face 303, 334, 302
face 304, 336, 335
face 304, 335, 303
face 305, 337, 336
face 305, 336, 304
face 306, 338, 337
face 306, 337, 305
face 307, 339, 338
face 307, 338, 306
face 308, 340, 339
face 308, 339, 307
face 309, 341, 340
face 309, 340, 308
face 310, 342, 341
face 310, 341, 309
face 311, 343, 342
face 311, 342, 310
face 312, 344, 343
face 312, 343, 311
face 313, 345, 344
face 313, 344, 312
face 314, 346, 345
face 314, 345, 313
face 315, 347, 346
face 315, 346, 314
face 316, 348, 347
face 316, 347, 315
face 317, 349, 348
face 317, 348, 316
face 318, 350, 349
face 318, 349, 317
face 319, 351, 350
face 319, 350, 318
face 320, 352, 383
face 320, 383, 351
face 321, 353, 352
face 321, 352, 320
face 322, 354, 353
face 322, 353, 321
face 323, 355, 354
face 323, 354, 322
face 324, 356, 355
face 324, 355, 323
face 325, 357, 356
face 325, 356, 324
face 326, 358, 357
face 326, 357, 325
face 327, 359, 358
face 327, 358, 326
face 328, 360, 359
face 328, 359, 327
face 329, 361, 360
face 329, 360, 328
face 330, 362, 361
face 330, 361, 329
face 331, 363, 362
face 331, 362, 330
face 332, 364, 363
face 332, 363, 331
face 333, 365, 364
face 333, 364, 332
face 334, 366, 365
face 334, 365, 333
face 335, 367, 366
face 335, 366, 334
face 336, 368, 367
face 336, 367, 335
face 337, 369, 368
face 337, 368, 336
face 338, 370, 369
face 338, 369, 337
face 339, 371, 370
face 339, 370, 338
face 340, 372, 371
face 340, 371, 339
face 341, 373, 372
face 341, 372, 340
face 342, 374, 373
face 342, 373, 341
face 343, 375, 374
face 343, 374, 342
face 344, 376, 375
face 344, 375, 343
face 345, 377, 376
face 345, 376, 344
face 346, 378, 377
face 346, 377, 345
face 347, 379, 378
face 347, 378, 346
face 348, 380, 379
face 348, 379, 347
face 349, 381, 380
face 349, 380, 348
face 350, 382, 381
face 350, 381, 349
face 351, 383, 382
face 351, 382, 350
face 352, 384, 415
face 352, 415, 383
face 353, 385, 384
face 353, 384, 352
face 354, 386, 385
face 354, 385, 353
face 355, 387, 386
face 355, 386, 354
face 356, 388, 387
face 356, 387, 355
face 357, 389, 388
face 357, 388, 356
face 358, 390, 389
face 358, 389, 357
face 359, 391, 390
face 359, 390, 358
face 360, 392, 391
face 360, 391, 359
face 361, 393, 392
face 361, 392, 360
face 362, 394, 393
face 362, 393, 361
face 363, 395, 394
face 363, 394, 362
face 364, 396, 395
face 364, 395, 363
face 365, 397, 396
face 365, 396, 364
face 366, 398, 397
face 366, 397, 365
face 367, 399, 398
face 367, 398, 366
face 368, 400, 399
face 368, 399, 367
face 369, 401, 400
face 369, 400, 368
face 370, 402, 401
face 370, 401, 369
face 371, 403, 402
face 371, 402, 370
face 372, 404, 403
face 372, 403, 371
face 373, 405, 404
face 373, 404, 372
face 374, 406, 405
face 374, 405, 373
face 375, 407, 406
face 375, 406, 374
face 376, 408, 407
face 376, 407, 375
face 377, 409, 408
face 377, 408, 376
face 378, 410, 409
face 378, 409, 377
face 379, 411, 410
face 379, 410, 378
face 380, 412, 411
face 380, 411, 379
face 381, 413, 412
face 381, 412, 380
face 382, 414, 413
face 382, 413, 381
face 383, 415, 414
face 383, 414, 382
face 384, 416, 447
face 384, 447, 415
face 385, 417, 416
face 385, 416, 384
face 386, 418, 417
face 386, 417, 385
face 387, 419, 418
face 387, 418, 386
face 388, 420, 419
face 388, 419, 387
face 389, 421, 420
face 389, 420, 388
face 390, 422, 421
face 390, 421, 389
face 391, 423, 422
face 391, 422, 390
face 392, 424, 423
face 392, 423, 391
face 393, 425, 424
face 393, 424, 392
face 394, 426, 425
face 394, 425, 393
face 395, 427, 426
face 395, 426, 394
face 396, 428, 427
face 396, 427, 395
face 397, 429, 428
face 397, 428, 396
face 398, 430, 429
face 398, 429, 397
face 399, 431, 430
face 399, 430, 398
face 400, 432, 431
face 400, 431, 399
face 401, 433, 432
face 401, 432, 400
face 402, 434, 433
face 402, 433, 401
face 403, 435, 434
face 403, 434, 402
face 404, 436, 435
face 404, 435, 403
face 405, 437, 436
face 405, 436, 404
face 406, 438, 437
face 406, 437, 405
face 407, 439, 438
face 407, 438, 406
face 408, 440, 439
face 408, 439, 407
face 409, 441, 440
face 409, 440, 408
face 410, 442, 441
face 410, 441, 409
face 411, 443, 442
face 411, 442, 410
face 412, 444, 443
face 412, 443, 411
face 413, 445, 444
face 413, 444, 412
face 414, 446, 445
face 414, 445, 413
face 415, 447, 446
face 415, 446, 414
face 416, 448, 479
face 416, 479, 447
face 417, 449, 448
face 417, 448, 416
face 418, 450, 449
face 418, 449, 417
face 419, 451, 450
face 419, 450, 418
face 420, 452, 451
face 420, 451, 419
face 421, 453, 452
face 421, 452, 420
face 422, 454, 453
face 422, 453, 421
face 423, 455, 454
face 423, 454, 422
face 424, 456, 455
face 424, 455, 423
face 425, 457, 456
face 425, 456, 424
face 426, 458, 457
face 426, 457, 425
face 427, 459, 458
face 427, 458, 426
face 428, 460, 459
face 428, 459, 427
face 429, 461, 460
face 429, 460, 428
face 430, 462, 461
face 430, 461, 429
face 431, 463, 462
face 431, 462, 430
face 432, 464, 463
face 432, 463, 431
face 433, 465, 464
face 433, 464, 432
face 434, 466, 465
face 434, 465, 433
face 435, 467, 466
face 435, 466, 434
face 436, 468, 467
face 436, 467, 435
face 437, 469, 468
face 437, 468, 436
face 438, 470, 469
face 438, 469, 437
face 439, 471, 470
face 439, 470, 438
face 440, 472, 471
face 440, 471, 439
face 441, 473, 472
face 441, 472, 440
face 442, 474, 473
face 442, 473, 441
face 443, 475, 474
face 443, 474, 442
face 444, 476, 475
face 444, 475, 443
face 445, 477, 476
face 445, 476, 444
face 446, 478, 477
face 446, 477, 445
face 447, 479, 478
face 447, 478, 446
face 448, 480, 511
face 448, 511, 479
face 449, 481, 480
face 449, 480, 448
face 450, 482, 481
face 450, 481, 449
face 451, 483, 482
face 451, 482, 450
face 452, 484, 483
face 452, 483, 451
face 453, 485, 484
face 453, 484, 452
face 454, 486, 485
face 454, 485, 453
face 455, 487, 486
face 455, 486, 454
face 456, 488, 487
face 456, 487, 455
face 457, 489, 488
face 457, 488, 456
face 458, 490, 489
face 458, 489, 457
face 459, 491, 490
face 459, 490, 458
face 460, 492, 491
face 460, 491, 459
face 461, 493, 492
face 461, 492, 460
face 462, 494, 493
face 462, 493, 461
face 463, 495, 494
face 463, 494, 462
face 464, 496, 495
face 464, 495, 463
face 465, 497, 496
face 465, 496, 464
face 466, 498, 497
face 466, 497, 465
face 467, 499, 498
face 467, 498, 466
face 468, 500, 499
face 468, 499, 467
face 469, 501, 500
face 469, 500, 468
face 470, 502, 501
face 470, 501, 469
face 471, 503, 502
face 471, 502, 470
face 472, 504, 503
face 472, 503, 471
face 473, 505, 504
face 473, 504, 472
face 474, 506, 505
face 474, 505, 473
face 475, 507, 506
face 475, 506, 474
face 476, 508, 507
face 476, 507, 475
face 477, 509, 508
face 477, 508, 476
face 478, 510, 509
face 478, 509, 477
face 479, 511, 510
face 479, 510, 478
face 480, 512, 543
face 480, 543, 511
face 481, 513, 512
face 481, 512, 480
face 482, 514, 513
face 482, 513, 481
face 483, 515, 514
face 483, 514, 482
face 484, 516, 515
face 484, 515, 483
face 485, 517, 516
face 485, 516, 484
face 486, 518, 517
face 486, 517, 485
face 487, 519, 518
face 487, 518, 486
face 488, 520, 519
face 488, 519, 487
face 489, 521, 520
face 489, 520, 488
face 490, 522, 521
face 490, 521, 489
face 491, 523, 522
face 491, 522, 490
face 492, 524, 523
face 492, 523, 491
face 493, 525, 524
face 493, 524, 492
face 494, 526, 525
face 494, 525, 493
face 495, 527, 526
face 495, 526, 494
face 496, 528, 527
face 496, 527, 495
face 497, 529, 528
face 497, 528, 496
face 498, 530, 529
face 498, 529, 497
face 499, 531, 530
face 499, 530, 498
face 500, 532, 531
face 500, 531, 499
face 501, 533, 532
face 501, 532, 500
face 502, 534, 533
face 502, 533, 501
face 503, 535, 534
face 503, 534, 502
face 504, 536, 535
face 504, 535, 503
face 505, 537, 536
face 505, 536, 504
face 506, 538, 537
face 506, 537, 505
face 507, 539, 538
face 507, 538, 506
face 508, 540, 539
face 508, 539, 507
face 509, 541, 540
face 509, 540, 508
face 510, 542, 541
face 510, 541, 509
face 511, 543, 542
face 511, 542, 510
face 512, 544, 575
face 512, 575, 543
face 513, 545, 544
face 513, 544, 512
face 514, 546, 545
face 514, 545, 513
face 515, 547, 546
face 515, 546, 514
face 516, 548, 547
face 516, 547, 515
face 517, 549, 548
face 517, 548, 516
face 518, 550, 549
face 518, 549, 517
face 519, 551, 550
face 519, 550, 518
face 520, 552, 551
face 520, 551, 519
face 521, 553, 552
face 521, 552, 520
face 522, 554, 553
face 522, 553, 521
face 523, 555, 554
face 523, 554, 522
face 524, 556, 555
face 524, 555, 523
face 525, 557, 556
face 525, 556, 524
face 526, 558, 557
face 526, 557, 525
face 527, 559, 558
face 527, 558, 526
face 528, 560, 559
face 528, 559, 527
face 529, 561, 560
face 529, 560, 528
face 530, 562, 561
face 530, 561, 529
face 531, 563, 562
face 531, 562, 530
face 532, 564, 563
face 532, 563, 531
face 533, 565, 564
face 533, 564, 532
face 534, 566, 565
face 534, 565, 533
face 535, 567, 566
face 535, 566, 534
face 536, 568, 567
face 536, 567, 535
face 537, 569, 568
face 537, 568, 536
face 538, 570, 569
face 538, 569, 537
face 539, 571, 570
face 539, 570, 538
face 540, 572, 571
face 540, 571, 539
face 541, 573, 572
face 541, 572, 540
face 542, 574, 573
face 542, 573, 541
face 543, 575, 574
face 543, 574, 542
face 544, 576, 607
face 544, 607, 575
face 545, 577, 576
face 545, 576, 544
face 546, 578, 577
face 546, 577, 545
face 547, 579, 578
face 547, 578, 546
face 548, 580, 579
face 548, 579, 547
face 549, 581, 580
face 549, 580, 548
face 550, 582, 581
face 550, 581, 549
face 551, 583, 582
face 551, 582, 550
face 552, 584, 583
face 552, 583, 551
face 553, 585, 584
face 553, 584, 552
face 554, 586, 585
face 554, 585, 553
face 555, 587, 586
face 555, 586, 554
face 556, 588, 587
face 556, 587, 555
face 557, 589, 588
face 557, 588, 556
face 558, 590, 589
face 558, 589, 557
face 559, 591, 590
face 559, 590, 558
face 560, 592, 591
face 560, 591, 559
face 561, 593, 592
face 561, 592, 560
face 562, 594, 593
face 562, 593, 561
face 563, 595, 594
face 563, 594, 562
face 564, 596, 595
face 564, 595, 563
face 565, 597, 596
face 565, 596, 564
face 566, 598, 597
face 566, 597, 565
face 567, 599, 598
face 567, 598, 566
face 568, 600, 599
face 568, 599, 567
face 569, 601, 600
face 569, 600, 568
face 570, 602, 601
face 570, 601, 569
face 571, 603, 602
face 571, 602, 570
face 572, 604, 603
face 572, 603, 571
face 573, 605, 604
face 573, 604, 572
face 574, 606, 605
face 574, 605, 573
face 575, 607, 606
face 575, 606, 574
face 576, 608, 639
face 576, 639, 607
face 577, 609, 608
face 577, 608, 576
face 578, 610, 609
face 578, 609, 577
face 579, 611, 610
face 579, 610, 578
face 580, 612, 611
face 580, 611, 579
face 581, 613, 612
face 581, 612, 580
face 582, 614, 613
face 582, 613, 581
face 583, 615, 614
face 583, 614, 582
face 584, 616, 615
face 584, 615, 583
face 585, 617, 616
face 585, 616, 584
face 586, 618, 617
face 586, 617, 585
face 587, 619, 618
face 587, 618, 586
face 588, 620, 619
face 588, 619, 587
face 589, 621, 620
face 589, 620, 588
face 590, 622, 621
face 590, 621, 589
face 591, 623, 622
face 591, 622, 590
face 592, 624, 623
face 592, 623, 591
face 593, 625, 624
face 593, 624, 592
face 594, 626, 625
face 594, 625, 593
face 595, 627, 626
face 595, 626, 594
face 596, 628, 627
face 596, 627, 595
face 597, 629, 628
face 597, 628, 596
face 598, 630, 629
face 598, 629, 597
face 599, 631, 630
face 599, 630, 598
face 600, 632, 631
face 600, 631, 599
face 601, 633, 632
face 601, 632, 600
face 602, 634, 633
face 602, 633, 601
face 603, 635, 634
face 603, 634, 602
face 604, 636, 635
face 604, 635, 603
face 605, 637, 636
face 605, 636, 604
face 606, 638, 637
face 606, 637, 605
face 607, 639, 638
face 607, 638, 606
face 608, 640, 671
face 608, 671, 639
face 609, 641, 640
face 609, 640, 608
face 610, 642, 641
face 610, 641, 609
face 611, 643, 642
face 611, 642, 610
face 612, 644, 643
face 612, 643, 611
face 613, 645, 644
face 613, 644, 612
face 614, 646, 645
face 614, 645, 613
face 615, 647, 646
face 615, 646, 614
face 616, 648, 647
face 616, 647, 615
face 617, 649, 648
face 617, 648, 616
face 618, 650, 649
face 618, 649, 617
face 619, 651, 650
face 619, 650, 618
face 620, 652, 651
face 620, 651, 619
face 621, 653, 652
face 621, 652, 620
face 622, 654, 653
face 622, 653, 621
face 623, 655, 654
face 623, 654, 622
face 624, 656, 655
face 624, 655, 623
face 625, 657, 656
face 625, 656, 624
face 626, 658, 657
face 626, 657, 625
face 627, 659, 658
face 627, 658, 626
face 628, 660, 659
face 628, 659, 627
face 629, 661, 660
face 629, 660, 628
face 630, 662, 661
face 630, 661, 629
face 631, 663, 662
face 631, 662, 630
face 632, 664, 663
face 632, 663, 631
face 633, 665, 664
face 633, 664, 632
face 634, 666, 665
face 634, 665, 633
face 635, 667, 666
face 635, 666, 634
face 636, 668, 667
face 636, 667, 635
face 637, 669, 668
face 637, 668, 636
face 638, 670, 669
face 638, 669, 637
face 639, 671, 670
face 639, 670, 638
face 640, 672, 703
face 640, 703, 671
face 641, 673, 672
face 641, 672, 640
face 642, 674, 673
face 642, 673, 641
face 643, 675, 674
face 643, 674, 642
face 644, 676, 675
face 644, 675, 643
face 645, 677, 676
face 645, 676, 644
face 646, 678, 677
face 646, 677, 645
face 647, 679, 678
face 647, 678, 646
face 648, 680, 679
face 648, 679, 647
face 649, 681, 680
face 649, 680, 648
face 650, 682, 681
face 650, 681, 649
face 651, 683, 682
face 651, 682, 650
face 652, 684, 683
face 652, 683, 651
face 653, 685, 684
face 653, 684, 652
face 654, 686, 685
face 654, 685, 653
face 655, 687, 686
face 655, 686, 654
face 656, 688, 687
face 656, 687, 655
face 657, 689, 688
face 657, 688, 656
face 658, 690, 689
face 658, 689, 657
face 659, 691, 690
face 659, 690, 658
face 660, 692, 691
face 660, 691, 659
face 661, 693, 692
face 661, 692, 660
face 662, 694, 693
face 662, 693, 661
face 663, 695, 694
face 663, 694, 662
face 664, 696, 695
face 664, 695, 663
face 665, 697, 696
face 665, 696, 664
face 666, 698, 697
face 666, 697, 665
face 667, 699, 698
face 667, 698, 666
face 668, 700, 699
face 668, 699, 667
face 669, 701, 700
face 669, 700, 668
face 670, 702, 701
face 670, 701, 669
face 671, 703, 702
face 671, 702, 670
face 672, 704, 735
face 672, 735, 703
face 673, 705, 704
face 673, 704, 672
face 674, 706, 705
face 674, 705, 673
face 675, 707, 706
face 675, 706, 674
face 676, 708, 707
face 676, 707, 675
face 677, 709, 708
face 677, 708, 676
face 678, 710, 709
face 678, 709, 677
face 679, 711, 710
face 679, 710, 678
face 680, 712, 711
face 680, 711, 679
face 681, 713, 712
face 681, 712, 680
face 682, 714, 713
face 682, 713, 681
face 683, 715, 714
face 683, 714, 682
face 684, 716, 715
face 684, 715, 683
face 685, 717, 716
face 685, 716, 684
face 686, 718, 717
face 686, 717, 685
face 687, 719, 718
face 687, 718, 686
face 688, 720, 719
face 688, 719, 687
face 689, 721, 720
face 689, 720, 688
face 690, 722, 721
face 690, 721, 689
face 691, 723, 722
face 691, 722, 690
face 692, 724, 723
face 692, 723, 691
face 693, 725, 724
face 693, 724, 692
face 694, 726, 725
face 694, 725, 693
face 695, 727, 726
face 695, 726, 694
face 696, 728, 727
face 696, 727, 695
face 697, 729, 728
face 697, 728, 696
face 698, 730, 729
face 698, 729, 697
face 699, 731, 730
face 699, 730, 698
face 700, 732, 731
face 700, 731, 699
face 701, 733, 732
face 701, 732, 700
face 702, 734, 733
face 702, 733, 701
face 703, 735, 734
face 703, 734, 702
face 704, 736, 767
face 704, 767, 735
face 705, 737, 736
face 705, 736, 704
face 706, 738, 737
face 706, 737, 705
face 707, 739, 738
face 707, 738, 706
face 708, 740, 739
face 708, 739, 707
face 709, 741, 740
face 709, 740, 708
face 710, 742, 741
face 710, 741, 709
face 711, 743, 742
face 711, 742, 710
face 712, 744, 743
face 712, 743, 711
face 713, 745, 744
face 713, 744, 712
face 714, 746, 745
face 714, 745, 713
face 715, 747, 746
face 715, 746, 714
face 716, 748, 747
face 716, 747, 715
face 717, 749, 748
face 717, 748, 716
face 718, 750, 749
face 718, 749, 717
face 719, 751, 750
face 719, 750, 718
face 720, 752, 751
face 720, 751, 719
face 721, 753, 752
face 721, 752, 720
face 722, 754, 753
face 722, 753, 721
face 723, 755, 754
face 723, 754, 722
face 724, 756, 755
face 724, 755, 723
face 725, 757, 756
face 725, 756, 724
face 726, 758, 757
face 726, 757, 725
face 727, 759, 758
face 727, 758, 726
face 728, 760, 759
face 728, 759, 727
face 729, 761, 760
face 729, 760, 728
face 730, 762, 761
face 730, 761, 729
face 731, 763, 762
face 731, 762, 730
face 732, 764, 763
face 732, 763, 731
face 733, 765, 764
face 733, 764, 732
face 734, 766, 765
face 734, 765, 733
face 735, 767, 766
face 735, 766, 734
face 768, 800, 831
face 768, 831, 799
face 800, 768, 769
face 800, 769, 801
face 770, 802, 801
face 770, 801, 769
face 771, 803, 802
face 771, 802, 770
face 772, 804, 803
face 772, 803, 771
face 773, 805, 804
face 773, 804, 772
face 774, 806, 805
face 774, 805, 773
face 775, 807, 806
face 775, 806, 774
face 776, 808, 807
face 776, 807, 775
face 777, 809, 808
face 777, 808, 776
face 778, 810, 809
face 778, 809, 777
face 779, 811, 810
face 779, 810, 778
face 780, 812, 811
face 780, 811, 779
face 781, 813, 812
face 781, 812, 780
face 782, 814, 813
face 782, 813, 781
face 783, 815, 814
face 783, 814, 782
face 784, 816, 815
face 784, 815, 783
face 785, 817, 816
face 785, 816, 784
face 786, 818, 817
face 786, 817, 785
face 787, 819, 818
face 787, 818, 786
face 788, 820, 819
face 788, 819, 787
face 789, 821, 820
face 789, 820, 788
face 790, 822, 821
face 790, 821, 789
face 791, 823, 822
face 791, 822, 790
face 792, 824, 823
face 792, 823, 791
face 793, 825, 824
face 793, 824, 792
face 794, 826, 825
face 794, 825, 793
face 795, 827, 826
face 795, 826, 794
face 796, 828, 827
face 796, 827, 795
face 797, 829, 828
face 797, 828, 796
face 798, 830, 829
face 798, 829, 797
face 799, 831, 830
face 799, 830, 798
face 800, 832, 863
face 800, 863, 831
face 801, 833, 832
face 801, 832, 800
face 802, 834, 833
face 802, 833, 801
face 803, 835, 834
face 803, 834, 802
face 804, 836, 835
face 804, 835, 803
face 805, 837, 836
face 805, 836, 804
face 806, 838, 837
face 806, 837, 805
face 807, 839, 838
face 807, 838, 806
face 808, 840, 839
face 808, 839, 807
face 809, 841, 840
face 809, 840, 808
face 810, 842, 841
face 810, 841, 809
face 811, 843, 842
face 811, 842, 810
face 812, 844, 843
face 812, 843, 811
face 813, 845, 844
face 813, 844, 812
face 814, 846, 845
face 814, 845, 813
face 815, 847, 846
face 815, 846, 814
face 816, 848, 847
face 816, 847, 815
face 817, 849, 848
face 817, 848, 816
face 818, 850, 849
face 818, 849, 817
face 819, 851, 850
face 819, 850, 818
face 820, 852, 851
face 820, 851, 819
face 821, 853, 852
face 821, 852, 820
face 822, 854, 853
face 822, 853, 821
face 823, 855, 854
face 823, 854, 822
face 824, 856, 855
face 824, 855, 823
face 825, 857, 856
face 825, 856, 824
face 826, 858, 857
face 826, 857, 825
face 827, 859, 858
face 827, 858, 826
face 828, 860, 859
face 828, 859, 827
face 829, 861, 860
face 829, 860, 828
face 830, 862, 861
face 830, 861, 829
face 831, 863, 862
face 831, 862, 830
face 832, 864, 895
face 832, 895, 863
face 833, 865, 864
face 833, 864, 832
face 834, 866, 865
face 834, 865, 833
face 835, 867, 866
face 835, 866, 834
face 836, 868, 867
face 836, 867, 835
face 837, 869, 868
face 837, 868, 836
face 838, 870, 869
face 838, 869, 837
face 839, 871, 870
face 839, 870, 838
face 840, 872, 871
face 840, 871, 839
face 841, 873, 872
face 841, 872, 840
face 842, 874, 873
face 842, 873, 841
face 843, 875, 874
face 843, 874, 842
face 844, 876, 875
face 844, 875, 843
face 845, 877, 876
face 845, 876, 844
face 846, 878, 877
face 846, 877, 845
face 847, 879, 878
face 847, 878, 846
face 848, 880, 879
face 848, 879, 847
face 849, 881, 880
face 849, 880, 848
face 850, 882, 881
face 850, 881, 849
face 851, 883, 882
face 851, 882, 850
face 852, 884, 883
face 852, 883, 851
face 853, 885, 884
face 853, 884, 852
face 854, 886, 885
face 854, 885, 853
face 855, 887, 886
face 855, 886, 854
face 856, 888, 887
face 856, 887, 855
face 857, 889, 888
face 857, 888, 856
face 858, 890, 889
face 858, 889, 857
face 859, 891, 890
face 859, 890, 858
face 860, 892, 891
face 860, 891, 859
face 861, 893, 892
face 861, 892, 860
face 862, 894, 893
face 862, 893, 861
face 863, 895, 894
face 863, 894, 862
face 864, 896, 927
face 864, 927, 895
face 865, 897, 896
face 865, 896, 864
face 866, 898, 897
face 866, 897, 865
face 867, 899, 898
face 867, 898, 866
face 868, 900, 899
face 868, 899, 867
face 869, 901, 900
face 869, 900, 868
face 870, 902, 901
face 870, 901, 869
face 871, 903, 902
face 871, 902, 870
face 872, 904, 903
face 872, 903, 871
face 873, 905, 904
face 873, 904, 872
face 874, 906, 905
face 874, 905, 873
face 875, 907, 906
face 875, 906, 874
face 876, 908, 907
face 876, 907, 875
face 877, 909, 908
face 877, 908, 876
face 878, 910, 909
face 878, 909, 877
face 879, 911, 910
face 879, 910, 878
face 880, 912, 911
face 880, 911, 879
face 881, 913, 912
face 881, 912, 880
face 882, 914, 913
face 882, 913, 881
face 883, 915, 914
face 883, 914, 882
face 884, 916, 915
face 884, 915, 883
face 885, 917, 916
face 885, 916, 884
face 886, 918, 917
face 886, 917, 885
face 887, 919, 918
face 887, 918, 886
face 888, 920, 919
face 888, 919, 887
face 889, 921, 920
face 889, 920, 888
face 890, 922, 921
face 890, 921, 889
face 891, 923, 922
face 891, 922, 890
face 892, 924, 923
face 892, 923, 891
face 893, 925, 924
face 893, 924, 892
face 894, 926, 925
face 894, 925, 893
face 895, 927, 926
face 895, 926, 894
face 896, 928, 959
face 896, 959, 927
face 897, 929, 928
face 897, 928, 896
face 898, 930, 929
face 898, 929, 897
face 899, 931, 930
face 899, 930, 898
face 900, 932, 931
face 900, 931, 899
face 901, 933, 932
face 901, 932, 900
face 902, 934, 933
face 902, 933, 901
face 903, 935, 934
face 903, 934, 902
face 904, 936, 935
face 904, 935, 903
face 905, 937, 936
face 905, 936, 904
face 906, 938, 937
face 906, 937, 905
face 907, 939, 938
face 907, 938, 906
face 908, 940, 939
face 908, 939, 907
face 909, 941, 940
face 909, 940, 908
face 910, 942, 941
face 910, 941, 909
face 911, 943, 942
face 911, 942, 910
face 912, 944, 943
face 912, 943, 911
face 913, 945, 944
face 913, 944, 912
face 914, 946, 945
face 914, 945, 913
face 915, 947, 946
face 915, 946, 914
face 916, 948, 947
face 916, 947, 915
face 917, 949, 948
face 917, 948, 916
face 918, 950, 949
face 918, 949, 917
face 919, 951, 950
face 919, 950, 918
face 920, 952, 951
face 920, 951, 919
face 921, 953, 952
face 921, 952, 920
face 922, 954, 953
face 922, 953, 921
face 923, 955, 954
face 923, 954, 922
face 924, 956, 955
face 924, 955, 923
face 925, 957, 956
face 925, 956, 924
face 926, 958, 957
face 926, 957, 925
face 927, 959, 958
face 927, 958, 926
face 928, 960, 991
face 928, 991, 959
face 929, 961, 960
face 929, 960, 928
face 930, 962, 961
face 930, 961, 929
face 931, 963, 962
face 931, 962, 930
face 932, 964, 963
face 932, 963, 931
face 933, 965, 964
face 933, 964, 932
face 934, 966, 965
face 934, 965, 933
face 935, 967, 966
face 935, 966, 934
face 936, 968, 967
face 936, 967, 935
face 937, 969, 968
face 937, 968, 936
face 938, 970, 969
face 938, 969, 937
face 939, 971, 970
face 939, 970, 938
face 940, 972, 971
face 940, 971, 939
face 941, 973, 972
face 941, 972, 940
face 942, 974, 973
face 942, 973, 941
face 943, 975, 974
face 943, 974, 942
face 944, 976, 975
face 944, 975, 943
face 945, 977, 976
face 945, 976, 944
face 946, 978, 977
face 946, 977, 945
face 947, 979, 978
face 947, 978, 946
face 948, 980, 979
face 948, 979, 947
face 949, 981, 980
face 949, 980, 948
face 950, 982, 981
face 950, 981, 949
face 951, 983, 982
face 951, 982, 950
face 952, 984, 983
face 952, 983, 951
face 953, 985, 984
face 953, 984, 952
face 954, 986, 985
face 954, 985, 953
face 955, 987, 986
face 955, 986, 954
face 956, 988, 987
face 956, 987, 955
face 957, 989, 988
face 957, 988, 956
face 958, 990, 989
face 958, 989, 957
face 959, 991, 990
face 959, 990, 958
face 960, 992, 1023
face 960, 1023, 991
face 961, 993, 992
face 961, 992, 960
face 962, 994, 993
face 962, 993, 961
face 963, 995, 994
face 963, 994, 962
face 964, 996, 995
face 964, 995, 963
face 965, 997, 996
face 965, 996, 964
face 966, 998, 997
face 966, 997, 965
face 967, 999, 998
face 967, 998, 966
face 968, 1000, 999
face 968, 999, 967
face 969, 1001, 1000
face 969, 1000, 968
face 970, 1002, 1001
face 970, 1001, 969
face 971, 1003, 1002
face 971, 1002, 970
face 972, 1004, 1003
face 972, 1003, 971
face 973, 1005, 1004
face 973, 1004, 972
face 974, 1006, 1005
face 974, 1005, 973
face 975, 1007, 1006
face 975, 1006, 974
face 976, 1008, 1007
face 976, 1007, 975
face 977, 1009, 1008
face 977, 1008, 976
face 978, 1010, 1009
face 978, 1009, 977
face 979, 1011, 1010
face 979, 1010, 978
face 980, 1012, 1011
face 980, 1011, 979
face 981, 1013, 1012
face 981, 1012, 980
face 982, 1014, 1013
face 982, 1013, 981
face 983, 1015, 1014
face 983, 1014, 982
face 984, 1016, 1015
face 984, 1015, 983
face 985, 1017, 1016
face 985, 1016, 984
face 986, 1018, 1017
face 986, 1017, 985
face 987, 1019, 1018
face 987, 1018, 986
face 988, 1020, 1019
face 988, 1019, 987
face 989, 1021, 1020
face 989, 1020, 988
face 990, 1022, 1021
face 990, 1021, 989
face 991, 1023, 1022
face 991, 1022, 990
face 992, 1024, 1055
face 992, 1055, 1023
face 993, 1025, 1024
face 993, 1024, 992
face 994, 1026, 1025
face 994, 1025, 993
face 995, 1027, 1026
face 995, 1026, 994
face 996, 1028, 1027
face 996, 1027, 995
face 997, 1029, 1028
face 997, 1028, 996
face 998, 1030, 1029
face 998, 1029, 997
face 999, 1031, 1030
face 999, 1030, 998
face 1000, 1032, 1031
face 1000, 1031, 999
face 1001, 1033, 1032
face 1001, 1032, 1000
face 1002, 1034, 1033
face 1002, 1033, 1001
face 1003, 1035, 1034
face 1003, 1034, 1002
face 1004, 1036, 1035
face 1004, 1035, 1003
face 1005, 1037, 1036
face 1005, 1036, 1004
face 1006, 1038, 1037
face 1006, 1037, 1005
face 1007, 1039, 1038
face 1007, 1038, 1006
face 1008, 1040, 1039
face 1008, 1039, 1007
face 1009, 1041, 1040
face 1009, 1040, 1008
face 1010, 1042, 1041
face 1010, 1041, 1009
face 1011, 1043, 1042
face 1011, 1042, 1010
face 1012, 1044, 1043
face 1012, 1043, 1011
face 1013, 1045, 1044
face 1013, 1044, 1012
face 1014, 1046, 1045
face 1014, 1045, 1013
face 1015, 1047, 1046
face 1015, 1046, 1014
face 1016, 1048, 1047
face 1016, 1047, 1015
face 1017, 1049, 1048
face 1017, 1048, 1016
face 1018, 1050, 1049
face 1018, 1049, 1017
face 1019, 1051, 1050
face 1019, 1050, 1018
face 1020, 1052, 1051
face 1020, 1051, 1019
face 1021, 1053, 1052
face 1021, 1052, 1020
face 1022, 1054, 1053
face 1022, 1053, 1021
face 1023, 1055, 1054
face 1023, 1054, 1022
face 1024, 1056, 1087
face 1024, 1087, 1055
face 1025, 1057, 1056
face 1025, 1056, 1024
face 1026, 1058, 1057
face 1026, 1057, 1025
face 1027, 1059, 1058
face 1027, 1058, 1026
face 1028, 1060, 1059
face 1028, 1059, 1027
face 1029, 1061, 1060
face 1029, 1060, 1028
face 1030, 1062, 1061
face 1030, 1061, 1029
face 1031, 1063, 1062
face 1031, 1062, 1030
face 1032, 1064, 1063
face 1032, 1063, 1031
face 1033, 1065, 1064
face 1033, 1064, 1032
face 1034, 1066, 1065
face 1034, 1065, 1033
face 1035, 1067, 1066
face 1035, 1066, 1034
face 1036, 1068, 1067
face 1036, 1067, 1035
face 1037, 1069, 1068
face 1037, 1068, 1036
face 1038, 1070, 1069
face 1038, 1069, 1037
face 1039, 1071, 1070
face 1039, 1070, 1038
face 1040, 1072, 1071
face 1040, 1071, 1039
face 1041, 1073, 1072
face 1041, 1072, 1040
face 1042, 1074, 1073
face 1042, 1073, 1041
face 1043, 1075, 1074
face 1043, 1074, 1042
face 1044, 1076, 1075
face 1044, 1075, 1043
face 1045, 1077, 1076
face 1045, 1076, 1044
face 1046, 1078, 1077
face 1046, 1077, 1045
face 1047, 1079, 1078
face 1047, 1078, 1046
face 1048, 1080, 1079
face 1048, 1079, 1047
face 1049, 1081, 1080
face 1049, 1080, 1048
face 1050, 1082, 1081
face 1050, 1081, 1049
face 1051, 1083, 1082
face 1051, 1082, 1050
face 1052, 1084, 1083
face 1052, 1083, 1051
face 1053, 1085, 1084
face 1053, 1084, 1052
face 1054, 1086, 1085
face 1054, 1085, 1053
face 1055, 1087, 1086
face 1055, 1086, 1054
face 1056, 1088, 1119
face 1056, 1119, 1087
face 1057, 1089, 1088
face 1057, 1088, 1056
face 1058, 1090, 1089
face 1058, 1089, 1057
face 1059, 1091, 1090
face 1059, 1090, 1058
face 1060, 1092, 1091
face 1060, 1091, 1059
face 1061, 1093, 1092
face 1061, 1092, 1060
face 1062, 1094, 1093
face 1062, 1093, 1061
face 1063, 1095, 1094
face 1063, 1094, 1062
face 1064, 1096, 1095
face 1064, 1095, 1063
face 1065, 1097, 1096
face 1065, 1096, 1064
face 1066, 1098, 1097
face 1066, 1097, 1065
face 1067, 1099, 1098
face 1067, 1098, 1066
face 1068, 1100, 1099
face 1068, 1099, 1067
face 1069, 1101, 1100
face 1069, 1100, 1068
face 1070, 1102, 1101
face 1070, 1101, 1069
face 1071, 1103, 1102
face 1071, 1102, 1070
face 1072, 1104, 1103
face 1072, 1103, 1071
face 1073, 1105, 1104
face 1073, 1104, 1072
face 1074, 1106, 1105
face 1074, 1105, 1073
face 1075, 1107, 1106
face 1075, 1106, 1074
face 1076, 1108, 1107
face 1076, 1107, 1075
face 1077, 1109, 1108
face 1077, 1108, 1076
face 1078, 1110, 1109
face 1078, 1109, 1077
face 1079, 1111, 1110
face 1079, 1110, 1078
face 1080, 1112, 1111
face 1080, 1111, 1079
face 1081, 1113, 1112
face 1081, 1112, 1080
face 1082, 1114, 1113
face 1082, 1113, 1081
face 1083, 1115, 1114
face 1083, 1114, 1082
face 1084, 1116, 1115
face 1084, 1115, 1083
face 1085, 1117, 1116
face 1085, 1116, 1084
face 1086, 1118, 1117
face 1086, 1117, 1085
face 1087, 1119, 1118
face 1087, 1118, 1086
face 1088, 1120, 1151
face 1088, 1151, 1119
face 1089, 1121, 1120
face 1089, 1120, 1088
face 1090, 1122, 1121
face 1090, 1121, 1089
face 1091, 1123, 1122
face 1091, 1122, 1090
face 1092, 1124, 1123
face 1092, 1123, 1091
face 1093, 1125, 1124
face 1093, 1124, 1092
face 1094, 1126, 1125
face 1094, 1125, 1093
face 1095, 1127, 1126
face 1095, 1126, 1094
face 1096, 1128, 1127
face 1096, 1127, 1095
face 1097, 1129, 1128
face 1097, 1128, 1096
face 1098, 1130, 1129
face 1098, 1129, 1097
face 1099, 1131, 1130
face 1099, 1130, 1098
face 1100, 1132, 1131
face 1100, 1131, 1099
face 1101, 1133, 1132
face 1101, 1132, 1100
face 1102, 1134, 1133
face 1102, 1133, 1101
face 1103, 1135, 1134
face 1103, 1134, 1102
face 1104, 1136, 1135
face 1104, 1135, 1103
face 1105, 1137, 1136
face 1105, 1136, 1104
face 1106, 1138, 1137
face 1106, 1137, 1105
face 1107, 1139, 1138
face 1107, 1138, 1106
face 1108, 1140, 1139
face 1108, 1139, 1107
face 1109, 1141, 1140
face 1109, 1140, 1108
face 1110, 1142, 1141
face 1110, 1141, 1109
face 1111, 1143, 1142
face 1111, 1142, 1110
face 1112, 1144, 1143
face 1112, 1143, 1111
face 1113, 1145, 1144
face 1113, 1144, 1112
face 1114, 1146, 1145
face 1114, 1145, 1113
face 1115, 1147, 1146
face 1115, 1146, 1114
face 1116, 1148, 1147
face 1116, 1147, 1115
face 1117, 1149, 1148
face 1117, 1148, 1116
face 1118, 1150, 1149
face 1118, 1149, 1117
face 1119, 1151, 1150
face 1119, 1150, 1118
face 1120, 1152, 1183
face 1120, 1183, 1151
face 1121, 1153, 1152
face 1121, 1152, 1120
face 1122, 1154, 1153
face 1122, 1153, 1121
face 1123, 1155, 1154
face 1123, 1154, 1122
face 1124, 1156, 1155
face 1124, 1155, 1123
face 1125, 1157, 1156
face 1125, 1156, 1124
face 1126, 1158, 1157
face 1126, 1157, 1125
face 1127, 1159, 1158
face 1127, 1158, 1126
face 1128, 1160, 1159
face 1128, 1159, 1127
face 1129, 1161, 1160
face 1129, 1160, 1128
face 1130, 1162, 1161
face 1130, 1161, 1129
face 1131, 1163, 1162
face 1131, 1162, 1130
face 1132, 1164, 1163
face 1132, 1163, 1131
face 1133, 1165, 1164
face 1133, 1164, 1132
face 1134, 1166, 1165
face 1134, 1165, 1133
face 1135, 1167, 1166
face 1135, 1166, 1134
face 1136, 1168, 1167
face 1136, 1167, 1135
face 1137, 1169, 1168
face 1137, 1168, 1136
face 1138, 1170, 1169
face 1138, 1169, 1137
face 1139, 1171, 1170
face 1139, 1170, 1138
face 1140, 1172, 1171
face 1140, 1171, 1139
face 1141, 1173, 1172
face 1141, 1172, 1140
face 1142, 1174, 1173
face 1142, 1173, 1141
face 1143, 1175, 1174
face 1143, 1174, 1142
face 1144, 1176, 1175
face 1144, 1175, 1143
face 1145, 1177, 1176
face 1145, 1176, 1144
face 1146, 1178, 1177
face 1146, 1177, 1145
face 1147, 1179, 1178
face 1147, 1178, 1146
face 1148, 1180, 1179
face 1148, 1179, 1147
face 1149, 1181, 1180
face 1149, 1180, 1148
face 1150, 1182, 1181
face 1150, 1181, 1149
face 1151, 1183, 1182
face 1151, 1182, 1150
face 1152, 1184, 1215
face 1152, 1215, 1183
face 1153, 1185, 1184
face 1153, 1184, 1152
face 1154, 1186, 1185
face 1154, 1185, 1153
face 1155, 1187, 1186
face 1155, 1186, 1154
face 1156, 1188, 1187
face 1156, 1187, 1155
face 1157, 1189, 1188
face 1157, 1188, 1156
face 1158, 1190, 1189
face 1158, 1189, 1157
face 1159, 1191, 1190
face 1159, 1190, 1158
face 1160, 1192, 1191
face 1160, 1191, 1159
face 1161, 1193, 1192
face 1161, 1192, 1160
face 1162, 1194, 1193
face 1162, 1193, 1161
face 1163, 1195, 1194
face 1163, 1194, 1162
face 1164, 1196, 1195
face 1164, 1195, 1163
face 1165, 1197, 1196
face 1165, 1196, 1164
face 1166, 1198, 1197
face 1166, 1197, 1165
face 1167, 1199, 1198
face 1167, 1198, 1166
face 1168, 1200, 1199
face 1168, 1199, 1167
face 1169, 1201, 1200
face 1169, 1200, 1168
face 1170, 1202, 1201
face 1170, 1201, 1169
face 1171, 1203, 1202
face 1171, 1202, 1170
face 1172, 1204, 1203
face 1172, 1203, 1171
face 1173, 1205, 1204
face 1173, 1204, 1172
face 1174, 1206, 1205
face 1174, 1205, 1173
face 1175, 1207, 1206
face 1175, 1206, 1174
face 1176, 1208, 1207
face 1176, 1207, 1175
face 1177, 1209, 1208
face 1177, 1208, 1176
face 1178, 1210, 1209
face 1178, 1209, 1177
face 1179, 1211, 1210
face 1179, 1210, 1178
face 1180, 1212, 1211
face 1180, 1211, 1179
face 1181, 1213, 1212
face 1181, 1212, 1180
face 1182, 1214, 1213
face 1182, 1213, 1181
face 1183, 1215, 1214
face 1183, 1214, 1182
face 1184, 1216, 1247
face 1184, 1247, 1215
face 1185, 1217, 1216
face 1185, 1216, 1184
face 1186, 1218, 1217
face 1186, 1217, 1185
face 1187, 1219, 1218
face 1187, 1218, 1186
face 1188, 1220, 1219
face 1188, 1219, 1187
face 1189, 1221, 1220
face 1189, 1220, 1188
face 1190, 1222, 1221
face 1190, 1221, 1189
face 1191, 1223, 1222
face 1191, 1222, 1190
face 1192, 1224, 1223
face 1192, 1223, 1191
face 1193, 1225, 1224
face 1193, 1224, 1192
face 1194, 1226, 1225
face 1194, 1225, 1193
face 1195, 1227, 1226
face 1195, 1226, 1194
face 1196, 1228, 1227
face 1196, 1227, 1195
face 1197, 1229, 1228
face 1197, 1228, 1196
face 1198, 1230, 1229
face 1198, 1229, 1197
face 1199, 1231, 1230
face 1199, 1230, 1198
face 1200, 1232, 1231
face 1200, 1231, 1199
face 1201, 1233, 1232
face 1201, 1232, 1200
face 1202, 1234, 1233
face 1202, 1233, 1201
face 1203, 1235, 1234
face 1203, 1234, 1202
face 1204, 1236, 1235
face 1204, 1235, 1203
face 1205, 1237, 1236
face 1205, 1236, 1204
face 1206, 1238, 1237
face 1206, 1237, 1205
face 1207, 1239, 1238
face 1207, 1238, 1206
face 1208, 1240, 1239
face 1208, 1239, 1207
face 1209, 1241, 1240
face 1209, 1240, 1208
face 1210, 1242, 1241
face 1210, 1241, 1209
face 1211, 1243, 1242
face 1211, 1242, 1210
face 1212, 1244, 1243
face 1212, 1243, 1211
face 1213, 1245, 1244
face 1213, 1244, 1212
face 1214, 1246, 1245
face 1214, 1245, 1213
face 1215, 1247, 1246
face 1215, 1246, 1214
face 1216, 1248, 1279
face 1216, 1279, 1247
face 1217, 1249, 1248
face 1217, 1248, 1216
face 1218, 1250, 1249
face 1218, 1249, 1217
face 1219, 1251, 1250
face 1219, 1250, 1218
face 1220, 1252, 1251
face 1220, 1251, 1219
face 1221, 1253, 1252
face 1221, 1252, 1220
face 1222, 1254, 1253
face 1222, 1253, 1221
face 1223, 1255, 1254
face 1223, 1254, 1222
face 1224, 1256, 1255
face 1224, 1255, 1223
face 1225, 1257, 1256
face 1225, 1256, 1224
face 1226, 1258, 1257
face 1226, 1257, 1225
face 1227, 1259, 1258
face 1227, 1258, 1226
face 1228, 1260, 1259
face 1228, 1259, 1227
face 1229, 1261, 1260
face 1229, 1260, 1228
face 1230, 1262, 1261
face 1230, 1261, 1229
face 1231, 1263, 1262
face 1231, 1262, 1230
face 1232, 1264, 1263
face 1232, 1263, 1231
face 1233, 1265, 1264
face 1233, 1264, 1232
face 1234, 1266, 1265
face 1234, 1265, 1233
face 1235, 1267, 1266
face 1235, 1266, 1234
face 1236, 1268, 1267
face 1236, 1267, 1235
face 1237, 1269, 1268
face 1237, 1268, 1236
face 1238, 1270, 1269
face 1238, 1269, 1237
face 1239, 1271, 1270
face 1239, 1270, 1238
face 1240, 1272, 1271
face 1240, 1271, 1239
face 1241, 1273, 1272
face 1241, 1272, 1240
face 1242, 1274, 1273
face 1242, 1273, 1241
face 1243, 1275, 1274
face 1243, 1274, 1242
face 1244, 1276, 1275
face 1244, 1275, 1243
face 1245, 1277, 1276
face 1245, 1276, 1244
face 1246, 1278, 1277
face 1246, 1277, 1245
face 1247, 1279, 1278
face 1247, 1278, 1246
face 1248, 1280, 1311
face 1248, 1311, 1279
face 1249, 1281, 1280
face 1249, 1280, 1248
face 1250, 1282, 1281
face 1250, 1281, 1249
face 1251, 1283, 1282
face 1251, 1282, 1250
face 1252, 1284, 1283
face 1252, 1283, 1251
face 1253, 1285, 1284
face 1253, 1284, 1252
face 1254, 1286, 1285
face 1254, 1285, 1253
face 1255, 1287, 1286
face 1255, 1286, 1254
face 1256, 1288, 1287
face 1256, 1287, 1255
face 1257, 1289, 1288
face 1257, 1288, 1256
face 1258, 1290, 1289
face 1258, 1289, 1257
face 1259, 1291, 1290
face 1259, 1290, 1258
face 1260, 1292, 1291
face 1260, 1291, 1259
face 1261, 1293, 1292
face 1261, 1292, 1260
face 1262, 1294, 1293
face 1262, 1293, 1261
face 1263, 1295, 1294
face 1263, 1294, 1262
face 1264, 1296, 1295
face 1264, 1295, 1263
face 1265, 1297, 1296
face 1265, 1296, 1264
face 1266, 1298, 1297
face 1266, 1297, 1265
face 1267, 1299, 1298
face 1267, 1298, 1266
face 1268, 1300, 1299
face 1268, 1299, 1267
face 1269, 1301, 1300
face 1269, 1300, 1268
face 1270, 1302, 1301
face 1270, 1301, 1269
face 1271, 1303, 1302
face 1271, 1302, 1270
face 1272, 1304, 1303
face 1272, 1303, 1271
face 1273, 1305, 1304
face 1273, 1304, 1272
face 1274, 1306, 1305
face 1274, 1305, 1273
face 1275, 1307, 1306
face 1275, 1306, 1274
face 1276, 1308, 1307
face 1276, 1307, 1275
face 1277, 1309, 1308
face 1277, 1308, 1276
face 1278, 1310, 1309
face 1278, 1309, 1277
face 1279, 1311, 1310
face 1279, 1310, 1278
face 1280, 1312, 1343
face 1280, 1343, 1311
face 1281, 1313, 1312
face 1281, 1312, 1280
face 1282, 1314, 1313
face 1282, 1313, 1281
face 1283, 1315, 1314
face 1283, 1314, 1282
face 1284, 1316, 1315
face 1284, 1315, 1283
face 1285, 1317, 1316
face 1285, 1316, 1284
face 1286, 1318, 1317
face 1286, 1317, 1285
face 1287, 1319, 1318
face 1287, 1318, 1286
face 1288, 1320, 1319
face 1288, 1319, 1287
face 1289, 1321, 1320
face 1289, 1320, 1288
face 1290, 1322, 1321
face 1290, 1321, 1289
face 1291, 1323, 1322
face 1291, 1322, 1290
face 1292, 1324, 1323
face 1292, 1323, 1291
face 1293, 1325, 1324
face 1293, 1324, 1292
face 1294, 1326, 1325
face 1294, 1325, 1293
face 1295, 1327, 1326
face 1295, 1326, 1294
face 1296, 1328, 1327
face 1296, 1327, 1295
face 1297, 1329, 1328
face 1297, 1328, 1296
face 1298, 1330, 1329
face 1298, 1329, 1297
face 1299, 1331, 1330
face 1299, 1330, 1298
face 1300, 1332, 1331
face 1300, 1331, 1299
face 1301, 1333, 1332
face 1301, 1332, 1300
face 1302, 1334, 1333
face 1302, 1333, 1301
face 1303, 1335, 1334
face 1303, 1334, 1302
face 1304, 1336, 1335
face 1304, 1335, 1303
face 1305, 1337, 1336
face 1305, 1336, 1304
face 1306, 1338, 1337
face 1306, 1337, 1305
face 1307, 1339, 1338
face 1307, 1338, 1306
face 1308, 1340, 1339
face 1308, 1339, 1307
face 1309, 1341, 1340
face 1309, 1340, 1308
face 1310, 1342, 1341
face 1310, 1341, 1309
face 1311, 1343, 1342
face 1311, 1342, 1310
face 1312, 1344, 1375
face 1312, 1375, 1343
face 1313, 1345, 1344
face 1313, 1344, 1312
face 1314, 1346, 1345
face 1314, 1345, 1313
face 1315, 1347, 1346
face 1315, 1346, 1314
face 1316, 1348, 1347
face 1316, 1347, 1315
face 1317, 1349, 1348
face 1317, 1348, 1316
face 1318, 1350, 1349
face 1318, 1349, 1317
face 1319, 1351, 1350
face 1319, 1350, 1318
face 1320, 1352, 1351
face 1320, 1351, 1319
face 1321, 1353, 1352
face 1321, 1352, 1320
face 1322, 1354, 1353
face 1322, 1353, 1321
face 1323, 1355, 1354
face 1323, 1354, 1322
face 1324, 1356, 1355
face 1324, 1355, 1323
face 1325, 1357, 1356
face 1325, 1356, 1324
face 1326, 1358, 1357
face 1326, 1357, 1325
face 1327, 1359, 1358
face 1327, 1358, 1326
face 1328, 1360, 1359
face 1328, 1359, 1327
face 1329, 1361, 1360
face 1329, 1360, 1328
face 1330, 1362, 1361
face 1330, 1361, 1329
face 1331, 1363, 1362
face 1331, 1362, 1330
face 1332, 1364, 1363
face 1332, 1363, 1331
face 1333, 1365, 1364
face 1333, 1364, 1332
face 1334, 1366, 1365
face 1334, 1365, 1333
face 1335, 1367, 1366
face 1335, 1366, 1334
face 1336, 1368, 1367
face 1336, 1367, 1335
face 1337, 1369, 1368
face 1337, 1368, 1336
face 1338, 1370, 1369
face 1338, 1369, 1337
face 1339, 1371, 1370
face 1339, 1370, 1338
face 1340, 1372, 1371
face 1340, 1371, 1339
face 1341, 1373, 1372
face 1341, 1372, 1340
face 1342, 1374, 1373
face 1342, 1373, 1341
face 1343, 1375, 1374
face 1343, 1374, 1342
face 1344, 1376, 1407
face 1344, 1407, 1375
face 1345, 1377, 1376
face 1345, 1376, 1344
face 1346, 1378, 1377
face 1346, 1377, 1345
face 1347, 1379, 1378
face 1347, 1378, 1346
face 1348, 1380, 1379
face 1348, 1379, 1347
face 1349, 1381, 1380
face 1349, 1380, 1348
face 1350, 1382, 1381
face 1350, 1381, 1349
face 1351, 1383, 1382
face 1351, 1382, 1350
face 1352, 1384, 1383
face 1352, 1383, 1351
face 1353, 1385, 1384
face 1353, 1384, 1352
face 1354, 1386, 1385
face 1354, 1385, 1353
face 1355, 1387, 1386
face 1355, 1386, 1354
face 1356, 1388, 1387
face 1356, 1387, 1355
face 1357, 1389, 1388
face 1357, 1388, 1356
face 1358, 1390, 1389
face 1358, 1389, 1357
face 1359, 1391, 1390
face 1359, 1390, 1358
face 1360, 1392, 1391
face 1360, 1391, 1359
face 1361, 1393, 1392
face 1361, 1392, 1360
face 1362, 1394, 1393
face 1362, 1393, 1361
face 1363, 1395, 1394
face 1363, 1394, 1362
face 1364, 1396, 1395
face 1364, 1395, 1363
face 1365, 1397, 1396
face 1365, 1396, 1364
face 1366, 1398, 1397
face 1366, 1397, 1365
face 1367, 1399, 1398
face 1367, 1398, 1366
face 1368, 1400, 1399
face 1368, 1399, 1367
face 1369, 1401, 1400
face 1369, 1400, 1368
face 1370, 1402, 1401
face 1370, 1401, 1369
face 1371, 1403, 1402
face 1371, 1402, 1370
face 1372, 1404, 1403
face 1372, 1403, 1371
face 1373, 1405, 1404
face 1373, 1404, 1372
face 1374, 1406, 1405
face 1374, 1405, 1373
face 1375, 1407, 1406
face 1375, 1406, 1374
face 1376, 1408, 1439
face 1376, 1439, 1407
face 1377, 1409, 1408
face 1377, 1408, 1376
face 1378, 1410, 1409
face 1378, 1409, 1377
face 1379, 1411, 1410
face 1379, 1410, 1378
face 1380, 1412, 1411
face 1380, 1411, 1379
face 1381, 1413, 1412
face 1381, 1412, 1380
face 1382, 1414, 1413
face 1382, 1413, 1381
face 1383, 1415, 1414
face 1383, 1414, 1382
face 1384, 1416, 1415
face 1384, 1415, 1383
face 1385, 1417, 1416
face 1385, 1416, 1384
face 1386, 1418, 1417
face 1386, 1417, 1385
face 1387, 1419, 1418
face 1387, 1418, 1386
face 1388, 1420, 1419
face 1388, 1419, 1387
face 1389, 1421, 1420
face 1389, 1420, 1388
face 1390, 1422, 1421
face 1390, 1421, 1389
face 1391, 1423, 1422
face 1391, 1422, 1390
face 1392, 1424, 1423
face 1392, 1423, 1391
face 1393, 1425, 1424
face 1393, 1424, 1392
face 1394, 1426, 1425
face 1394, 1425, 1393
face 1395, 1427, 1426
face 1395, 1426, 1394
face 1396, 1428, 1427
face 1396, 1427, 1395
face 1397, 1429, 1428
face 1397, 1428, 1396
face 1398, 1430, 1429
face 1398, 1429, 1397
face 1399, 1431, 1430
face 1399, 1430, 1398
face 1400, 1432, 1431
face 1400, 1431, 1399
face 1401, 1433, 1432
face 1401, 1432, 1400
face 1402, 1434, 1433
face 1402, 1433, 1401
face 1403, 1435, 1434
face 1403, 1434, 1402
face 1404, 1436, 1435
face 1404, 1435, 1403
face 1405, 1437, 1436
face 1405, 1436, 1404
face 1406, 1438, 1437
face 1406, 1437, 1405
face 1407, 1439, 1438
face 1407, 1438, 1406
face 1408, 1440, 1471
face 1408, 1471, 1439
face 1409, 1441, 1440
face 1409, 1440, 1408
face 1410, 1442, 1441
face 1410, 1441, 1409
face 1411, 1443, 1442
face 1411, 1442, 1410
face 1412, 1444, 1443
face 1412, 1443, 1411
face 1413, 1445, 1444
face 1413, 1444, 1412
face 1414, 1446, 1445
face 1414, 1445, 1413
face 1415, 1447, 1446
face 1415, 1446, 1414
face 1416, 1448, 1447
face 1416, 1447, 1415
face 1417, 1449, 1448
face 1417, 1448, 1416
face 1418, 1450, 1449
face 1418, 1449, 1417
face 1419, 1451, 1450
face 1419, 1450, 1418
face 1420, 1452, 1451
face 1420, 1451, 1419
face 1421, 1453, 1452
face 1421, 1452, 1420
face 1422, 1454, 1453
face 1422, 1453, 1421
face 1423, 1455, 1454
face 1423, 1454, 1422
face 1424, 1456, 1455
face 1424, 1455, 1423
face 1425, 1457, 1456
face 1425, 1456, 1424
face 1426, 1458, 1457
face 1426, 1457, 1425
face 1427, 1459, 1458
face 1427, 1458, 1426
face 1428, 1460, 1459
face 1428, 1459, 1427
face 1429, 1461, 1460
face 1429, 1460, 1428
face 1430, 1462, 1461
face 1430, 1461, 1429
face 1431, 1463, 1462
face 1431, 1462, 1430
face 1432, 1464, 1463
face 1432, 1463, 1431
face 1433, 1465, 1464
face 1433, 1464, 1432
face 1434, 1466, 1465
face 1434, 1465, 1433
face 1435, 1467, 1466
face 1435, 1466, 1434
face 1436, 1468, 1467
face 1436, 1467, 1435
face 1437, 1469, 1468
face 1437, 1468, 1436
face 1438, 1470, 1469
face 1438, 1469, 1437
face 1439, 1471, 1470
face 1439, 1470, 1438
face 1440, 1472, 1503
face 1440, 1503, 1471
face 1441, 1473, 1472
face 1441, 1472, 1440
face 1442, 1474, 1473
face 1442, 1473, 1441
face 1443, 1475, 1474
face 1443, 1474, 1442
face 1444, 1476, 1475
face 1444, 1475, 1443
face 1445, 1477, 1476
face 1445, 1476, 1444
face 1446, 1478, 1477
face 1446, 1477, 1445
face 1447, 1479, 1478
face 1447, 1478, 1446
face 1448, 1480, 1479
face 1448, 1479, 1447
face 1449, 1481, 1480
face 1449, 1480, 1448
face 1450, 1482, 1481
face 1450, 1481, 1449
face 1451, 1483, 1482
face 1451, 1482, 1450
face 1452, 1484, 1483
face 1452, 1483, 1451
face 1453, 1485, 1484
face 1453, 1484, 1452
face 1454, 1486, 1485
face 1454, 1485, 1453
face 1455, 1487, 1486
face 1455, 1486, 1454
face 1456, 1488, 1487
face 1456, 1487, 1455
face 1457, 1489, 1488
face 1457, 1488, 1456
face 1458, 1490, 1489
face 1458, 1489, 1457
face 1459, 1491, 1490
face 1459, 1490, 1458
face 1460, 1492, 1491
face 1460, 1491, 1459
face 1461, 1493, 1492
face 1461, 1492, 1460
face 1462, 1494, 1493
face 1462, 1493, 1461
face 1463, 1495, 1494
face 1463, 1494, 1462
face 1464, 1496, 1495
face 1464, 1495, 1463
face 1465, 1497, 1496
face 1465, 1496, 1464
face 1466, 1498, 1497
face 1466, 1497, 1465
face 1467, 1499, 1498
face 1467, 1498, 1466
face 1468, 1500, 1499
face 1468, 1499, 1467
face 1469, 1501, 1500
face 1469, 1500, 1468
face 1470, 1502, 1501
face 1470, 1501, 1469
face 1471, 1503, 1502
face 1471, 1502, 1470
face 1472, 1504, 1535
face 1472, 1535, 1503
face 1473, 1505, 1504
face 1473, 1504, 1472
face 1474, 1506, 1505
face 1474, 1505, 1473
face 1475, 1507, 1506
face 1475, 1506, 1474
face 1476, 1508, 1507
face 1476, 1507, 1475
face 1477, 1509, 1508
face 1477, 1508, 1476
face 1478, 1510, 1509
face 1478, 1509, 1477
face 1479, 1511, 1510
face 1479, 1510, 1478
face 1480, 1512, 1511
face 1480, 1511, 1479
face 1481, 1513, 1512
face 1481, 1512, 1480
face 1482, 1514, 1513
face 1482, 1513, 1481
face 1483, 1515, 1514
face 1483, 1514, 1482
face 1484, 1516, 1515
face 1484, 1515, 1483
face 1485, 1517, 1516
face 1485, 1516, 1484
face 1486, 1518, 1517
face 1486, 1517, 1485
face 1487, 1519, 1518
face 1487, 1518, 1486
face 1488, 1520, 1519
face 1488, 1519, 1487
face 1489, 1521, 1520
face 1489, 1520, 1488
face 1490, 1522, 1521
face 1490, 1521, 1489
face 1491, 1523, 1522
face 1491, 1522, 1490
face 1492, 1524, 1523
face 1492, 1523, 1491
face 1493, 1525, 1524
face 1493, 1524, 1492
face 1494, 1526, 1525
face 1494, 1525, 1493
face 1495, 1527, 1526
face 1495, 1526, 1494
face 1496, 1528, 1527
face 1496, 1527, 1495
face 1497, 1529, 1528
face 1497, 1528, 1496
face 1498, 1530, 1529
face 1498, 1529, 1497
face 1499, 1531, 1530
face 1499, 1530, 1498
face 1500, 1532, 1531
face 1500, 1531, 1499
face 1501, 1533, 1532
face 1501, 1532, 1500
face 1502, 1534, 1533
face 1502, 1533, 1501
face 1503, 1535, 1534
face 1503, 1534, 1502
face 1536, 1568, 1599
face 1536, 1599, 1567
face 1568, 1536, 1537
face 1568, 1537, 1569
face 1538, 1570, 1569
face 1538, 1569, 1537
face 1539, 1571, 1570
face 1539, 1570, 1538
face 1540, 1572, 1571
face 1540, 1571, 1539
face 1541, 1573, 1572
face 1541, 1572, 1540
face 1542, 1574, 1573
face 1542, 1573, 1541
face 1543, 1575, 1574
face 1543, 1574, 1542
face 1544, 1576, 1575
face 1544, 1575, 1543
face 1545, 1577, 1576
face 1545, 1576, 1544
face 1546, 1578, 1577
face 1546, 1577, 1545
face 1547, 1579, 1578
face 1547, 1578, 1546
face 1548, 1580, 1579
face 1548, 1579, 1547
face 1549, 1581, 1580
face 1549, 1580, 1548
face 1550, 1582, 1581
face 1550, 1581, 1549
face 1551, 1583, 1582
face 1551, 1582, 1550
face 1552, 1584, 1583
face 1552, 1583, 1551
face 1553, 1585, 1584
face 1553, 1584, 1552
face 1554, 1586, 1585
face 1554, 1585, 1553
face 1555, 1587, 1586
face 1555, 1586, 1554
face 1556, 1588, 1587
face 1556, 1587, 1555
face 1557, 1589, 1588
face 1557, 1588, 1556
face 1558, 1590, 1589
face 1558, 1589, 1557
face 1559, 1591, 1590
face 1559, 1590, 1558
face 1560, 1592, 1591
face 1560, 1591, 1559
face 1561, 1593, 1592
face 1561, 1592, 1560
face 1562, 1594, 1593
face 1562, 1593, 1561
face 1563, 1595, 1594
face 1563, 1594, 1562
face 1564, 1596, 1595
face 1564, 1595, 1563
face 1565, 1597, 1596
face 1565, 1596, 1564
face 1566, 1598, 1597
face 1566, 1597, 1565
face 1567, 1599, 1598
face 1567, 1598, 1566
face 1568, 1600, 1631
face 1568, 1631, 1599
face 1569, 1601, 1600
face 1569, 1600, 1568
face 1570, 1602, 1601
face 1570, 1601, 1569
face 1571, 1603, 1602
face 1571, 1602, 1570
face 1572, 1604, 1603
face 1572, 1603, 1571
face 1573, 1605, 1604
face 1573, 1604, 1572
face 1574, 1606, 1605
face 1574, 1605, 1573
face 1575, 1607, 1606
face 1575, 1606, 1574
face 1576, 1608, 1607
face 1576, 1607, 1575
face 1577, 1609, 1608
face 1577, 1608, 1576
face 1578, 1610, 1609
face 1578, 1609, 1577
face 1579, 1611, 1610
face 1579, 1610, 1578
face 1580, 1612, 1611
face 1580, 1611, 1579
face 1581, 1613, 1612
face 1581, 1612, 1580
face 1582, 1614, 1613
face 1582, 1613, 1581
face 1583, 1615, 1614
face 1583, 1614, 1582
face 1584, 1616, 1615
face 1584, 1615, 1583
face 1585, 1617, 1616
face 1585, 1616, 1584
face 1586, 1618, 1617
face 1586, 1617, 1585
face 1587, 1619, 1618
face 1587, 1618, 1586
face 1588, 1620, 1619
face 1588, 1619, 1587
face 1589, 1621, 1620
face 1589, 1620, 1588
face 1590, 1622, 1621
face 1590, 1621, 1589
face 1591, 1623, 1622
face 1591, 1622, 1590
face 1592, 1624, 1623
face 1592, 1623, 1591
face 1593, 1625, 1624
face 1593, 1624, 1592
face 1594, 1626, 1625
face 1594, 1625, 1593
face 1595, 1627, 1626
face 1595, 1626, 1594
face 1596, 1628, 1627
face 1596, 1627, 1595
face 1597, 1629, 1628
face 1597, 1628, 1596
face 1598, 1630, 1629
face 1598, 1629, 1597
face 1599, 1631, 1630
face 1599, 1630, 1598
face 1600, 1632, 1663
face 1600, 1663, 1631
face 1601, 1633, 1632
face 1601, 1632, 1600
face 1602, 1634, 1633
face 1602, 1633, 1601
face 1603, 1635, 1634
face 1603, 1634, 1602
face 1604, 1636, 1635
face 1604, 1635, 1603
face 1605, 1637, 1636
face 1605, 1636, 1604
face 1606, 1638, 1637
face 1606, 1637, 1605
face 1607, 1639, 1638
face 1607, 1638, 1606
face 1608, 1640, 1639
face 1608, 1639, 1607
face 1609, 1641, 1640
face 1609, 1640, 1608
face 1610, 1642, 1641
face 1610, 1641, 1609
face 1611, 1643, 1642
face 1611, 1642, 1610
face 1612, 1644, 1643
face 1612, 1643, 1611
face 1613, 1645, 1644
face 1613, 1644, 1612
face 1614, 1646, 1645
face 1614, 1645, 1613
face 1615, 1647, 1646
face 1615, 1646, 1614
face 1616, 1648, 1647
face 1616, 1647, 1615
face 1617, 1649, 1648
face 1617, 1648, 1616
face 1618, 1650, 1649
face 1618, 1649, 1617
face 1619, 1651, 1650
face 1619, 1650, 1618
face 1620, 1652, 1651
face 1620, 1651, 1619
face 1621, 1653, 1652
face 1621, 1652, 1620
face 1622, 1654, 1653
face 1622, 1653, 1621
face 1623, 1655, 1654
face 1623, 1654, 1622
face 1624, 1656, 1655
face 1624, 1655, 1623
face 1625, 1657, 1656
face 1625, 1656, 1624
face 1626, 1658, 1657
face 1626, 1657, 1625
face 1627, 1659, 1658
face 1627, 1658, 1626
face 1628, 1660, 1659
face 1628, 1659, 1627
face 1629, 1661, 1660
face 1629, 1660, 1628
face 1630, 1662, 1661
face 1630, 1661, 1629
face 1631, 1663, 1662
face 1631, 1662, 1630
face 1632, 1664, 1695
face 1632, 1695, 1663
face 1633, 1665, 1664
face 1633, 1664, 1632
face 1634, 1666, 1665
face 1634, 1665, 1633
face 1635, 1667, 1666
face 1635, 1666, 1634
face 1636, 1668, 1667
face 1636, 1667, 1635
face 1637, 1669, 1668
face 1637, 1668, 1636
face 1638, 1670, 1669
face 1638, 1669, 1637
face 1639, 1671, 1670
face 1639, 1670, 1638
face 1640, 1672, 1671
face 1640, 1671, 1639
face 1641, 1673, 1672
face 1641, 1672, 1640
face 1642, 1674, 1673
face 1642, 1673, 1641
face 1643, 1675, 1674
face 1643, 1674, 1642
face 1644, 1676, 1675
face 1644, 1675, 1643
face 1645, 1677, 1676
face 1645, 1676, 1644
face 1646, 1678, 1677
face 1646, 1677, 1645
face 1647, 1679, 1678
face 1647, 1678, 1646
face 1648, 1680, 1679
face 1648, 1679, 1647
face 1649, 1681, 1680
face 1649, 1680, 1648
face 1650, 1682, 1681
face 1650, 1681, 1649
face 1651, 1683, 1682
face 1651, 1682, 1650
face 1652, 1684, 1683
face 1652, 1683, 1651
face 1653, 1685, 1684
face 1653, 1684, 1652
face 1654, 1686, 1685
face 1654, 1685, 1653
face 1655, 1687, 1686
face 1655, 1686, 1654
face 1656, 1688, 1687
face 1656, 1687, 1655
face 1657, 1689, 1688
face 1657, 1688, 1656
face 1658, 1690, 1689
face 1658, 1689, 1657
face 1659, 1691, 1690
face 1659, 1690, 1658
face 1660, 1692, 1691
face 1660, 1691, 1659
face 1661, 1693, 1692
face 1661, 1692, 1660
face 1662, 1694, 1693
face 1662, 1693, 1661
face 1663, 1695, 1694
face 1663, 1694, 1662
face 1664, 1696, 1727
face 1664, 1727, 1695
face 1665, 1697, 1696
face 1665, 1696, 1664
face 1666, 1698, 1697
face 1666, 1697, 1665
face 1667, 1699, 1698
face 1667, 1698, 1666
face 1668, 1700, 1699
face 1668, 1699, 1667
face 1669, 1701, 1700
face 1669, 1700, 1668
face 1670, 1702, 1701
face 1670, 1701, 1669
face 1671, 1703, 1702
face 1671, 1702, 1670
face 1672, 1704, 1703
face 1672, 1703, 1671
face 1673, 1705, 1704
face 1673, 1704, 1672
face 1674, 1706, 1705
face 1674, 1705, 1673
face 1675, 1707, 1706
face 1675, 1706, 1674
face 1676, 1708, 1707
face 1676, 1707, 1675
face 1677, 1709, 1708
face 1677, 1708, 1676
face 1678, 1710, 1709
face 1678, 1709, 1677
face 1679, 1711, 1710
face 1679, 1710, 1678
face 1680, 1712, 1711
face 1680, 1711, 1679
face 1681, 1713, 1712
face 1681, 1712, 1680
face 1682, 1714, 1713
face 1682, 1713, 1681
face 1683, 1715, 1714
face 1683, 1714, 1682
face 1684, 1716, 1715
face 1684, 1715, 1683
face 1685, 1717, 1716
face 1685, 1716, 1684
face 1686, 1718, 1717
face 1686, 1717, 1685
face 1687, 1719, 1718
face 1687, 1718, 1686
face 1688, 1720, 1719
face 1688, 1719, 1687
face 1689, 1721, 1720
face 1689, 1720, 1688
face 1690, 1722, 1721
face 1690, 1721, 1689
face 1691, 1723, 1722
face 1691, 1722, 1690
face 1692, 1724, 1723
face 1692, 1723, 1691
face 1693, 1725, 1724
face 1693, 1724, 1692
face 1694, 1726, 1725
face 1694, 1725, 1693
face 1695, 1727, 1726
face 1695, 1726, 1694
face 1696, 1728, 1759
face 1696, 1759, 1727
face 1697, 1729, 1728
face 1697, 1728, 1696
face 1698, 1730, 1729
face 1698, 1729, 1697
face 1699, 1731, 1730
face 1699, 1730, 1698
face 1700, 1732, 1731
face 1700, 1731, 1699
face 1701, 1733, 1732
face 1701, 1732, 1700
face 1702, 1734, 1733
face 1702, 1733, 1701
face 1703, 1735, 1734
face 1703, 1734, 1702
face 1704, 1736, 1735
face 1704, 1735, 1703
face 1705, 1737, 1736
face 1705, 1736, 1704
face 1706, 1738, 1737
face 1706, 1737, 1705
face 1707, 1739, 1738
face 1707, 1738, 1706
face 1708, 1740, 1739
face 1708, 1739, 1707
face 1709, 1741, 1740
face 1709, 1740, 1708
face 1710, 1742, 1741
face 1710, 1741, 1709
face 1711, 1743, 1742
face 1711, 1742, 1710
face 1712, 1744, 1743
face 1712, 1743, 1711
face 1713, 1745, 1744
face 1713, 1744, 1712
face 1714, 1746, 1745
face 1714, 1745, 1713
face 1715, 1747, 1746
face 1715, 1746, 1714
face 1716, 1748, 1747
face 1716, 1747, 1715
face 1717, 1749, 1748
face 1717, 1748, 1716
face 1718, 1750, 1749
face 1718, 1749, 1717
face 1719, 1751, 1750
face 1719, 1750, 1718
face 1720, 1752, 1751
face 1720, 1751, 1719
face 1721, 1753, 1752
face 1721, 1752, 1720
face 1722, 1754, 1753
face 1722, 1753, 1721
face 1723, 1755, 1754
face 1723, 1754, 1722
face 1724, 1756, 1755
face 1724, 1755, 1723
face 1725, 1757, 1756
face 1725, 1756, 1724
face 1726, 1758, 1757
face 1726, 1757, 1725
face 1727, 1759, 1758
face 1727, 1758, 1726
face 1728, 1760, 1791
face 1728, 1791, 1759
face 1729, 1761, 1760
face 1729, 1760, 1728
face 1730, 1762, 1761
face 1730, 1761, 1729
face 1731, 1763, 1762
face 1731, 1762, 1730
face 1732, 1764, 1763
face 1732, 1763, 1731
face 1733, 1765, 1764
face 1733, 1764, 1732
face 1734, 1766, 1765
face 1734, 1765, 1733
face 1735, 1767, 1766
face 1735, 1766, 1734
face 1736, 1768, 1767
face 1736, 1767, 1735
face 1737, 1769, 1768
face 1737, 1768, 1736
face 1738, 1770, 1769
face 1738, 1769, 1737
face 1739, 1771, 1770
face 1739, 1770, 1738
face 1740, 1772, 1771
face 1740, 1771, 1739
face 1741, 1773, 1772
face 1741, 1772, 1740
face 1742, 1774, 1773
face 1742, 1773, 1741
face 1743, 1775, 1774
face 1743, 1774, 1742
face 1744, 1776, 1775
face 1744, 1775, 1743
face 1745, 1777, 1776
face 1745, 1776, 1744
face 1746, 1778, 1777
face 1746, 1777, 1745
face 1747, 1779, 1778
face 1747, 1778, 1746
face 1748, 1780, 1779
face 1748, 1779, 1747
face 1749, 1781, 1780
face 1749, 1780, 1748
face 1750, 1782, 1781
face 1750, 1781, 1749
face 1751, 1783, 1782
face 1751, 1782, 1750
face 1752, 1784, 1783
face 1752, 1783, 1751
face 1753, 1785, 1784
face 1753, 1784, 1752
face 1754, 1786, 1785
face 1754, 1785, 1753
face 1755, 1787, 1786
face 1755, 1786, 1754
face 1756, 1788, 1787
face 1756, 1787, 1755
face 1757, 1789, 1788
face 1757, 1788, 1756
face 1758, 1790, 1789
face 1758, 1789, 1757
face 1759, 1791, 1790
face 1759, 1790, 1758
face 1760, 1792, 1823
face 1760, 1823, 1791
face 1761, 1793, 1792
face 1761, 1792, 1760
face 1762, 1794, 1793
face 1762, 1793, 1761
face 1763, 1795, 1794
face 1763, 1794, 1762
face 1764, 1796, 1795
face 1764, 1795, 1763
face 1765, 1797, 1796
face 1765, 1796, 1764
face 1766, 1798, 1797
face 1766, 1797, 1765
face 1767, 1799, 1798
face 1767, 1798, 1766
face 1768, 1800, 1799
face 1768, 1799, 1767
face 1769, 1801, 1800
face 1769, 1800, 1768
face 1770, 1802, 1801
face 1770, 1801, 1769
face 1771, 1803, 1802
face 1771, 1802, 1770
face 1772, 1804, 1803
face 1772, 1803, 1771
face 1773, 1805, 1804
face 1773, 1804, 1772
face 1774, 1806, 1805
face 1774, 1805, 1773
face 1775, 1807, 1806
face 1775, 1806, 1774
face 1776, 1808, 1807
face 1776, 1807, 1775
face 1777, 1809, 1808
face 1777, 1808, 1776
face 1778, 1810, 1809
face 1778, 1809, 1777
face 1779, 1811, 1810
face 1779, 1810, 1778
face 1780, 1812, 1811
face 1780, 1811, 1779
face 1781, 1813, 1812
face 1781, 1812, 1780
face 1782, 1814, 1813
face 1782, 1813, 1781
face 1783, 1815, 1814
face 1783, 1814, 1782
face 1784, 1816, 1815
face 1784, 1815, 1783
face 1785, 1817, 1816
face 1785, 1816, 1784
face 1786, 1818, 1817
face 1786, 1817, 1785
face 1787, 1819, 1818
face 1787, 1818, 1786
face 1788, 1820, 1819
face 1788, 1819, 1787
face 1789, 1821, 1820
face 1789, 1820, 1788
face 1790, 1822, 1821
face 1790, 1821, 1789
face 1791, 1823, 1822
face 1791, 1822, 1790
face 1792, 1824, 1855
face 1792, 1855, 1823
face 1793, 1825, 1824
face 1793, 1824, 1792
face 1794, 1826, 1825
face 1794, 1825, 1793
face 1795, 1827, 1826
face 1795, 1826, 1794
face 1796, 1828, 1827
face 1796, 1827, 1795
face 1797, 1829, 1828
face 1797, 1828, 1796
face 1798, 1830, 1829
face 1798, 1829, 1797
face 1799, 1831, 1830
face 1799, 1830, 1798
face 1800, 1832, 1831
face 1800, 1831, 1799
face 1801, 1833, 1832
face 1801, 1832, 1800
face 1802, 1834, 1833
face 1802, 1833, 1801
face 1803, 1835, 1834
face 1803, 1834, 1802
face 1804, 1836, 1835
face 1804, 1835, 1803
face 1805, 1837, 1836
face 1805, 1836, 1804
face 1806, 1838, 1837
face 1806, 1837, 1805
face 1807, 1839, 1838
face 1807, 1838, 1806
face 1808, 1840, 1839
face 1808, 1839, 1807
face 1809, 1841, 1840
face 1809, 1840, 1808
face 1810, 1842, 1841
face 1810, 1841, 1809
face 1811, 1843, 1842
face 1811, 1842, 1810
face 1812, 1844, 1843
face 1812, 1843, 1811
face 1813, 1845, 1844
face 1813, 1844, 1812
face 1814, 1846, 1845
face 1814, 1845, 1813
face 1815, 1847, 1846
face 1815, 1846, 1814
face 1816, 1848, 1847
face 1816, 1847, 1815
face 1817, 1849, 1848
face 1817, 1848, 1816
face 1818, 1850, 1849
face 1818, 1849, 1817
face 1819, 1851, 1850
face 1819, 1850, 1818
face 1820, 1852, 1851
face 1820, 1851, 1819
face 1821, 1853, 1852
face 1821, 1852, 1820
face 1822, 1854, 1853
face 1822, 1853, 1821
face 1823, 1855, 1854
face 1823, 1854, 1822
face 1824, 1856, 1887
face 1824, 1887, 1855
face 1825, 1857, 1856
face 1825, 1856, 1824
face 1826, 1858, 1857
face 1826, 1857, 1825
face 1827, 1859, 1858
face 1827, 1858, 1826
face 1828, 1860, 1859
face 1828, 1859, 1827
face 1829, 1861, 1860
face 1829, 1860, 1828
face 1830, 1862, 1861
face 1830, 1861, 1829
face 1831, 1863, 1862
face 1831, 1862, 1830
face 1832, 1864, 1863
face 1832, 1863, 1831
face 1833, 1865, 1864
face 1833, 1864, 1832
face 1834, 1866, 1865
face 1834, 1865, 1833
face 1835, 1867, 1866
face 1835, 1866, 1834
face 1836, 1868, 1867
face 1836, 1867, 1835
face 1837, 1869, 1868
face 1837, 1868, 1836
face 1838, 1870, 1869
face 1838, 1869, 1837
face 1839, 1871, 1870
face 1839, 1870, 1838
face 1840, 1872, 1871
face 1840, 1871, 1839
face 1841, 1873, 1872
face 1841, 1872, 1840
face 1842, 1874, 1873
face 1842, 1873, 1841
face 1843, 1875, 1874
face 1843, 1874, 1842
face 1844, 1876, 1875
face 1844, 1875, 1843
face 1845, 1877, 1876
face 1845, 1876, 1844
face 1846, 1878, 1877
face 1846, 1877, 1845
face 1847, 1879, 1878
face 1847, 1878, 1846
face 1848, 1880, 1879
face 1848, 1879, 1847
face 1849, 1881, 1880
face 1849, 1880, 1848
face 1850, 1882, 1881
face 1850, 1881, 1849
face 1851, 1883, 1882
face 1851, 1882, 1850
face 1852, 1884, 1883
face 1852, 1883, 1851
face 1853, 1885, 1884
face 1853, 1884, 1852
face 1854, 1886, 1885
face 1854, 1885, 1853
face 1855, 1887, 1886
face 1855, 1886, 1854
face 1856, 1888, 1919
face 1856, 1919, 1887
face 1857, 1889, 1888
face 1857, 1888, 1856
face 1858, 1890, 1889
face 1858, 1889, 1857
face 1859, 1891, 1890
face 1859, 1890, 1858
face 1860, 1892, 1891
face 1860, 1891, 1859
face 1861, 1893, 1892
face 1861, 1892, 1860
face 1862, 1894, 1893
face 1862, 1893, 1861
face 1863, 1895, 1894
face 1863, 1894, 1862
face 1864, 1896, 1895
face 1864, 1895, 1863
face 1865, 1897, 1896
face 1865, 1896, 1864
face 1866, 1898, 1897
face 1866, 1897, 1865
face 1867, 1899, 1898
face 1867, 1898, 1866
face 1868, 1900, 1899
face 1868, 1899, 1867
face 1869, 1901, 1900
face 1869, 1900, 1868
face 1870, 1902, 1901
face 1870, 1901, 1869
face 1871, 1903, 1902
face 1871, 1902, 1870
face 1872, 1904, 1903
face 1872, 1903, 1871
face 1873, 1905, 1904
face 1873, 1904, 1872
face 1874, 1906, 1905
face 1874, 1905, 1873
face 1875, 1907, 1906
face 1875, 1906, 1874
face 1876, 1908, 1907
face 1876, 1907, 1875
face 1877, 1909, 1908
face 1877, 1908, 1876
face 1878, 1910, 1909
face 1878, 1909, 1877
face 1879, 1911, 1910
face 1879, 1910, 1878
face 1880, 1912, 1911
face 1880, 1911, 1879
face 1881, 1913, 1912
face 1881, 1912, 1880
face 1882, 1914, 1913
face 1882, 1913, 1881
face 1883, 1915, 1914
face 1883, 1914, 1882
face 1884, 1916, 1915
face 1884, 1915, 1883
face 1885, 1917, 1916
face 1885, 1916, 1884
face 1886, 1918, 1917
face 1886, 1917, 1885
face 1887, 1919, 1918
face 1887, 1918, 1886
face 1888, 1920, 1951
face 1888, 1951, 1919
face 1889, 1921, 1920
face 1889, 1920, 1888
face 1890, 1922, 1921
face 1890, 1921, 1889
face 1891, 1923, 1922
face 1891, 1922, 1890
face 1892, 1924, 1923
face 1892, 1923, 1891
face 1893, 1925, 1924
face 1893, 1924, 1892
face 1894, 1926, 1925
face 1894, 1925, 1893
face 1895, 1927, 1926
face 1895, 1926, 1894
face 1896, 1928, 1927
face 1896, 1927, 1895
face 1897, 1929, 1928
face 1897, 1928, 1896
face 1898, 1930, 1929
face 1898, 1929, 1897
face 1899, 1931, 1930
face 1899, 1930, 1898
face 1900, 1932, 1931
face 1900, 1931, 1899
face 1901, 1933, 1932
face 1901, 1932, 1900
face 1902, 1934, 1933
face 1902, 1933, 1901
face 1903, 1935, 1934
face 1903, 1934, 1902
face 1904, 1936, 1935
face 1904, 1935, 1903
face 1905, 1937, 1936
face 1905, 1936, 1904
face 1906, 1938, 1937
face 1906, 1937, 1905
face 1907, 1939, 1938
face 1907, 1938, 1906
face 1908, 1940, 1939
face 1908, 1939, 1907
face 1909, 1941, 1940
face 1909, 1940, 1908
face 1910, 1942, 1941
face 1910, 1941, 1909
face 1911, 1943, 1942
face 1911, 1942, 1910
face 1912, 1944, 1943
face 1912, 1943, 1911
face 1913, 1945, 1944
face 1913, 1944, 1912
face 1914, 1946, 1945
face 1914, 1945, 1913
face 1915, 1947, 1946
face 1915, 1946, 1914
face 1916, 1948, 1947
face 1916, 1947, 1915
face 1917, 1949, 1948
face 1917, 1948, 1916
face 1918, 1950, 1949
face 1918, 1949, 1917
face 1919, 1951, 1950
face 1919, 1950, 1918
face 1920, 1952, 1983
face 1920, 1983, 1951
face 1921, 1953, 1952
face 1921, 1952, 1920
face 1922, 1954, 1953
face 1922, 1953, 1921
face 1923, 1955, 1954
face 1923, 1954, 1922
face 1924, 1956, 1955
face 1924, 1955, 1923
face 1925, 1957, 1956
face 1925, 1956, 1924
face 1926, 1958, 1957
face 1926, 1957, 1925
face 1927, 1959, 1958
face 1927, 1958, 1926
face 1928, 1960, 1959
face 1928, 1959, 1927
face 1929, 1961, 1960
face 1929, 1960, 1928
face 1930, 1962, 1961
face 1930, 1961, 1929
face 1931, 1963, 1962
face 1931, 1962, 1930
face 1932, 1964, 1963
face 1932, 1963, 1931
face 1933, 1965, 1964
face 1933, 1964, 1932
face 1934, 1966, 1965
face 1934, 1965, 1933
face 1935, 1967, 1966
face 1935, 1966, 1934
face 1936, 1968, 1967
face 1936, 1967, 1935
face 1937, 1969, 1968
face 1937, 1968, 1936
face 1938, 1970, 1969
face 1938, 1969, 1937
face 1939, 1971, 1970
face 1939, 1970, 1938
face 1940, 1972, 1971
face 1940, 1971, 1939
face 1941, 1973, 1972
face 1941, 1972, 1940
face 1942, 1974, 1973
face 1942, 1973, 1941
face 1943, 1975, 1974
face 1943, 1974, 1942
face 1944, 1976, 1975
face 1944, 1975, 1943
face 1945, 1977, 1976
face 1945, 1976, 1944
face 1946, 1978, 1977
face 1946, 1977, 1945
face 1947, 1979, 1978
face 1947, 1978, 1946
face 1948, 1980, 1979
face 1948, 1979, 1947
face 1949, 1981, 1980
face 1949, 1980, 1948
face 1950, 1982, 1981
face 1950, 1981, 1949
face 1951, 1983, 1982
face 1951, 1982, 1950
face 1952, 1984, 2015
face 1952, 2015, 1983
face 1953, 1985, 1984
face 1953, 1984, 1952
face 1954, 1986, 1985
face 1954, 1985, 1953
face 1955, 1987, 1986
face 1955, 1986, 1954
face 1956, 1988, 1987
face 1956, 1987, 1955
face 1957, 1989, 1988
face 1957, 1988, 1956
face 1958, 1990, 1989
face 1958, 1989, 1957
face 1959, 1991, 1990
face 1959, 1990, 1958
face 1960, 1992, 1991
face 1960, 1991, 1959
face 1961, 1993, 1992
face 1961, 1992, 1960
face 1962, 1994, 1993
face 1962, 1993, 1961
face 1963, 1995, 1994
face 1963, 1994, 1962
face 1964, 1996, 1995
face 1964, 1995, 1963
face 1965, 1997, 1996
face 1965, 1996, 1964
face 1966, 1998, 1997
face 1966, 1997, 1965
face 1967, 1999, 1998
face 1967, 1998, 1966
face 1968, 2000, 1999
face 1968, 1999, 1967
face 1969, 2001, 2000
face 1969, 2000, 1968
face 1970, 2002, 2001
face 1970, 2001, 1969
face 1971, 2003, 2002
face 1971, 2002, 1970
face 1972, 2004, 2003
face 1972, 2003, 1971
face 1973, 2005, 2004
face 1973, 2004, 1972
face 1974, 2006, 2005
face 1974, 2005, 1973
face 1975, 2007, 2006
face 1975, 2006, 1974
face 1976, 2008, 2007
face 1976, 2007, 1975
face 1977, 2009, 2008
face 1977, 2008, 1976
face 1978, 2010, 2009
face 1978, 2009, 1977
face 1979, 2011, 2010
face 1979, 2010, 1978
face 1980, 2012, 2011
face 1980, 2011, 1979
face 1981, 2013, 2012
face 1981, 2012, 1980
face 1982, 2014, 2013
face 1982, 2013, 1981
face 1983, 2015, 2014
face 1983, 2014, 1982
face 1984, 2016, 2047
face 1984, 2047, 2015
face 1985, 2017, 2016
face 1985, 2016, 1984
face 1986, 2018, 2017
face 1986, 2017, 1985
face 1987, 2019, 2018
face 1987, 2018, 1986
face 1988, 2020, 2019
face 1988, 2019, 1987
face 1989, 2021, 2020
face 1989, 2020, 1988
face 1990, 2022, 2021
face 1990, 2021, 1989
face 1991, 2023, 2022
face 1991, 2022, 1990
face 1992, 2024, 2023
face 1992, 2023, 1991
face 1993, 2025, 2024
face 1993, 2024, 1992
face 1994, 2026, 2025
face 1994, 2025, 1993
face 1995, 2027, 2026
face 1995, 2026, 1994
face 1996, 2028, 2027
face 1996, 2027, 1995
face 1997, 2029, 2028
face 1997, 2028, 1996
face 1998, 2030, 2029
face 1998, 2029, 1997
face 1999, 2031, 2030
face 1999, 2030, 1998
face 2000, 2032, 2031
face 2000, 2031, 1999
face 2001, 2033, 2032
face 2001, 2032, 2000
face 2002, 2034, 2033
face 2002, 2033, 2001
face 2003, 2035, 2034
face 2003, 2034, 2002
face 2004, 2036, 2035
face 2004, 2035, 2003
face 2005, 2037, 2036
face 2005, 2036, 2004
face 2006, 2038, 2037
face 2006, 2037, 2005
face 2007, 2039, 2038
face 2007, 2038, 2006
face 2008, 2040, 2039
face 2008, 2039, 2007
face 2009, 2041, 2040
face 2009, 2040, 2008
face 2010, 2042, 2041
face 2010, 2041, 2009
face 2011, 2043, 2042
face 2011, 2042, 2010
face 2012, 2044, 2043
face 2012, 2043, 2011
face 2013, 2045, 2044
face 2013, 2044, 2012
face 2014, 2046, 2045
face 2014, 2045, 2013
face 2015, 2047, 2046
face 2015, 2046, 2014
face 2016, 2048, 2079
face 2016, 2079, 2047
face 2017, 2049, 2048
face 2017, 2048, 2016
face 2018, 2050, 2049
face 2018, 2049, 2017
face 2019, 2051, 2050
face 2019, 2050, 2018
face 2020, 2052, 2051
face 2020, 2051, 2019
face 2021, 2053, 2052
face 2021, 2052, 2020
face 2022, 2054, 2053
face 2022, 2053, 2021
face 2023, 2055, 2054
face 2023, 2054, 2022
face 2024, 2056, 2055
face 2024, 2055, 2023
face 2025, 2057, 2056
face 2025, 2056, 2024
face 2026, 2058, 2057
face 2026, 2057, 2025
face 2027, 2059, 2058
face 2027, 2058, 2026
face 2028, 2060, 2059
face 2028, 2059, 2027
face 2029, 2061, 2060
face 2029, 2060, 2028
face 2030, 2062, 2061
face 2030, 2061, 2029
face 2031, 2063, 2062
face 2031, 2062, 2030
face 2032, 2064, 2063
face 2032, 2063, 2031
face 2033, 2065, 2064
face 2033, 2064, 2032
face 2034, 2066, 2065
face 2034, 2065, 2033
face 2035, 2067, 2066
face 2035, 2066, 2034
face 2036, 2068, 2067
face 2036, 2067, 2035
face 2037, 2069, 2068
face 2037, 2068, 2036
face 2038, 2070, 2069
face 2038, 2069, 2037
face 2039, 2071, 2070
face 2039, 2070, 2038
face 2040, 2072, 2071
face 2040, 2071, 2039
face 2041, 2073, 2072
face 2041, 2072, 2040
face 2042, 2074, 2073
face 2042, 2073, 2041
face 2043, 2075, 2074
face 2043, 2074, 2042
face 2044, 2076, 2075
face 2044, 2075, 2043
face 2045, 2077, 2076
face 2045, 2076, 2044
face 2046, 2078, 2077
face 2046, 2077, 2045
face 2047, 2079, 2078
face 2047, 2078, 2046
face 2048, 2080, 2111
face 2048, 2111, 2079
face 2049, 2081, 2080
face 2049, 2080, 2048
face 2050, 2082, 2081
face 2050, 2081, 2049
face 2051, 2083, 2082
face 2051, 2082, 2050
face 2052, 2084, 2083
face 2052, 2083, 2051
face 2053, 2085, 2084
face 2053, 2084, 2052
face 2054, 2086, 2085
face 2054, 2085, 2053
face 2055, 2087, 2086
face 2055, 2086, 2054
face 2056, 2088, 2087
face 2056, 2087, 2055
face 2057, 2089, 2088
face 2057, 2088, 2056
face 2058, 2090, 2089
face 2058, 2089, 2057
face 2059, 2091, 2090
face 2059, 2090, 2058
face 2060, 2092, 2091
face 2060, 2091, 2059
face 2061, 2093, 2092
face 2061, 2092, 2060
face 2062, 2094, 2093
face 2062, 2093, 2061
face 2063, 2095, 2094
face 2063, 2094, 2062
face 2064, 2096, 2095
face 2064, 2095, 2063
face 2065, 2097, 2096
face 2065, 2096, 2064
face 2066, 2098, 2097
face 2066, 2097, 2065
face 2067, 2099, 2098
face 2067, 2098, 2066
face 2068, 2100, 2099
face 2068, 2099, 2067
face 2069, 2101, 2100
face 2069, 2100, 2068
face 2070, 2102, 2101
face 2070, 2101, 2069
face 2071, 2103, 2102
face 2071, 2102, 2070
face 2072, 2104, 2103
face 2072, 2103, 2071
face 2073, 2105, 2104
face 2073, 2104, 2072
face 2074, 2106, 2105
face 2074, 2105, 2073
face 2075, 2107, 2106
face 2075, 2106, 2074
face 2076, 2108, 2107
face 2076, 2107, 2075
face 2077, 2109, 2108
face 2077, 2108, 2076
face 2078, 2110, 2109
face 2078, 2109, 2077
face 2079, 2111, 2110
face 2079, 2110, 2078
face 2080, 2112, 2143
face 2080, 2143, 2111
face 2081, 2113, 2112
face 2081, 2112, 2080
face 2082, 2114, 2113
face 2082, 2113, 2081
face 2083, 2115, 2114
face 2083, 2114, 2082
face 2084, 2116, 2115
face 2084, 2115, 2083
face 2085, 2117, 2116
face 2085, 2116, 2084
face 2086, 2118, 2117
face 2086, 2117, 2085
face 2087, 2119, 2118
face 2087, 2118, 2086
face 2088, 2120, 2119
face 2088, 2119, 2087
face 2089, 2121, 2120
face 2089, 2120, 2088
face 2090, 2122, 2121
face 2090, 2121, 2089
face 2091, 2123, 2122
face 2091, 2122, 2090
face 2092, 2124, 2123
face 2092, 2123, 2091
face 2093, 2125, 2124
face 2093, 2124, 2092
face 2094, 2126, 2125
face 2094, 2125, 2093
face 2095, 2127, 2126
face 2095, 2126, 2094
face 2096, 2128, 2127
face 2096, 2127, 2095
face 2097, 2129, 2128
face 2097, 2128, 2096
face 2098, 2130, 2129
face 2098, 2129, 2097
face 2099, 2131, 2130
face 2099, 2130, 2098
face 2100, 2132, 2131
face 2100, 2131, 2099
face 2101, 2133, 2132
face 2101, 2132, 2100
face 2102, 2134, 2133
face 2102, 2133, 2101
face 2103, 2135, 2134
face 2103, 2134, 2102
face 2104, 2136, 2135
face 2104, 2135, 2103
face 2105, 2137, 2136
face 2105, 2136, 2104
face 2106, 2138, 2137
face 2106, 2137, 2105
face 2107, 2139, 2138
face 2107, 2138, 2106
face 2108, 2140, 2139
face 2108, 2139, 2107
face 2109, 2141, 2140
face 2109, 2140, 2108
face 2110, 2142, 2141
face 2110, 2141, 2109
face 2111, 2143, 2142
face 2111, 2142, 2110
face 2112, 2144, 2175
face 2112, 2175, 2143
face 2113, 2145, 2144
face 2113, 2144, 2112
face 2114, 2146, 2145
face 2114, 2145, 2113
face 2115, 2147, 2146
face 2115, 2146, 2114
face 2116, 2148, 2147
face 2116, 2147, 2115
face 2117, 2149, 2148
face 2117, 2148, 2116
face 2118, 2150, 2149
face 2118, 2149, 2117
face 2119, 2151, 2150
face 2119, 2150, 2118
face 2120, 2152, 2151
face 2120, 2151, 2119
face 2121, 2153, 2152
face 2121, 2152, 2120
face 2122, 2154, 2153
face 2122, 2153, 2121
face 2123, 2155, 2154
face 2123, 2154, 2122
face 2124, 2156, 2155
face 2124, 2155, 2123
face 2125, 2157, 2156
face 2125, 2156, 2124
face 2126, 2158, 2157
face 2126, 2157, 2125
face 2127, 2159, 2158
face 2127, 2158, 2126
face 2128, 2160, 2159
face 2128, 2159, 2127
face 2129, 2161, 2160
face 2129, 2160, 2128
face 2130, 2162, 2161
face 2130, 2161, 2129
face 2131, 2163, 2162
face 2131, 2162, 2130
face 2132, 2164, 2163
face 2132, 2163, 2131
face 2133, 2165, 2164
face 2133, 2164, 2132
face 2134, 2166, 2165
face 2134, 2165, 2133
face 2135, 2167, 2166
face 2135, 2166, 2134
face 2136, 2168, 2167
face 2136, 2167, 2135
face 2137, 2169, 2168
face 2137, 2168, 2136
face 2138, 2170, 2169
face 2138, 2169, 2137
face 2139, 2171, 2170
face 2139, 2170, 2138
face 2140, 2172, 2171
face 2140, 2171, 2139
face 2141, 2173, 2172
face 2141, 2172, 2140
face 2142, 2174, 2173
face 2142, 2173, 2141
face 2143, 2175, 2174
face 2143, 2174, 2142
face 2144, 2176, 2207
face 2144, 2207, 2175
face 2145, 2177, 2176
face 2145, 2176, 2144
face 2146, 2178, 2177
face 2146, 2177, 2145
face 2147, 2179, 2178
face 2147, 2178, 2146
face 2148, 2180, 2179
face 2148, 2179, 2147
face 2149, 2181, 2180
face 2149, 2180, 2148
face 2150, 2182, 2181
face 2150, 2181, 2149
face 2151, 2183, 2182
face 2151, 2182, 2150
face 2152, 2184, 2183
face 2152, 2183, 2151
face 2153, 2185, 2184
face 2153, 2184, 2152
face 2154, 2186, 2185
face 2154, 2185, 2153
face 2155, 2187, 2186
face 2155, 2186, 2154
face 2156, 2188, 2187
face 2156, 2187, 2155
face 2157, 2189, 2188
face 2157, 2188, 2156
face 2158, 2190, 2189
face 2158, 2189, 2157
face 2159, 2191, 2190
face 2159, 2190, 2158
face 2160, 2192, 2191
face 2160, 2191, 2159
face 2161, 2193, 2192
face 2161, 2192, 2160
face 2162, 2194, 2193
face 2162, 2193, 2161
face 2163, 2195, 2194
face 2163, 2194, 2162
face 2164, 2196, 2195
face 2164, 2195, 2163
face 2165, 2197, 2196
face 2165, 2196, 2164
face 2166, 2198, 2197
face 2166, 2197, 2165
face 2167, 2199, 2198
face 2167, 2198, 2166
face 2168, 2200, 2199
face 2168, 2199, 2167
face 2169, 2201, 2200
face 2169, 2200, 2168
face 2170, 2202, 2201
face 2170, 2201, 2169
face 2171, 2203, 2202
face 2171, 2202, 2170
face 2172, 2204, 2203
face 2172, 2203, 2171
face 2173, 2205, 2204
face 2173, 2204, 2172
face 2174, 2206, 2205
face 2174, 2205, 2173
face 2175, 2207, 2206
face 2175, 2206, 2174
face 2176, 2208, 2239
face 2176, 2239, 2207
face 2177, 2209, 2208
face 2177, 2208, 2176
face 2178, 2210, 2209
face 2178, 2209, 2177
face 2179, 2211, 2210
face 2179, 2210, 2178
face 2180, 2212, 2211
face 2180, 2211, 2179
face 2181, 2213, 2212
face 2181, 2212, 2180
face 2182, 2214, 2213
face 2182, 2213, 2181
face 2183, 2215, 2214
face 2183, 2214, 2182
face 2184, 2216, 2215
face 2184, 2215, 2183
face 2185, 2217, 2216
face 2185, 2216, 2184
face 2186, 2218, 2217
face 2186, 2217, 2185
face 2187, 2219, 2218
face 2187, 2218, 2186
face 2188, 2220, 2219
face 2188, 2219, 2187
face 2189, 2221, 2220
face 2189, 2220, 2188
face 2190, 2222, 2221
face 2190, 2221, 2189
face 2191, 2223, 2222
face 2191, 2222, 2190
face 2192, 2224, 2223
face 2192, 2223, 2191
face 2193, 2225, 2224
face 2193, 2224, 2192
face 2194, 2226, 2225
face 2194, 2225, 2193
face 2195, 2227, 2226
face 2195, 2226, 2194
face 2196, 2228, 2227
face 2196, 2227, 2195
face 2197, 2229, 2228
face 2197, 2228, 2196
face 2198, 2230, 2229
face 2198, 2229, 2197
face 2199, 2231, 2230
face 2199, 2230, 2198
face 2200, 2232, 2231
face 2200, 2231, 2199
face 2201, 2233, 2232
face 2201, 2232, 2200
face 2202, 2234, 2233
face 2202, 2233, 2201
face 2203, 2235, 2234
face 2203, 2234, 2202
face 2204, 2236, 2235
face 2204, 2235, 2203
face 2205, 2237, 2236
face 2205, 2236, 2204
face 2206, 2238, 2237
face 2206, 2237, 2205
face 2207, 2239, 2238
face 2207, 2238, 2206
face 2208, 2240, 2271
face 2208, 2271, 2239
face 2209, 2241, 2240
face 2209, 2240, 2208
face 2210, 2242, 2241
face 2210, 2241, 2209
face 2211, 2243, 2242
face 2211, 2242, 2210
face 2212, 2244, 2243
face 2212, 2243, 2211
face 2213, 2245, 2244
face 2213, 2244, 2212
face 2214, 2246, 2245
face 2214, 2245, 2213
face 2215, 2247, 2246
face 2215, 2246, 2214
face 2216, 2248, 2247
face 2216, 2247, 2215
face 2217, 2249, 2248
face 2217, 2248, 2216
face 2218, 2250, 2249
face 2218, 2249, 2217
face 2219, 2251, 2250
face 2219, 2250, 2218
face 2220, 2252, 2251
face 2220, 2251, 2219
face 2221, 2253, 2252
face 2221, 2252, 2220
face 2222, 2254, 2253
face 2222, 2253, 2221
face 2223, 2255, 2254
face 2223, 2254, 2222
face 2224, 2256, 2255
face 2224, 2255, 2223
face 2225, 2257, 2256
face 2225, 2256, 2224
face 2226, 2258, 2257
face 2226, 2257, 2225
face 2227, 2259, 2258
face 2227, 2258, 2226
face 2228, 2260, 2259
face 2228, 2259, 2227
face 2229, 2261, 2260
face 2229, 2260, 2228
face 2230, 2262, 2261
face 2230, 2261, 2229
face 2231, 2263, 2262
face 2231, 2262, 2230
face 2232, 2264, 2263
face 2232, 2263, 2231
face 2233, 2265, 2264
face 2233, 2264, 2232
face 2234, 2266, 2265
face 2234, 2265, 2233
face 2235, 2267, 2266
face 2235, 2266, 2234
face 2236, 2268, 2267
face 2236, 2267, 2235
face 2237, 2269, 2268
face 2237, 2268, 2236
face 2238, 2270, 2269
face 2238, 2269, 2237
face 2239, 2271, 2270
face 2239, 2270, 2238
face 2240, 2272, 2303
face 2240, 2303, 2271
face 2241, 2273, 2272
face 2241, 2272, 2240
face 2242, 2274, 2273
face 2242, 2273, 2241
face 2243, 2275, 2274
face 2243, 2274, 2242
face 2244, 2276, 2275
face 2244, 2275, 2243
face 2245, 2277, 2276
face 2245, 2276, 2244
face 2246, 2278, 2277
face 2246, 2277, 2245
face 2247, 2279, 2278
face 2247, 2278, 2246
face 2248, 2280, 2279
face 2248, 2279, 2247
face 2249, 2281, 2280
face 2249, 2280, 2248
face 2250, 2282, 2281
face 2250, 2281, 2249
face 2251, 2283, 2282
face 2251, 2282, 2250
face 2252, 2284, 2283
face 2252, 2283, 2251
face 2253, 2285, 2284
face 2253, 2284, 2252
face 2254, 2286, 2285
face 2254, 2285, 2253
face 2255, 2287, 2286
face 2255, 2286, 2254
face 2256, 2288, 2287
face 2256, 2287, 2255
face 2257, 2289, 2288
face 2257, 2288, 2256
face 2258, 2290, 2289
face 2258, 2289, 2257
face 2259, 2291, 2290
face 2259, 2290, 2258
face 2260, 2292, 2291
face 2260, 2291, 2259
face 2261, 2293, 2292
face 2261, 2292, 2260
face 2262, 2294, 2293
face 2262, 2293, 2261
face 2263, 2295, 2294
face 2263, 2294, 2262
face 2264, 2296, 2295
face 2264, 2295, 2263
face 2265, 2297, 2296
face 2265, 2296, 2264
face 2266, 2298, 2297
face 2266, 2297, 2265
face 2267, 2299, 2298
face 2267, 2298, 2266
face 2268, 2300, 2299
face 2268, 2299, 2267
face 2269, 2301, 2300
face 2269, 2300, 2268
face 2270, 2302, 2301
face 2270, 2301, 2269
face 2271, 2303, 2302
face 2271, 2302, 2270

facecount equ ($ - test_faces) / 18

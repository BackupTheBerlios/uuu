;; Hydro3d
;; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bimage/x86/test.asm,v 1.1 2003/12/23 02:25:03 bitglue Exp $
;; Written in 2001 Phil Frost, who is playing with it still.


;%define _RDTSC_	; This is bitrotten.

;---------------===============\         /===============---------------
;				constants
;---------------===============/         \===============---------------

%define MINOR_POINTS		25	; number of points around the minor radius
%define CORNER_MAJOR_STEPS	16	; the number of rings that make the corner
%define TOTAL_POINTS		MINOR_POINTS * CORNER_MAJOR_STEPS * 3

; the radius of the tubes that comprise the triangle
%define MINOR_RADIUS		0.8
; the radius of the centerline of the torus that defines each corner
%define CORNER_MAJOR_RADIUS	1.7320508
; the distance from the center of each triangle to the center of each corner
%define TRIANGLE_MAJOR_RADIUS	3.0
; how far each triangle is displaced from the center of all three triangles
%define CENTER_DISPLACEMENT	4.375

; the "ambient light". This is added to the diffuse regions
%define AMBIENT		0x0f
; size of the specular highlight
%define SPEC_SIZE	6

%define CAMERA_Z	30.0

%define SC_INDEX	0x3c4
%define MEMORY_MODE	4
%define GRAPHICS_MODE	5
%define MISCELLANEOUS	6
%define MAP_MASK	2
%define CRTC_INDEX	0x3d4
%define MAX_SCAN_LINE	9
%define UNDERLINE	0x14
%define MODE_CONTROL	0x17

;%define VANILLA_0x13	; if your video card doesn't like my tweaked modes, but
			; can support plain mode 0x13

%ifndef VANILLA_0x13
  %define XRES		320
  %define YRES		400
  %define F_HALF_XRES	160.0	; half of the res. as a float
  %define F_HALF_YRES	200.0
  %define ASPECT_RATIO	0.6	; a horizontal scale factor. Doesn't really
				;work as an aspect ratio; i'll fix that later
%endif

%define VIDEO_RAM	0xa0000
%define MISC_OUTPUT	0x03c2	; VGA misc. output register
%define SC_INDEX	0x03c4	; VGA sequence controller
%define SC_DATA		0x03c5
%define PALETTE_INDEX	0x03c8	; VGA digital-to-analog converter
%define PALETTE_DATA	0x03c9
%define GRAPHICS_INDEX	0x03ce
%define CRTC_INDEX	0x03d4	; VGA CRT controller
%define STATUS		0x03da
%define FEATURE		0x03da
%define ATTRIB		0x03c0

%define NUMSEQUENCER	0x05
%define NUMCRTC		0x19
%define NUMGRAPHICS	0x09
%define NUMATTRIB	0x15

%define MAP_MASK	0x02	; Sequence controller registers
%define MEMORY_MODE	0x04

%define H_TOTAL		0x00	; CRT controller registers
%define H_DISPLAY_END	0x01
%define H_BLANK_START	0x02
%define H_BLANK_END	0x03
%define H_RETRACE_START	0x04
%define H_RETRACE_END	0x05
%define V_TOTAL		0x06
%define OVERFLOW	0x07
%define MAX_SCAN_LINE	0x09
%define HIGH_ADDRESS	0x0C
%define LOW_ADDRESS	0x0D
%define V_RETRACE_START	0x10
%define V_RETRACE_END	0x11
%define V_DISPLAY_END	0x12
%define OFFSET		0x13
%define UNDERLINE_LOCATION	0x14
%define V_BLANK_START	0x15
%define V_BLANK_END	0x16
%define MODE_CONTROL	0x17

%define ENABLEATTRIB	0x20

%define CURSORTOPDATA	17
%define CURSORBOTTOMDATA	18

%define BIOSMODE	0x49
%define COLUMNS		0x4a
%define CURSORTOP	0x61
%define CURSORBOTTOM	0x60

%define _KEYB_STATUS_PORT_	0x64
%define _KEYB_DATA_PORT_	0x60
%define _KEYB_OUTPUT_BUFFER_	0x01

%define BIT_UP		( 1 << 0 )
%define BIT_DOWN	( 1 << 1 )
%define BIT_LEFT	( 1 << 2 )
%define BIT_RIGHT	( 1 << 3 )
%define BIT_PLUS	( 1 << 4 )
%define BIT_MINUS	( 1 << 5 )

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
  .object1:	resd 1
  .object2:	resd 1
  .object3:	resd 1
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

struc span
  .p0:		resw 1
  .p1:		resw 1
  .depth0:	resw 1
  .depth1:	resw 1
endstruc



%ifdef VANILLA_0x13

  %define XRES		320
  %define YRES		200
  %define F_HALF_XRES	160.0	; half of the res. as a float
  %define F_HALF_YRES	100.0
  %define ASPECT_RATIO	0.5625

  %macro inc_x 0
    inc eax
  %endmacro

  %macro dec_x 0
    dec eax
  %endmacro

%else

  %macro inc_x 0	; effectivly increments X, except for a planar memory
    add eax, byte XRES/4; model so that all the plane 0 pixels are the first 80
    cmp eax, XRES	; bytes in the buffer, plane 1 is the next 80, etc.
    jb %%no_wrap
    sub eax, XRES - 1	; we went past the scanline, so correct it
  %%no_wrap:
  %endmacro

  %macro dec_x 0	; same as inc_x, but decrement
    sub eax, byte XRES/4
    jns %%no_wrap
    add eax, XRES - 1
  %%no_wrap:
  %endmacro

%endif


;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						set_matrix_to_identity:	;
; eax = ptr to matrix

  push ecx
  push ebx

  mov ecx, 0x3f800000			; 1.0
  xor ebx, ebx				; 0.0
  mov [eax+camera.cmatrix+matrix44.xx], ecx
  mov [eax+camera.cmatrix+matrix44.xy], ebx
  mov [eax+camera.cmatrix+matrix44.xz], ebx
  mov [eax+camera.cmatrix+matrix44.xw], ebx

  mov [eax+camera.cmatrix+matrix44.yx], ebx
  mov [eax+camera.cmatrix+matrix44.yy], ecx
  mov [eax+camera.cmatrix+matrix44.yz], ebx
  mov [eax+camera.cmatrix+matrix44.yw], ebx

  mov [eax+camera.cmatrix+matrix44.zx], ebx
  mov [eax+camera.cmatrix+matrix44.zy], ebx
  mov [eax+camera.cmatrix+matrix44.zz], ecx
  mov [eax+camera.cmatrix+matrix44.zw], ebx

  mov [eax+camera.cmatrix+matrix44.tx], ebx
  mov [eax+camera.cmatrix+matrix44.ty], ebx
  mov [eax+camera.cmatrix+matrix44.tz], ebx
  mov [eax+camera.cmatrix+matrix44.tw], ecx

  pop ebx
  pop ecx
  retn



;-----------------------------------------------------------------------.
					apply_transformation_to_verts:	;
; ECX = number of verts
; ESI = pointer to start of verts
; EBX = pointer to matrix to apply
;
; returns:
; ESI = pointer to byte after last vert
; ECX = 0
; all others unchanged

.point:
  fld dword[esi+vect3.x]
  fld dword[esi+vect3.y]
  fld dword[esi+vect3.z]	; z y x

  fld dword[ebx+matrix44.xx]	; xx z y x
  fmul st3			; x*xx z y x
  fld dword[ebx+matrix44.yx]	; yx x*xx z y x
  fmul st3			; y*yx x*xx z y x
  fld dword[ebx+matrix44.zx]	; ...
  fmul st3			; ...
  fld dword[ebx+matrix44.tx]	; tx z*zx y*yx x*xx z y x
  faddp st3			; z*zx y*yx x*xx+tx z y x
  faddp st2			; y*yx x*xx+tx+z*zx z y x
  faddp st1			; x*xx+tx+z*zx+y*yx z y x
  fstp dword[esi+vect3.x]

  fld dword[ebx+matrix44.xy]
  fmul st3
  fld dword[ebx+matrix44.yy]
  fmul st3
  fld dword[ebx+matrix44.zy]
  fmul st3
  fld dword[ebx+matrix44.ty]
  faddp st3
  faddp st2
  faddp st1
  fstp dword[esi+vect3.y]
  				; z y x
  fld dword[ebx+matrix44.xz]
  fmulp st3
  fld dword[ebx+matrix44.yz]
  fmulp st2
  fld dword[ebx+matrix44.zz]
  fmulp st1
  fld dword[ebx+matrix44.tz]
  faddp st3
  faddp st2
  faddp st1
  fstp dword[esi+vect3.z]

  add esi, byte vect3_size	;move the pointers to the next cords
  dec ecx			;
  jnz .point			;

  retn


one_point_five:	dd 1.5
data.minor_radius: dd MINOR_RADIUS
data.corner_major_radius: dd CORNER_MAJOR_RADIUS
data.triangle_major_radius: dd TRIANGLE_MAJOR_RADIUS

global _start
_start:

;-----------------------------------------------------------------------.
						create_object:		;

; let S be the angular distance between each step in corner
; let s be the angular distance between each point on the minor radius

  push eax
  fldpi					; pi
  fld dword[one_point_five]		; 3/2	pi
  fdivr st1				; 2pi/3	pi
  fidiv dword[.corner_major_points_less_one]	; S	pi
  fxch					; pi	S
  fadd st0				; 2pi	S
  fidiv dword[.minor_points]		; s	S

; create one circle in the minor
; let t be an ascii replacement for theta
  mov ecx, MINOR_POINTS
.minor_points equ $-4
  mov edi, test_verts

  fld dword[data.minor_radius]		; r	s	S
  fld dword[data.corner_major_radius]	; R	r	s	S
  fldz					; t	R	r	s	S

.create_minor:
  fld st0			; t	t	R	r	s	S
  fsincos			; cos(t)	sin(t)	 t	R	r	s	S
  fmul st4			; r cos(t)	sin(t)	 t	R	r	s	S
  fadd st3			; r cos(t) + R	sin(t)	 t	R	r	s	S
  fstp dword[edi+vect3.x]	; sin(t)	t	R	r	s	S
  fmul st3			; r sin(t)	t	R	r	s	S
  fstp dword[edi+vect3.z]	; t	R	r	s	S
  fadd st3			; t+s	R	r	s	S

  add edi, vect3_size
  dec ecx
  jnz .create_minor

  fstp st0			; R	r	s	S
  fstp st0			; r	s	S
  fstp st0			; s	S
  fstp st0			; S

; now we have a circle of the specified minor radus in the y-z plane, translated
; in the +y direction by the major corner radius.  Duplicate it for each joint
; in the corner.

  mov ebx, CORNER_MAJOR_STEPS - 1

.duplicate_minor:
  mov ecx, MINOR_POINTS * vect3_size / 4
  mov esi, test_verts

  rep movsd

  dec ebx
  jnz .duplicate_minor

  ; now, rotate each circle about the z axis to create a corner.

  sub esp, byte matrix44_size - 4
  mov eax, esp
  call set_matrix_to_identity	; identity matrix at esp

  mov esi, test_verts + MINOR_POINTS * vect3_size
  mov ebp, CORNER_MAJOR_STEPS - 1
.corner_major_points_less_one equ $-4

.rotate_major:
  lea edx, [esp+matrix44.xx]
  lea ebx, [esp+matrix44.yx]
  fld st0			; S	S
  call _rotate_matrix		; S

  mov ecx, MINOR_POINTS
  mov ebx, esp
  call apply_transformation_to_verts

  dec ebp
  jnz .rotate_major

  fstp st0			; fpu stack empty

  ; Now we have a complete corner of the triangle. Now translate away from the
  ; origin so it can be duplicated and rotated.

  fldpi				; pi
  push byte 6			; damn fpu...
  fidiv dword[esp]		; pi/6
  pop ecx			; deallocate our kludgespace
  fsincos			; cos(pi/6)	sin(pi/6)
  fld dword[data.triangle_major_radius]; R	cos(pi/6)	sin(pi/6)
  fmul to st2			; R	cos(pi/6)	R sin(pi/6)
  fmulp st1			; R cos(pi/6)	R sin(pi/6)
  fldz				; 0	R cos(pi/6)	R sin(pi/6)
  fsubrp st1			; -R cos(pi/6)	R sin(pi/6)

  mov eax, esp
  call set_matrix_to_identity	; identity matrix at esp

  fstp dword[esp+matrix44.ty]

  fstp dword[esp+matrix44.tx]

  mov ecx, MINOR_POINTS * CORNER_MAJOR_STEPS
  mov ebx, esp
  mov esi, test_verts
  call apply_transformation_to_verts

  ; duplicate the corner to get three corners...

  mov ebp, 2
.duplicate_major:
  mov esi, test_verts
  mov ecx, MINOR_POINTS * CORNER_MAJOR_STEPS * vect3_size / 4
  rep movsd

  dec ebp
  jnz .duplicate_major

  ; rotate each corner to position

  mov eax, esp
  call set_matrix_to_identity	; identity matrix at esp

  mov esi, test_verts + MINOR_POINTS * CORNER_MAJOR_STEPS * vect3_size
  mov ebp, 2

.rotate_major2:
  fld dword[data.two_third_pi]
  lea edx, [esp+matrix44.xx]
  lea ebx, [esp+matrix44.yx]
  call _rotate_matrix

  mov ecx, MINOR_POINTS * CORNER_MAJOR_STEPS
  mov ebx, esp
  call apply_transformation_to_verts

  dec ebp
  jnz .rotate_major2

  add esp, byte matrix44_size


  mov esi, test_verts
  mov ecx, TOTAL_POINTS

  fld dword[data.center_displacement]
.displace:
  fld dword[esi+vect3.z]
  fadd st1
  fstp dword[esi+vect3.z]

  add esi, byte vect3_size
  dec ecx
  jnz .displace

  fstp st0
  



;-----------------------------------------------------------------------.
						create_faces:		;
  mov edi, fake_test_faces	; XXX

  mov ebp, MINOR_POINTS * CORNER_MAJOR_STEPS * 3
.do_tube:
  mov edx, MINOR_POINTS
.tube_loop:
  lea eax, [edx+ebp-1]
  lea ebx, [edx]
  lea ecx, [edx+MINOR_POINTS]

  cmp ebx, byte MINOR_POINTS
  jl .good1
  sub ebx, byte MINOR_POINTS
.good1:
  cmp ecx, byte MINOR_POINTS * 2
  jl .good2
  sub ecx, byte MINOR_POINTS
.good2:

  add ebx, ebp
  add ecx, ebp

  mov esi, CORNER_MAJOR_STEPS * MINOR_POINTS * 3

  cmp eax, esi
  jb .good3
  sub eax, esi
.good3:
  cmp ebx, esi
  jb .good4
  sub ebx, esi
.good4:
  cmp ecx, esi
  jb .good5
  sub ecx, esi
.good5:

  mov [edi+face.vert1], ax
  mov [edi+face.vert2], bx
  mov [edi+face.vert3], cx

  lea ebx, [edx+ebp+MINOR_POINTS-1]

  cmp ebx, esi
  jb .good6
  sub ebx, esi
.good6:
  mov [edi+face_size+face.vert1], cx
  mov [edi+face_size+face.vert2], bx
  mov [edi+face_size+face.vert3], ax

  add edi, face_size * 2

  dec edx
  jnz .tube_loop

  sub ebp, byte MINOR_POINTS
  jnz .do_tube



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

  ; first, switch to the usual mode 0x13
  mov esi, mcga_mode
  call set_vga_regs

%ifndef VANILLA_0x13
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

%endif ; %ifdef VANILLA_0x13


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
  push edi
  call _create_object
  mov [data.object1], edi			;

  fld dword[data.three_half_pi]
  fadd dword[data.sixth_pi]
  lea edx, [edi+object.omatrix+matrix44.zx]
  lea ebx, [edi+object.omatrix+matrix44.xx]
  call _rotate_matrix


  mov esi, [esp]
  call _create_object
  mov [data.object2], edi

  fld dword[data.three_half_pi]
  lea edx, [edi+object.omatrix+matrix44.zx]
  lea ebx, [edi+object.omatrix+matrix44.xx]
  call _rotate_matrix

  fld dword[data.two_third_pi]
  fchs
  lea edx, [edi+object.omatrix+matrix44.yx]
  lea ebx, [edi+object.omatrix+matrix44.zx]
  call _rotate_matrix

  fld dword[data.sixth_pi]
  lea edx, [edi+object.omatrix+matrix44.zx]
  lea ebx, [edi+object.omatrix+matrix44.xx]
  call _rotate_matrix


  mov esi, [esp]
  call _create_object
  mov [data.object3], edi

  fld dword[data.three_half_pi]
  lea edx, [edi+object.omatrix+matrix44.zx]
  lea ebx, [edi+object.omatrix+matrix44.xx]
  call _rotate_matrix

  fld dword[data.two_third_pi]
  lea edx, [edi+object.omatrix+matrix44.yx]
  lea ebx, [edi+object.omatrix+matrix44.zx]
  call _rotate_matrix

  fld dword[data.sixth_pi]
  lea edx, [edi+object.omatrix+matrix44.zx]
  lea ebx, [edi+object.omatrix+matrix44.xx]
  call _rotate_matrix

  pop edi


create_camera:
;-------------------------------------------------------------------------------
  call _create_camera	;
  ; edi = pointer to camera			;

  mov eax, [data.far_clip]
  xor eax, 0x80000000
  mov [edi+camera.cmatrix+matrix44.tz], eax
  
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
  mov [edi+scene.object1], esi
  mov esi, [data.object2]			;
  mov [edi+scene.object2], esi
  mov esi, [data.object3]			;
  mov [edi+scene.object3], esi



set_palette:
;-------------------------------------------------------------------------------
  mov ecx, SPEC_SIZE
  xor ebx, ebx	;
.loop:  	;
  mov dx, 0x3c8	;
  mov eax, ebx	;
  out dx, al	;
 		;
  inc edx	; 0x3c9 now
  mov al, 0x3F	;
  out dx, al	;red
  out dx, al	;green
  out dx, al	;blue
		;
  inc ebx	;
  dec ecx	;
  jnl .loop	;

  mov ecx, 254-SPEC_SIZE
.loop2:  	;
  mov dx, 0x3c8	;
  mov eax, ebx	;
  out dx, al	;
 		;
  inc edx	; 0x3c9 now
  mov eax, ecx	;
  shr eax, 3	;
  add eax, byte AMBIENT
  out dx, al	;red
  out dx, al	;green
  out dx, al	;blue
		;
  inc ebx	;
  dec ecx	;
  jnl .loop2	;



set_sane_floating_precision:
;-------------------------------------------------------------------------------
  push eax
  fstcw [esp]
  and word[esp], 0xfcff	; clear bits 8 and 9 for single precision
  fldcw [esp]
  pop eax


;; Init stuff is done. We have the whole scene set up and a pointer to it
;; in [data.scene]. This should be all we need to draw it.



;                                                               frame loop here
;==============================================================================

frame:


  in al, _KEYB_STATUS_PORT_
  test al, _KEYB_OUTPUT_BUFFER_
  jz .no_key

  in al, _KEYB_DATA_PORT_
  call _keyboard_client
.no_key:


%ifdef _RDTSC_
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
  mov dx, STATUS;
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

%ifndef VANILLA_0x13

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

%else	; VANILLA_0x13 is defined

  mov ecx, XRES * YRES / 4
  rep movsd

%endif


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
  test bx, BIT_UP			;up arrow pressed?
  jz .down				;
  fld dword[data.Xrot_amount]	;
  fld dword[data.rot_accel]		;
  fchs					;
  faddp st1, st0			;
  fstp dword[data.Xrot_amount]	;
					;
.down:					;
  test bx, BIT_DOWN			;
  jz .left				;
  fld dword[data.Xrot_amount]	;
  fld dword[data.rot_accel]		;
  faddp st1, st0			;
  fstp dword[data.Xrot_amount]	;
					;
.left:					;
  test bx, BIT_LEFT			;
  jz .right				;
  fld dword[data.Yrot_amount]	;
  fld dword[data.rot_accel]		;
  faddp st1, st0			;
  fstp dword[data.Yrot_amount]	;
					;
.right:					;
  test bx, BIT_RIGHT			;
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
;  test bx, BIT_PLUS			;
;  jz .minus				;
;  fld dword[ecx+client_state.cam_dis]	;
;  fld dword[data.zoom_speed]	;
;  faddp st1,st0			;
;  fstp dword[ecx+client_state.cam_dis]	;
;					;
;.minus:				;
;  test bx, BIT_MINUS			;
;  jz .done				;
;  fld dword[ecx+client_state.cam_dis]	;
;  fld dword[data.zoom_speed]	;
;  fsubp st1,st0			;
;  fstp dword[ecx+client_state.cam_dis]	;
.done:					;


rotate:
  mov eax, [data.object1]			;
  call _rotate_object
  mov eax, [data.object2]			;
  call _rotate_object
  mov eax, [data.object3]			;
  call _rotate_object
						;
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
  or bx, BIT_UP			;
  jmp short .done
				;
.up_released:			;
  and bx, ~BIT_UP		;
  jmp short .done
				;
.down_pressed:			;
  or bx, BIT_DOWN		;
  jmp short .done
				;
.down_released:			;
  and bx, ~BIT_DOWN		;
  jmp short .done
				;
.left_pressed:			;
  or bx, BIT_LEFT		;
  jmp short .done
				;
.left_released:			;
  and bx, ~BIT_LEFT		;
  jmp short .done
				;
.right_pressed:			;
  or bx, BIT_RIGHT		;
  jmp short .done
				;
.right_released:		;
  and bx, ~BIT_RIGHT		;
  jmp short .done
				;
.plus_pressed:			;
  or bx, BIT_PLUS		;
  jmp short .done
				;
.plus_released:			;
  and bx, ~BIT_PLUS		;
  jmp short .done
				;
.minus_pressed:			;
  or bx, BIT_MINUS		;
  jmp short .done
				;
.minus_released:		;
  and bx, ~BIT_MINUS		;
  jmp short .done
				;________
.q_pressed:				;
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



;-----------------------------------------------------------------------.
						_scale_matrix:		;

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



;-----------------------------------------------------------------------.
						_rotate_object:		;

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



;-----------------------------------------------------------------------.
						mem.alloc:		;
  mov edi, [memory_frame]
  add [memory_frame], ecx

  push eax
  mov eax, memory_pool.end
  sub eax, ecx
  cmp edi, eax
  ja $
  pop eax

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
  mov [edi+scene.object1], ebx
  mov [edi+scene.object2], ebx
  mov [edi+scene.object3], ebx
  mov [edi+scene.buffer], eax
  mov [edi+scene.camera], esi

  retn					;



;-----------------------------------------------------------------------.
						_create_object:		;
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

  push esi
  
  mov ecx, object_size
  xor edx, edx
  call mem.alloc

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



;-----------------------------------------------------------------------.
						_create_mesh:		;
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



;-----------------------------------------------------------------------.
						_create_camera:		;
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



;-----------------------------------------------------------------------.
						_create_camera_matrix:	;
;>
;; This is a function usefull for creating a camera projection matrix from usual
;; human parameters like FOV and near/far clipping planes. This function only
;; makes the matrix, one must still create a camera if he is to make much use of
;; it :)
;;
;; I think I may have the vertical and horizontal axies switched, because
;; changing the aspect ratio scales the image horizontally. This should not be,
;; because the (horizontal) FOV should remain constant.
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
;<

; get a list of the objects ---===---

  push dword [edi+scene.object3]
  push dword [edi+scene.object2]
  push dword [edi+scene.object1]
  mov ecx, 3
  ; stack now has the objects on it, ECX has the number of them

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

;;XXX: use the real resloution in here. This code assumes mode 0x13.
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
  
  call _draw_face

; advance the pointers ---===---
.skip:
  add edx, byte face_size
  fstp st0
  dec ecx
  jnz .face

;; We have drawn all the faces of that object. Here's the end of the object
;; loop:

  pop edi		; pointer to scene
  pop ecx		; the number of objects.
  dec ecx
  jnz .object

.done:
  retn

[section .data]
resx: dd F_HALF_XRES
resy: dd F_HALF_YRES
__SECT__



;-----------------------------------------------------------------------.
						_to_screen_cordinates:	;
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
  sub esp, byte 8
  
  fld dword[eax+vect4.x]	; x
  fld dword[eax+vect4.y]	; y x
  fld dword[eax+vect4.w]	; w y x
  fdiv to st2			; w y x/w
  fdivp st1			; y/w x/w

  ;; we now have our point in the range [-1,1]. This makes it easy to map to
  ;; screen cordinates and do clipping and such and stuff.

  fmul dword[resx]
  fistp dword[esp]
  pop eax
  fmul dword[resy]
  fistp dword[esp]
  pop ebx

  add eax, XRES/2 - 1
  add ebx, YRES/2 - 1
  
  retn



_draw_face.flat_bottom:
  pushad
  jmp near _draw_face.flat_bottom_return

_draw_face.out16:
  add esp, byte 8
_draw_face.out8:
  add esp, byte 8
_draw_face.out0:
  popad
  retn

;-----------------------------------------------------------------------.
						_draw_face:		;
  pushad

  movzx eax, word[edx+face.vert1]	; EAX = index to first point
  call _to_screen_cordinates

  cmp ebx, YRES
  jae near .out0
  cmp eax, XRES
  jae near .out0

  push ebx
  push eax

  movzx eax, word[edx+face.vert2]	; EAX = index to 2nd point
  call _to_screen_cordinates

  cmp ebx, YRES
  jae near .out8
  cmp eax, XRES
  jae near .out8

  push ebx
  push eax

  movzx eax, word[edx+face.vert3]	; EAX = index to 2nd point
  call _to_screen_cordinates

  cmp ebx, YRES
  jae .out16
  cmp eax, XRES
.xres equ $-4
  jae .out16

  sub esp, byte 8		; so that we can use POPAD to get all points
  push ebx
  push eax

;; stack:
;; x2		+0	edi
;; y2		+4	esi
;; color	+8
;; ---		+12
;; x1		+16	ebx
;; y1		+20	edx
;; x0		+24	ecx
;; y0		+28	eax

  popad

  ; sort so that (x0,y0) is highest, that is, lowest y

  cmp eax, edx
  jb .no_swap0

  xchg ebx, ecx
  xchg edx, eax
.no_swap0:

  cmp eax, esi
  jb .no_swap1

  xchg edi, ecx
  xchg esi, eax
.no_swap1:

  pushad


  ; draw the two lines from the highest (lowest y) point

  mov edi, .span_buffer
  lea eax, [esp+24]
  lea ebx, [esp+16]
  call .render_section

  mov edi, .span_buffer+2
  lea eax, [esp+24]
  mov ebx, esp
  call .render_section

  ; draw the remaining line

  popad

  ; determine on which side this line goes. it goes on the same side as
  ; whichever of the first two lines was shorter in the y direction.
  xor ebp, ebp
  cmp edx, esi
  jb .on_left
  je .flat_bottom
  add ebp, byte span.p1
.on_left:
  ; ebp = 2 if on right, 0 if on left.

  ; sort so that (x1,y1) is higher (smaller y) than (x2,y2)

  cmp edx, esi
  jb .no_swap4
  xchg ebx, edi
  xchg edx, esi
.no_swap4:

  pushad
 
  mov edi, [esp+20]	;
  sub edi, [esp+28]	; deltax of the shorter of the two first lines
  lea edi, [edi*span_size+ebp+.span_buffer]

  lea eax, [esp+16]
  mov ebx, esp
  call .render_section


.flat_bottom_return:

  ; now we have our spans in the buffer. next, fill the triangle

  fmul dword[.num_colors]
  fist dword[esp+8]

  mov ecx, [esp+4]
  sub ecx, [esp+28]		; ECX = triangle height
  inc ecx
  mov esi, .span_buffer

  mov edi, [esp+28]		; highest, smallest Y
%if XRES = 320
  lea edi, [edi*5]
  shl edi, 6
%elif XRES = 360
  lea edx, [edi+edi]
  shl edi, 5
  sub edi, edx
  lea edi, [edi+edi*2]
  shl edi, 2
%else
  %error "cant multiply by XRES here "
%endif
  add edi, [esp+32]

.do_line:
  movzx eax, word[esi+span.p0]
%ifndef VANILLA_0x13
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
%endif

  movzx ebx, word[esi+span.p1]
  movzx ebp, word[esi+span.p0]
  sub ebx, ebp
  jz .next_scanline
  js .draw_backwards

  ; edi+eax = start
  ; edi+ebx = end

.fill_line:
  mov edx, [esp+8]	; DL = color
  mov [edi+eax], dl

  inc_x
  dec ebx
  jnz .fill_line

.next_scanline:
  add edi, XRES
  add esi, byte span_size
  dec ecx
  jnz .do_line

  jmp short .done_filling

.draw_backwards:
  ; edi+eax = start
  ; edi+ebx = end

  dec_x

.fill_line_backwards:
  mov edx, [esp+8]	; DL = color
  mov [edi+eax], dl

  dec_x
  inc ebx
  jnz .fill_line_backwards

  add edi, XRES
  add esi, byte span_size
  dec ecx
  jnz .do_line

.done_filling:

;  mov dl, 0xff
;
;  mov eax, [esp+24]
;  mov ebx, [esp+28]
;
;  mov ecx, [esp+16]
;  mov esi, [esp+20]
;
;  mov edi, [esp+32]
;  call _draw_line
;
;  mov eax, [esp+24]
;  mov ebx, [esp+28]
;
;  mov ecx, [esp+0]
;  mov esi, [esp+4]
;
;  mov edi, [esp+32]
;  call _draw_line
;
;  mov eax, [esp+16]
;  mov ebx, [esp+20]
;
;  mov ecx, [esp+0]
;  mov esi, [esp+4]
;
;  mov edi, [esp+32]
;  call _draw_line

  add esp, byte 32

  popad
  retn


[section .bss]
.span_buffer:	resb YRES * span_size
__SECT__


[section .data]
.num_colors: dd 255.0
__SECT__


.render_section:
  ; EDI = target in scanline buffer
  ; EAX = pointer to top point
  ; EBX = pointer to bottom point

  mov ecx, [ebx+4]
  sub ecx, [eax+4]
  inc ecx		; ECX = ysteps

  fild dword[eax]	; x0
  fld st0		; x0	x0
  push ecx
  fild dword[esp]	; ysteps	x0	x0
  fild dword[ebx]	; x1	ysteps	x0	x0
  fsubrp st3		; ysteps	x0	x1-x0
  pop ecx
  fdivp st2		; x0	(x1-x0)/ysteps
.render_loop:
  fist word[edi]
  fadd st1		; next x	(x1-x0)/ysteps
  add edi, byte span_size
  dec ecx
  jnz .render_loop

  fstp st0
  fstp st0

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
;; EDI = ptr to buffer
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
;; |1)        ..* |3) *..           |
;; |       ...    |      ...        |        dx > dy       |
;; |    ...       |         ...     | one pixel per column |
;; | ...          |            ...  |                      |
;; |--------------+-----------------|
;; |2)     *      |4)    *          |
;; |       .      |      .          |
;; |      .       |       .         |        dx < dy
;; |      .       |       .         | one pixel per row  -----
;; |     .        |        .        |
;; |     .        |        .        |
;; |    .         |         .       |
;; |    .         |         .       |
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
;; About planar VGA memory:
;; ------------------------
;; Unless VANILLA_0x13 is defined, hydro3d uses VGA modes with a planar memory
;; layout. This means that memory is divided between four planes. Rather than
;; each byte coresponding directly to each pixel on the raster, each plane hold
;; each fourth pixel.
;;
;; As you can imagine, it's quite a nightmare if I draw the scene to a buffer
;; in a linear manner and then want to copy it do display memory.  By grouping
;; all the pixels that will go in each plane (in other words every 4th pixel)
;; together I can avoid all the messy unpacking and make use of rep movsd to
;; copy rather than do it byte per byte.
;;
;; If i grouped all of the bytes for each plane together and then copied each
;; plane sequentially to the screen, I would get funny stripes at the top of
;; the display because when vertical blanking is over, I may be done with
;; planes 0, 1, and 2, but 3 has yet to be drawn, which means every fourth
;; pixel is incorrect.
;;
;; So, I only group the planes together for each scanline. Then I can easily
;; copy an entire scanline with only 4 plane changes, 4 rep movsd, and no
;; unpacking. In other words, each XRES/4 bytes in the buffer is a new plane.
;;
;; To make this fast I use a macro to 'increment' the X cord when drawing. Just
;; INC alone would generate the sequence {0, 1, 2, 3, 4 ... 319} but because of
;; the planar layout I need {0, 80, 160, 240, 1, 81, 161, 241, ..} The macro
;; inc_x does that. There is also a dec_x, which decrements the same sequence.
;<

; perhaps a better line drawing from vulture that could do antialiasing:
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


  ; possibly swap points so that y0 =< y1; therefore dy =< 0
  cmp ebx, esi		; cmp y0, y1
  je near .possible_degenerate
  jb .no_swap
  xchg eax, ecx		; flip the points
  xchg ebx, esi
.no_swap:
  
  sub ecx, eax		; ECX = dx
  sub esi, ebx		; EDX = dy ( always =< 0 )
  
  ;; now convert the linear X to the planar sort we need
  ;; the equation to do this is: newx = x / 4 + (x % 4) * RESX / 4
%ifndef VANILLA_0x13
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
%endif

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

.possible_degenerate:
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
;; to radians, multiply degrees by pi/180. These rotations are relative to the
;; current orientaion of the object. If you need absloute rotations, you can set
;; the matrix to identiy first:
;;   dd 1.0, 0.0, 0.0
;;   dd 0.0, 1.0, 0.0
;;   dd 0.0, 0.0, 1.0
;;
;; (*) HOW TO SET THE EDX AND EBX REGISTERS
;; All the rotations are essentially the same code, only operate on a diffrent
;; part of the matrix. By using these two pointers, I can combine 110
;; instructions down to about 20, with a speed loss of about 5 clocks per
;; rotation. The EDX and EBX registers should be a pointer to the matrix, then a
;; value must be added to them according to the following table:
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
;; top three elements of fpu stack are unused
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
;						vga stuff		;

%macro IODELAY 0
  jmp short $+2
  jmp short $+2
%endmacro


set_vga_register_set:
  xor eax, eax
.loop1:
  mov ah, [esi]
  inc esi
  out dx, ax
  IODELAY
  inc al
  dec cl
  jnz .loop1
  retn

set_vga_regs:

  ; -=# wait for vertical retrace #=-
  ;
  ; I don't see why this is logically needed...but it was here, and one never
  ; knows the deep mysteries of VGA :)

  mov dx, STATUS;
.wait:		;
  in al, dx	;
  and al, 0x8	;
  jnz .wait	;
.waitmore:	;
  in al, dx	;
  and al, 0x8	;
  jz .waitmore	;


  ; -=# Not sure what this does, and if it's required if one does not use the bios #=-

  xor ah, ah
  mov al, [esi]
  mov [BIOSMODE], al
  inc esi
  mov al, [esi]
  mov [COLUMNS], al
  inc esi
  mov di, [esi]
  add esi, 2
  mov al, [esi+CURSORTOPDATA]
  mov [CURSORTOP], al
  mov al, [esi+CURSORBOTTOMDATA]
  mov [CURSORBOTTOM], al


  ; -=# Set the misc. output and feature registers #=-

  mov dx, MISC_OUTPUT
  mov al, [esi]
  inc esi
  out dx, al
  IODELAY

  mov dx, FEATURE
  mov al, [esi]
  inc esi
  out dx, al
  IODELAY


  ; -=# set sequencer registers #=-

  mov dx, SC_INDEX
  mov cl, NUMSEQUENCER
  call set_vga_register_set


  ; -=# set the CRTC registers #=-

  mov ah, [esi+V_RETRACE_END]
  mov al, V_RETRACE_END
  and ah, 0x7f
  mov dx, CRTC_INDEX
  out dx, ax
  IODELAY

  mov cl, NUMCRTC
  call set_vga_register_set


  ; -=# set the graphics registers #=-

  mov dx, GRAPHICS_INDEX
  mov cl, NUMGRAPHICS
  call set_vga_register_set


  ; -=# set the attribute registers #=-

  mov dx, FEATURE
  in al, dx		; reset the attrib data/address flipflop
  IODELAY
  mov dx, ATTRIB
  mov cl, NUMATTRIB
  xor al, al
.loop:
  mov ah, [esi]
  out dx, al
  IODELAY
  xchg al, ah
  out dx, al
  xchg ah, al
  inc al
  inc esi
  cmp al, cl
  jb .loop
  mov al, ENABLEATTRIB
  out dx, al
  IODELAY

  retn



;---------------===============\            /===============---------------
				section .bss
;---------------===============/            \===============---------------

memory_pool:	resb 0x40000
.end:

vertcount equ TOTAL_POINTS
test_verts:	resb vertcount * vect3_size

facecount equ TOTAL_POINTS * 2
test_faces:
fake_test_faces:	resb vertcount * 2 * face_size
;test_faces equ fake_test_faces + (TOTAL_POINTS * 2 - MINOR_POINTS * 8 - 4) * face_size


alignb 4
data:
  .scene:	resd 1		; pointer to scene
  .object1:	resd 1
  .object2:	resd 1
  .object3:	resd 1
  .Xrot_amount:	resd 1
  .Yrot_amount:	resd 1
  .Zrot_amount:	resd 1
  .keys:	resd 1		; flags of what keys are currently pressed
  .fade_count:	resb 1		;



;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

; misc. data ---===---

  .rot_accel:		dd 0.0008
  .rot_decel:		dd 0.999
  .far_clip:		dd CAMERA_Z	; far clip plane
  .near_clip:		dd 1.0		; near clip plane
  .fov:			dd 0.6		; FOV, in radians
  .aspect_ratio:	dd ASPECT_RATIO	; aspect ratio (gee!)
  .half_pi:		dd 1.57079632679
  .third_pi:		dd 1.0471975512
  .sixth_pi:		dd 0.523598775598
  .two_third_pi:	dd 2.09439510239
  .three_half_pi:	dd 4.71238898038
  .center_displacement:	dd CENTER_DISPLACEMENT


mcga_mode: db 0x13, 40		;BIOS mode num, and num columns
  dw 0a000h

  ; misc output, feature control
  db 0x63,0x00

  ; -=# sequencer registers #=-

  db 0x03,0x01,0x0f,0x00,0x0e
  ;  |    |    |    |    `---------------- 0x04 sequencer memory mode
  ;  |    |    |    `--------------------- 0x03 character map select
  ;  |    |    `-------------------------- 0x02 map mask
  ;  |    `------------------------------- 0x01 clocking mode
  ;  `------------------------------------ 0x00 reset

  ; -=# CRTC registers #=-

  db 0x5f,0x4f,0x50,0x82,0x54,0x80,0xbf,0x1f
  ;  |    |    |    |    |    |    |    `- 0x07 overflow
  ;  |    |    |    |    |    |    `------ 0x06 vertical total
  ;  |    |    |    |    |    `----------- 0x05 end horiz retrace
  ;  |    |    |    |    `---------------- 0x04 start horiz retrace
  ;  |    |    |    `--------------------- 0x03 end horiz blanking
  ;  |    |    `-------------------------- 0x02 start horiz blanking
  ;  |    `------------------------------- 0x01 end horiz display
  ;  `------------------------------------ 0x00 horiz total

  db 0x00,0x41,0x00,0x00,0x00,0x00,0x00,0x00
  ;  |    |    |    |    |    |    |    `- 0x0F cursor location low
  ;  |    |    |    |    |    |    `------ 0x0E cursor location high
  ;  |    |    |    |    |    `----------- 0x0D start address low
  ;  |    |    |    |    `---------------- 0x0C start address high
  ;  |    |    |    `--------------------- 0x0B cursor end
  ;  |    |    `-------------------------- 0x0A cursor start
  ;  |    `------------------------------- 0x09 maximum scan line
  ;  `------------------------------------ 0x08 preset row scan

  db 0x9c,0x0e,0x8f,0x28,0x40,0x96,0xb9,0xa3
  ;  |    |    |    |    |    |    |    `- 0x17 crtc mode control
  ;  |    |    |    |    |    |    `------ 0x16 end vertical blanking
  ;  |    |    |    |    |    `----------- 0x15 start vertical blanking
  ;  |    |    |    |    `---------------- 0x14 underline location
  ;  |    |    |    `--------------------- 0x13 offset
  ;  |    |    `-------------------------- 0x12 vert display end
  ;  |    `------------------------------- 0x11 vert retrace end
  ;  `------------------------------------ 0x10 vert retrace start

  db 0xff
  ;  `------------------------------------ 0x18 line compare register

  ; -=# graphics registers #=-

  db 0x00,0x00,0x00,0x00,0x00,0x50,0x07,0x0f
  ;  |    |    |    |    |    |    |    `- 0x07 color don't care
  ;  |    |    |    |    |    |    `------ 0x06 misc. graphics
  ;  |    |    |    |    |    `----------- 0x05 graphics mode
  ;  |    |    |    |    `---------------- 0x04 read map select
  ;  |    |    |    `--------------------- 0x03 data rotate
  ;  |    |    `-------------------------- 0x02 color compare
  ;  |    `------------------------------- 0x01 enable set/reset
  ;  `------------------------------------ 0x00 set/reset

  db 0xff
  ;  `------------------------------------ 0x08 bit mask

  ; -=# attribute registers #=-
 
  db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07
  ;  `----`----`----`----`----`----`----`- 0x00 - 0x07 palette

  db 0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f
  ;  `----`----`----`----`----`----`----`- 0x08 - 0x0F palette

  db 0x41,0x00,0x0f,0x00,0x00
  ;  |    |    |    |    `---------------- 0x14 color select
  ;  |    |    |    `--------------------- 0x13 horiz pixel panning
  ;  |    |    `-------------------------- 0x12 color plane enable 
  ;  |    `------------------------------- 0x11 overscan color
  ;  `------------------------------------ 0x10 attribute mode control

memory_frame:	dd memory_pool

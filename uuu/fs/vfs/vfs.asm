; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/fs/vfs/vfs.asm,v 1.2 2003/12/31 20:16:55 bitglue Exp $

%include "fs/fs.asm"


extern mem.allocate
extern mem.deallocate

global vfs.instantiate



;---------------===============\          /===============---------------
;				structures
;---------------===============/          \===============---------------

struc vfs_descriptor
  .fs_descriptor:	resb fs_descriptor_size
  .root_node:		resd 1	; root vfs_node
endstruc


struc node_set
  .node:	resd 1	; ptr to the first (and only) node, or NULL after it's been retrieved
endstruc


struc vfs_node
  .ref:		resd 1
endstruc



;---------------===============\             /===============---------------
				section .text
;---------------===============/             \===============---------------

;-----------------------------------------------------------------------.
						vfs.instantiate:	;
;! <proc>
;!   Create an instance of the filesystem.
;!   <p reg="eax" type="uuustring" brief="options">
;!     This is a FS specific option string. It indicates important stuff such
;!     as what to mount, how to mount it, etc. Some time in the future, some
;!     general conventions for the format of this will be estabilshed.
;!   </p>
;!
;!   <ret brief="success">
;!     <r reg="eax" type="pointer" brief="fs_descriptor thus created"/>
;!   </ret>
;!
;!   <ret brief="other"/>
;!
;! </proc>

  mov eax, vfs_descriptor_size
  ecall mem.allocate, CONT, .other, .other
  xor ebx, ebx
  inc ebx
  mov [eax+fs_descriptor.ref], ebx
  mov [eax+fs_descriptor.destroy], dword destroy_fs_descriptor
  mov [eax+fs_descriptor.get_files], dword get_files
  mov [eax+fs_descriptor.get_nodeset_next], dword get_nodeset_next
  return

.other:
  return 1



;-----------------------------------------------------------------------.
						get_files:		;
; eax = path
;
; return 


;-----------------------------------------------------------------------.
						get_nodeset_next:	;
  mov ebx, [eax+node_set.node]
  xchg eax, ebx
  test eax, eax
  jz .empty

  xor edx, edx
  mov [ebx+node_set.node], edx
  return

.empty:
  return 1



;-----------------------------------------------------------------------.
						destroy_fs_descriptor:	;
  ecall mem.deallocate, CONT, .other
  return

.other:
  return 1


;---------------===============\             /===============---------------
				section .data
;---------------===============/             \===============---------------

empty_nodeset:
  istruc node_set
    at node_set.node,	dd 0
  iend

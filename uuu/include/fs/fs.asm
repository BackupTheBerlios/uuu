; $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/include/fs/fs.asm,v 1.1 2003/12/31 18:34:44 bitglue Exp $

; for discussion, see http://unununium.org/fs

struc fs_descriptor
  .ref:			resd 1	; reference count
  .destroy:		resd 1	; procedure to call when ref count reaches 0
  .get_files:		resd 1	; ptr to procedure to return a nodeset by name
  .get_nodeset_next:	resd 1	; ptr to procedure to retrieve next node in a nodeset
  ; fs specific information follows
endstruc


struc file_descriptor
  .ref:			resd 1	; reference count
  .destroy:		resd 1	; procedure to call when ref count reaches 0
  .get_interface:	resd 1	; ptr to get_interface procedure
  ; file system specific information follows
endstruc


struc interface_descriptor
  .ref:			resd 1	; reference count
  .destroy:		resd 1	; procedure to call when ref count reaches 0 (in FS terms, "close" the interface)
  ; interface specific procedures follow
endstruc

;! <proc name="fs.get_files">
;!   <p reg="eax" type="uuustring" brief="path">
;!     This is a xpath expression to the files to be opened.
;!   </p>
;!
;!   <ret brief="success">
;!     <r reg="eax" type="pointer" brief="a nodeset representing the files matched by the path">
;!       This can be further examined by fs.get_nodeset_next, availible through
;!       fl_descriptor.get_nodeset_next. Node that nodesets can be empty, so
;!       this procedure always succeedes, even if the path matches no files.
;!     </r>
;!   </ret>
;! </proc>
;!
;!
;! <proc name="fs.get_nodeset_next">
;!   <p reg="eax" type="pointer" brief="nodeset on which to operate">
;!     This is a nodeset obtained from fs.get_files
;!   </p>
;!
;!   <ret brief="next file">
;!     <r reg="eax" type="pointer" brief="next file in nodeset"/>
;!   </ret>
;!   <ret brief="no more files"/>
;! </proc>

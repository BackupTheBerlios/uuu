%ifndef __RING_QUEUE_INCLUDE__
%define __RING_QUEUE_INCLUDE__

; Ring Links
;------------------------------------------------------------------------------
; This structure describe the expected order for the next/previous links used
; in the ring lists.  It is used in the _rt_thread_t and _rt_mutex_t structures
;
;------------------------------------------------------------------------------
struc _ring_queue_t		; ----- ;
.next		resd 1		; 00-03 ;
.previous	resd 1		; 04-07 ;
endstruc			; ----- ;
;------------------------------------------------------------------------------

%endif

%ifndef __THREAD_INCLUDE__
%define __THREAD_INCLUDE__

; Realtime Thread Header
;------------------------------------------------------------------------------
; This structure is created for every realtime thread in the system and is
; located at the top of a thread's stack.
;
; The '*_link' are used to chain the thread header in both the timer queue or
; the priority execution queue.
;
; The execution 'start' and 'end' times are specified in unadjusted Uuu-Time
; difference since the scheduler initialization.
;
; The 'event notifier' is a callback function used to receive various
; notification about the execution of the thread, such as:
;   - execution start was delayed by other threads
;   - execution aborted - would go above execution end
;   - mutex lock required time lending
;   - thread was preempted at least once
;   - invalid processor instruction caught
;   - invalid co-processor usage
;   - and more, see official documentation (if any.. )
;
; The 'event mask' is used to control filtering of the above events.
;
; The 'execution priority' is the priority associated to the thread.  It may
; or may not be at all time the currently executing priority, if for example
; a higher priority thread is lending time until a mutex is unlocked.
;
; The 'locked mutexes' is a count of locked mutexes, mostly used in deadlock
; prevention and help programmers in the development of their software.
;
; The 'execution status' indicate one of the following state:
%define RT_SCHED_STATUS_UNSCHEDULED	0x00
%define RT_SCHED_STATUS_SLEEPING	0x01
%define RT_SCHED_STATUS_RUNNING		0x02
%define RT_SCHED_STATUS_WAITING		0x03
;
; The 'flags' are used by the scheduler for various tracking functions:
;   bit	description
;     0	lended time run (0=no, 1=running under lended time)
;     1 realtime thread select (0=non-rt, 1=realtime)
;     2	initialized status (0=unitialized, 1=initialized)
;   3-7	reserved
;------------------------------------------------------------------------------
struc _thread_t			; ----- ; -------------------------------------
.execution_start	resd 2	; 00-07 ; start time
.start_ring		resb _rt_ring_links_size
.execution_end		resd 2	; 10-17 ; number of microseconds of execution
.end_ring		resb _rt_ring_links_size
.top_of_stack           resd 1	; 20-23 ; active TOS (ESP)
.bottom_of_stack	resd 1	; 24-27 ; Lowest allowed ESP
.process_id             resd 1	; 28-2B ; ID of parent process
.event_notifier         resd 1	; 2C-2F ; callback for event forwarding
.event_mask		resd 1	; 30-33 ; mask some event types
.thread_pool		resd 1	; 34-37 ;
.execution_priority	resb 1	; 38-38 ; selected execution priority
.locked_mutexes		resb 1	; 39-39 ; number of locked mutexes
.execution_status	resb 1	; 3A-3A ; execution status
.flags			resb 1	; 3B-3B ; thread flags
.magic			resd 1	; 3C-3F ;
endstruc                        ; ----- ; -------------------------------------
;------------------------------------------------------------------------------


; Mutex
;------------------------------------------------------------------------------
; This is the structure used for mutexes, which are dynamically allocated 
; unless fine-tuning is done by a third-party in a fixed version development
; environment.
;
;------------------------------------------------------------------------------
struc _rt_mutex_t		; ----- ; -------------------------------------
.holding_thread	resd 1		;   -   ; thread currently holding the lock
.magic		resd 1		;   -   ;
.wait_queue	resb _rt_ring_links_size;
endstruc			; ----- ; -------------------------------------
;------------------------------------------------------------------------------


%endif

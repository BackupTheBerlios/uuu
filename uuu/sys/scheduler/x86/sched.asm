; Avalon - Hard Realtime Priority Scheduler
; Copyright (C) 2002-2004, Dave Poirier
; Distributed under the BSD License
;
; Implementation Specifics
;-------------------------
;
; > Thread ID
;
; Thread ID are pointers to stack base.  Thread headers are stored at the top
; of the stack.  One can locate the thread headers by adding the stack size
; to the thread ID then substracting the size of the thread headers.
;
; > Realtime Scheduler
;
; The scheduler works on a hard realtime basis, scheduled threads have to
; both provide a start time and a maximum time by which they must be completed
; or an error be reported.
;
; > Non-Realtime Scheduler
;
; Non-RT scheduling is achieved by scheduling an unbounded (max allowed UUU-Time)
; lowest priority real-time thread.
;
; Using this tolerance, the thread will be scheduled at the specified time
; or _LATER_, up to X microseconds as specified in the tolerance.
;
;
;
;
;
;                                    .---.
;                                   /     \
;                                   | - - |
;                                  (| ' ' |)
;                                   | (_) |   o
;                                   `//=\\' o
;                                   (((()))
;                                    )))((
;                                    (())))
;                                     ))((
;                                     (()
;                                 jgs  ))
;                                      (
;
;
;                       c o n t r o l   v a r i a b l e s
;
;
;
;
;
;
; Stack Size
;------------------------------------------------------------------------------
; Default stack size in bytes.  Note, the thread headers are stored at the
; stack top, so if ESP == Thread ID the stack is empty.
;
; If ESP == thread ID - (_DEFAULT_STACK_SIZE - _thread_t_size) the stack is
; full.
;
%assign _LOG_STACK_SIZE_        11
%assign _STACK_SIZE_        (1<<_LOG_STACK_SIZE_)
;------------------------------------------------------------------------------
;
;
; Number of 32 thread pools to pre-allocate
;------------------------------------------------------------------------------
%assign _THREAD_POOLS_  2
;------------------------------------------------------------------------------
;
;
; Default time resolution (PIT/microseconds)
;------------------------------------------------------------------------------
; The default resolution influence the time between Timer IRQ, or the time
; interval between which thread execution times are checked.  A lower 
; resolution means a more responsive system with slightly lower workload
; capacity as the scheduler will be spending most of its time checking thread
; execution times.
;
; There are two possible ways to select the timer resolution, either in
; microseconds or in PIT ticks.  The system will be slightly more precise
; if setup using PIT ticks, so in case of doubt leave it as it is.
;
;
; Comment the next line to set the system in microseconds based configuration:
%define _RT_TIMER_TICKS_	1
;
;
; Recommended _DEFAULT_RESOLUTION_ values:
;   80386:		250us		298ticks
;   80486:		100us		119ticks
;   Pentium:		 80us		 95ticks
;   Pentium II:		 45us		 57ticks
;   Pentium III/Athlon:	 10us		 12ticks
;   Pentium IV:		  5us		  6ticks
;
%assign _DEFAULT_RESOLUTION_    12
;------------------------------------------------------------------------------
;
;
; Initial Eflags Register state when creating threads
;------------------------------------------------------------------------------
; 
; bit   description
; ---   -----------
;   0   CF, Carry flag
;   1   1
;   2   PF, Parity flag
;   3   0
;   4   AF, Adjust flag
;   5   0
;   6   ZF, Zero flag
;   7   SF, Sign flag
;   8   TF, Trap flag
;   9   IF, Interrupt flag
;  10   DF, Direction flag
;  11   OF, Overflow flag
; 12-13 IOPL, I/O Privilege level
;  14   NT, Nested flag
;  15   0
;  16   RF, Resume flag
;  17   VM, Virtual mode
;  18   AC, Alignment check     
;  19   VIF, Virtual Interrupt flag
;  20   VIP, Virtual Interrupt pending
;  21   ID, Identification flag
; 22-31 0
%define _THREAD_INITIAL_EFLAGS_ 0x00000602
;------------------------------------------------------------------------------
;
;
; Initial code segment to use by default
;------------------------------------------------------------------------------
%define _THREAD_INITIAL_CS_     0x0008
;------------------------------------------------------------------------------
;
;
; PIT Adjustment value
;------------------------------------------------------------------------------
%assign _PIT_ADJ_DIV_			1799795308
%assign _PIT_ADJ_DIV_PRECISION_			31
%assign _PIT_ADJ_MULT_			2562336687
%assign _PIT_ADJ_MULT_PRECISION_		31
;
; How to compute this value... The 8254 PIT has a frequency of 1.193181MHz
; and we want a resolution in microsecond.  Programmation of the pic is
; pretty simple, you give it the number of "tick" to do, and it decrement
; this value at each clock cycle (1.193...).  When the value reach 0, an
; interrupt is fired.
;
; Thus, if we give 1 to the PIT, it will take 0.838095 micro-seconds to
; fire an interrupt.  To have a proper 1 to 1 matching, we need to
; multiply the number of microsecond to wait by 1.193181.
;
; Using fixed point arithmetic 1.31, we take this multiplier and shift
; it by 31 bits, equivalent to multiplying it by 2^31. This gives us
; a value of 2562336687 without losing any precision.
;
; Now if we multiply this 1.31 bits with a 31.1 value, we obtain a 32.32
; fixed point result, which should be easy to extract from EDX:EAX.
;
; The operation will then consist of the following sequence:
; o Load number of microseconds to wait: EAX = microseconds
; o adjust the value for 31.1, insert a 0 on the right: EAX < 1
; o multiply the 31.1 value with the 1.31 value: EAX * 2562336687
; o get result in high part of 32.32: EDX = result
;
; For more information on fixed point arithmetic, please visit:
; http://www.accu.org/acornsig/public/caugers/volume2/issue6/fixedpoint.html
;
%if _PIT_ADJ_DIV_PRECISION_ <> _PIT_ADJ_MULT_PRECISION_
  %error "Precision adjustments unmatching for mult/div in PIT conversion"
%endif
%assign _PIT_ADJ_SHIFT_REQUIRED_	(32 - _PIT_ADJ_MULT_PRECISION_)
;------------------------------------------------------------------------------
;
;
;------------------------------------------------------------------------------
; Macro introducing a small I/O delay, gives some time for the chips to handle
; the request we just sent.
;
%define io_delay        out 0x80, al
;%define io_delay       ;-no-delay-
;------------------------------------------------------------------------------
;
;
;------------------------------------------------------------------------------
; Sanity Checks.
;
; Enabling sanity checks causes additional code to be included to validate
; pointers before following them, making sure every ring node member points
; properly to valid members in both direction, etc.
;
; Keeping sanity checks enabled is a good idea and should be disabled only after
; thorough testing of the scheduler.
;
; To disable sanity checks, comment the next line:
%define RT_SANITY_CHECKS
;
; Sanity check is performed the same under the dev bench as outside, but some
; additional information is only provided inside the dev bench. Uncomment the
; next line to enable that additional information.
%define RT_SANITY_DEVBENCH
;
; Those values are magic markers to help detect invalid pointers/corruption
%define RT_THREAD_MAGIC		'thrmagic'
%define RT_THREAD_POOL_MAGIC	'thpomagi'
;------------------------------------------------------------------------------




;                                    .---.
;                                   /     \
;                                   | - - |
;                                  (| ' ' |)
;                                   | (_) |   o
;                                   `//=\\' o
;                                   (((()))
;                                    )))((
;                                    (())))
;                                     ))((
;                                     (()
;                                 jgs  ))
;                                      (
;
;
;                              s t r u c t u r e s




; Ring Links
;------------------------------------------------------------------------------
; This structure describe the expected order for the next/previous links used
; in the ring lists.  It is used in the _rt_thread_t and _rt_mutex_t structures
;
;------------------------------------------------------------------------------
struc _rt_ring_links		; ----- ;
res32	.next			; 00-03 ;
res32	.previous		; 04-07 ;
endstruc			; ----- ;
;------------------------------------------------------------------------------




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
struc _rt_thread_t              ; ----- ; -------------------------------------
res64   .execution_start        ; 00-07 ; start time
.start_ring	resb _rt_ring_links_size;
res64   .execution_end          ; 10-17 ; number of microseconds of execution
.end_ring	resb _rt_ring_links_size;
res32   .top_of_stack           ; 20-23 ; active TOS (ESP)
res32	.bottom_of_stack	; 24-27 ; Lowest allowed ESP
res32   .process_id             ; 28-2B ; ID of parent process
res32   .event_notifier         ; 2C-2F ; callback for event forwarding
res32   .event_mask		; 30-33 ; mask some event types
res32	.thread_pool		; 34-37 ;
res8    .execution_priority	; 38-38 ; selected execution priority
res8	.locked_mutexes		; 39-39 ; number of locked mutexes
res8	.execution_status	; 3A-3A ; execution status
res8	.flags			; 3B-3B ; thread flags
%ifdef RT_SANITY_CHECKS		; -- -- ;
res32	.magic			; 3C-3F ;
%endif				; -- -- ;
endstruc                        ; ----- ; -------------------------------------
;------------------------------------------------------------------------------



; Thread Pools
;------------------------------------------------------------------------------
; Structure grouping together 32 threads (stack and header), an allocation
; bitmap and a ring structure.  Thread acquisition requests are searching
; the thread pools for a free thread entry using the allocation bitmap.  If
; no free thread is available they move on to the next thread pool until all
; pools have been searched.
;------------------------------------------------------------------------------
struc _rt_thread_pool_t		; ----- ; -------------------------------------
.ring		resb _rt_ring_links_size; ring to other thread pools
res32	.bitmap			;   -   ; thread allocation bitmap
%ifdef RT_SANITY_CHECKS
res32	.magic			;   -   ; magic thread pool identifier
%endif
.threads	resb _STACK_SIZE_ * 32	; thread headers and stacks
endstruc			; ----- ; -------------------------------------
;------------------------------------------------------------------------------




; Mutex
;------------------------------------------------------------------------------
; This is the structure used for mutexes, which are dynamically allocated 
; unless fine-tuning is done by a third-party in a fixed version development
; environment.
;
;------------------------------------------------------------------------------
struc _rt_mutex_t		; ----- ; -------------------------------------
res32	.holding_thread		;   -   ; thread currently holding the lock
res32	.magic			;   -   ;
.wait_queue	resb _rt_ring_links_size;
endstruc			; ----- ; -------------------------------------
;------------------------------------------------------------------------------
;
; IMPORTANT NOTE:
;
; In order to optimize the link/unlink process of threads in mutex wait queue,
; the mutex is acting as a valid thread header member in a ring.  It is of
; the utmost importance that '.next_link' and '.previous_link' are exactly at
; the same offset within the _rt_mutex_t structure as their equivalent in the
; _rt_thread_t structure.
;
;
; Unlocking procedure:
;
; Remove from the wait queue all threads and reschedule them according to
; their priorities, then set the .holding_thread value to 0.  From this
; point the mutex is marked as unlocked.
;
; Once completed, the '.locked_mutexes' count in the _rt_thread_t header should
; be decremented.
;
; If the thread was running on lended time (see '.flags' in _rt_thread_t) the
; thread should be prempted with the highest priority thread in the system.
;
;
; Locking procedure from mutex_lock:
;
; Compare the value of '.holding_thread' with 0, if held true then the mutex
; is free and can be locked by simply filling this value with the current
; thread ID.
;
; In the event where it would be held false, the current thread should be
; placed in the wait queue.
;
;------------------------------------------------------------------------------











;                                    .---.
;                                   /     \
;                                   | - - |
;                                  (| ' ' |)
;                                   | (_) |   o
;                                   `//=\\' o
;                                   (((()))
;                                    )))((
;                                    (())))
;                                     ))((
;                                     (()
;                                 jgs  ))
;                                      (
;
;
;                       i n i t i a l i z e d   d a t a
section .data



; Timer Queues
;------------------------------------------------------------------------------
; Ring list containing all scheduled threads sorted by their execution start
; time.  This list is used to determine when to move a thread from scheduled
; to executing status and queue them for execution.
;
; This ring list uses the _rt_thread_t members '.next_link' and
; '.previous_link'.
queue:
.start_run_timers:	istruc _rt_ring_links
		at _rt_ring_links.next,		dd queue.start_run_timers
		at _rt_ring_links.previous,	dd queue.start_run_timers
			iend
;
; End run timers
;------------------------------------------------------------------------------
; Ring list containing all scheduled, waiting, executing and sleeping threads
; sorted by their execution end time.  This list is used to generate event to
; thread event notifier callbacks to notice when a thread execution could not
; be finished before its set deadline.
;
; This ring list uses the _rt_thread_t members '.endrun_next_link' and
; '.endrun_previous_link'.
.end_run_timers:	istruc _rt_ring_links
		at _rt_ring_links.next,		dd queue.end_run_timers
		at _rt_ring_links.previous,	dd queue.end_run_timers
			iend
;------------------------------------------------------------------------------



; Thread Pools Ring
;------------------------------------------------------------------------------
thread_pools_ring:	istruc _rt_ring_links
		at _rt_ring_links.next,		dd thread_pools_ring
		at _rt_ring_links.previous,	dd thread_pools_ring
			iend
;------------------------------------------------------------------------------








;                                    .---.
;                                   /     \
;                                   | - - |
;                                  (| ' ' |)
;                                   | (_) |   o
;                                   `//=\\' o
;                                   (((()))
;                                    )))((
;                                    (())))
;                                     ))((
;                                     (()
;                                 jgs  ))
;                                      (
;
;
;                       u n i n i t i a l i z e d   d a t a
section .bss



; Pre-Allocated Thread Pools
;------------------------------------------------------------------------------
; In order to allow the scheduler to be started and ran without the presence
; of a memory manager, some thread pools are pre-allocated.  The number of
; pre-allocated thread pools is controled by the '_THREAD_POOLS_' variable.
;
; Each thread pool contain 32 threads, see the _rt_thread_pool_t structure
; declaration for more information.
;------------------------------------------------------------------------------
pre_allocated_thread_pools:			;
  resb _THREAD_POOLS_ * _rt_thread_pool_t_size	;
;------------------------------------------------------------------------------











;                                    .---.
;                                   /     \
;                                   | - - |
;                                  (| ' ' |)
;                                   | (_) |   o
;                                   `//=\\' o
;                                   (((()))
;                                    )))((
;                                    (())))
;                                     ))((
;                                     (()
;                                 jgs  ))
;                                      (
;
;
;                         l o c a l   f u n c t i o n s
section .text



;----------------------------------------------------------[ SANITY CONTROL ]--
; This function only purpose is to handle sanity checks during development
; and test phases.
;
%ifdef RT_SANITY_CHECKS
 %ifdef RT_SANITY_DEVBENCH
sanity_check_failed:
[section .data]
 .string: dd 0
 .eax: dd 0
 .ecx: dd 0
 .edx: dd 0
 .ebx: dd 0
 .esp: dd 0
 .ebp: dd 0
 .esi: dd 0
 .edi: dd 0
__SECT__
  mov [.eax], eax
  mov [.ecx], ecx
  mov [.edx], edx
  mov [.ebx], ebx
  mov [.esp], esp
  mov [.ebp], ebp
  mov [.esi], esi
  mov [.edi], edi
  mov eax, [.string]
  mov ebx, .dump_registers
  extern _display_string
  jmp _display_string
.dump_registers:
  mov eax, .eax
  extern _emergency_exit
  mov ebx, _emergency_exit
  extern _dump_registers
  jmp _dump_registers
 %endif
%endif
;------------------------------------------------------------------------------







__set_timer:
;--------------------------------------------------------------[ set timer ]--
;>
;; Reprogram the PIT and sets the number of full timer expirations for a given
;; microsecond delay.
;;
;; parameters
;; ----------
;; eax = number of microseconds before allowing interruption
;;
;;
;; returns
;; -------
;; eax = destroyed
;; edx = destroyed
;; pit_ticks = number of full expiration to let go
;<
;-----------------------------------------------------------------------------
%ifdef _RT_TIMER_TICKS_				;-timer is in PIT ticks
  mov edx, eax					; move tick count in edx
						; edx: tick count
						;
%else						;-timer is in microseconds
  shl  eax, _PIT_ADJ_SHIFT_REQUIRED_            ; adjust microseconds for mul
  mov  edx, _PIT_ADJ_MULT_                      ; magic multiplier
  mul  edx                                      ; magic mul, get ticks count
%endif						; edx: tick count
						;
  mov  al, 0x36                                 ; select channel 0
  out  0x43, al                                 ; send op to command port
  xchg eax, edx                                 ; move tick count in eax
  and  ah, 0x7F                                 ; keep only the lowest 15bits
  out  0x40, al                                 ; send low 8bits of tick count
  mov  al, ah                                   ; get high 7bits of tick count
  out  0x40, al                                 ; send it
  retn                                          ; return to caller
;-----------------------------------------------------------------------------
;     8253 Mode Control Register, data format: 
;
;        |7|6|5|4|3|2|1|0|  Mode Control Register
;         | | | | | | | ----- 0=16 binary counter, 1=4 decade BCD counter
;         | | | | ---------- counter mode bits
;         | | ------------- read/write/latch format bits
;         ---------------- counter select bits (also 8254 read back command)
;
;        Bits
;         76 Counter Select Bits
;         00  select counter 0
;         01  select counter 1
;         10  select counter 2
;         11  read back command (8254 only, illegal on 8253, see below)
;
;        Bits
;         54  Read/Write/Latch Format Bits
;         00  latch present counter value
;         01  read/write of MSB only
;         10  read/write of LSB only
;         11  read/write LSB, followed by write of MSB
;
;        Bits
;        321  Counter Mode Bits
;        000  mode 0, interrupt on terminal count;  countdown, interrupt,
;             then wait for a new mode or count; loading a new count in the
;             middle of a count stops the countdown
;        001  mode 1, programmable one-shot; countdown with optional
;             restart; reloading the counter will not affect the countdown
;             until after the following trigger
;        010  mode 2, rate generator; generate one pulse after 'count' CLK
;             cycles; output remains high until after the new countdown has
;             begun; reloading the count mid-period does not take affect
;             until after the period
;        011  mode 3, square wave rate generator; generate one pulse after
;             'count' CLK cycles; output remains high until 1/2 of the next
;             countdown; it does this by decrementing by 2 until zero, at
;             which time it lowers the output signal, reloads the counter
;             and counts down again until interrupting at 0; reloading the
;             count mid-period does not take affect until after the period
;        100  mode 4, software triggered strobe; countdown with output high
;             until counter zero;  at zero output goes low for one CLK
;             period;  countdown is triggered by loading counter;  reloading
;             counter takes effect on next CLK pulse
;        101  mode 5, hardware triggered strobe; countdown after triggering
;             with output high until counter zero; at zero output goes low
;             for one CLK period
; 
;-----------------------------------------------------------------------------










__prepend_to_queue:
;--------------------------------------------------------[ prepend to queue ]--
;>
;; Prepend a thread to a ring list queue.
;;
;; parameters:
;;   eax = pointer to thread ring links
;;   ebx = pointer to queue ring links
;;
;; returns:
;;   -nothing-
;<
;------------------------------------------------------------------------------
%ifdef RT_SANITY_CHECKS				;-o
 cmp [eax + _rt_ring_links.next], eax		; thread points back to itself?
 jnz short .failed_sanity			; no? failed
 cmp [eax + _rt_ring_links.previous], eax	; thread points back to itself?
 jnz short .failed_sanity			; no? failed
%endif						;--o
						;
  mov ecx, [ebx + _rt_ring_links.next]		; Load first ring member
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp [ecx + _rt_ring_links.previous], ebx	; Make sure member points back
 jnz short .failed_sanity			; ZF=0? guess it doesn't, fail
%endif						;--o
						;
  mov [eax + _rt_ring_links.next], ecx		; set thrd next to 1st member
  mov [eax + _rt_ring_links.previous], ebx	; set thrd previous to head
  mov [ebx + _rt_ring_links.next], eax		; head point to thread
  mov [ecx + _rt_ring_links.previous], eax	; 1st member point to thread
  retn						; return to caller TODO
						;
%ifdef RT_SANITY_CHECKS				;-o
 %ifdef RT_SANITY_DEVBENCH
[section .data]					; declare some data
.str:						;
 db .str_end - $ - 1				;
 db "sanity check failed in __prepend_to_queue", 0x0A
 .str_end:					;
__SECT__					; return to code section
.failed_sanity:					;
 mov [sanity_check_failed.string], dword .str	; error message to display
 jmp sanity_check_failed			; go display it
 %else
.failed_sanity:
  %error "return macro not yet included!"	; TODO
 %endif
%endif						;--o
;------------------------------------------------------------------------------








__link_to_ordered_queue:
;---------------------------------------------------[ link to ordered queue ]--
;>
;; Link a thread into a ordered ring list.  The ordering value for both the
;; ring list members and the thread is a 64bit value located prior to the 
;; ring links.
;;
;;
;; parameters:
;;   eax = pointer to thread ring links
;;   ebx = pointer to queue ring links
;;
;; returns:
;;   -nothing-
;;
;;
;; IMPORTANT NOTE:
;;
;; This function expects a 64bit ordering value to be localized immediately
;; prior to the thread ring links.
;<
;------------------------------------------------------------------------------
%ifdef RT_SANITY_CHECKS				;-o
 cmp [eax + _rt_ring_links.next], eax		; thread points back to itself?
 jnz short .failed_sanity			; no? failed
 cmp [eax + _rt_ring_links.previous], eax	; thread points back to itself?
 jnz short .failed_sanity			; no? failed
%endif						;--o
						;
  push edi					; back up current edi
  push esi					; back up current esi
  mov edi, [byte eax - 4]			; load high 32bits
  mov esi, [byte eax - 8]			; complete edi:esi 64bit value
  						;
						; edi:esi is the value by which
						; ordering is decided.  Search
						; for insertion point.
						;
  mov ecx, [ebx + _rt_ring_links.next]		; load first ring member
  mov edx, ebx					; set ref to previous member
.check_complete_round:				;
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp [ecx + _rt_ring_links.previous], edx	; next member points back?
 jnz short .failed_sanity			; if not, invalid next member
%endif						;--o
						;
  cmp ecx, ebx					; did we do a complete round?
  jz short .insert_point_localized		; yes, insert as last member
						;
  cmp edi, [byte ecx - 4]			; compare high 32bits
  jb short .insert_point_localized		; value is lower, insert prior
  cmp esi, [byte ecx - 8]			; compare low 32bits
  jbe short .insert_point_localized		; value is lower or equal
						;
						; greater than current member
						;
  mov edx, ecx					; update ref to previous member
  mov ecx, [ecx + _rt_ring_links.next]		; move to next member
  jmp short .check_complete_round		; attempt another cycle
						;
.insert_point_localized:			; insert between ecx and edx
  pop esi					; restore original esi
  mov [eax + _rt_ring_links.next], ecx		; set thread ring next link
  mov [eax + _rt_ring_links.previous], edx	; set thread ring previous link
  pop edi					; restore original edi
  mov [edx + _rt_ring_links.next], eax		; set ring next to thread
  mov [ecx + _rt_ring_links.previous], eax	; set ring previous to thread
  retn						; return to caller TODO
						;
%ifdef RT_SANITY_CHECKS				;-o
 %ifdef RT_SANITY_DEVBENCH
[section .data]					; declare some data
.str:						;
 db .str_end - $ - 1				;
 db "failed sanity check in __link_to_ordered_queue", 0x0A
 .str_end:					;
__SECT__					; select back the code section
.failed_sanity:					;
 mov [sanity_check_failed.string], dword .str	; error message to display
 jmp sanity_check_failed			; display it
 %else
.failed_sanity:
  %error "return macro not yet included!"	; TODO
 %endif
%endif						;--o
;------------------------------------------------------------------------------





__unlink_from_queue:
;-------------------------------------------------------[ unlink from queue ]--
;>
;; Unlink a thread from a ring list.
;;
;;
;; parameters:
;;   eax = pointer to thread ring links
;;
;; returns:
;;   -nothing-
;<
;------------------------------------------------------------------------------
  mov ebx, [eax + _rt_ring_links.next]		; load member after thread
  mov ecx, [eax + _rt_ring_links.previous]	; load member previos to thread
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp [ebx + _rt_ring_links.previous], eax	; next member points to thread?
 jnz short .failed_sanity			; no? well, invalid pointer
 cmp [ecx + _rt_ring_links.next], eax		; prev member points to thread?
 jnz short .failed_sanity			; no? well, invalid pointer
 cmp ebx, eax					; next member = thread?
 jz short .already_unlinked			; yes? oops, did it twice!
%endif						;--o
						;
  mov [ebx + _rt_ring_links.previous], ecx	; close previous ring member
  mov [ecx + _rt_ring_links.next], ebx		; close next ring member
						;
%ifdef RT_SANITY_CHECKS				;-o
 mov [eax + _rt_ring_links.next], eax		; loop back thread next link
 mov [eax + _rt_ring_links.previous], eax	; loop back thread previous lnk
%endif						;--o
						;
  retn						; return to the caller
						;
%ifdef RT_SANITY_CHECKS				;-o
 %ifdef RT_SANITY_DEVBENCH
[section .data]					; declare some data
.str_failed:					;
 db .end_failed - $ - 1				;
 db "failed sanity check in __unlink_from_queue", 0x0A
 .end_failed:					;
.str_unlinked:					;
 db .end_unlinked - $ - 1			;
 db "thread already unlinked in __unlink_from_queue", 0x0A
 .end_unlinked:
__SECT__					; select back the code section
						;
.failed_sanity:					;
 mov [sanity_check_failed.string], dword .str_failed	; error message to display
 jmp sanity_check_failed			; display it
						;
.already_unlinked:				;
 mov [sanity_check_failed.string], dword .str_unlinked	; error message to display
 jmp sanity_check_failed			; display it
 %else
.failed_sanity:
.already_unlinked:
  %error "return macro not yet included!"
 %endif
%endif						;--o
;------------------------------------------------------------------------------












;                                    .---.
;                                   /     \
;                                   | - - |
;                                  (| ' ' |)
;                                   | (_) |   o
;                                   `//=\\' o
;                                   (((()))
;                                    )))((
;                                    (())))
;                                     ))((
;                                     (()
;                                 jgs  ))
;                                      (
;
;
;                        g l o b a l   f u n c t i o n s
section .text





;-------------------------------------------------[ realtime thread acquire ]--
global rthrd_acquire
rthrd_acquire:
;!<proc>
;! <ret fatal="0" brief="allocation succesfull">
;!  <r reg="eax" brief="pointer to allocated thread"/>
;! </ret>
;! <ret fatal="1" brief="allocation failed - out of thread"/>
;! <ret fatal="2" brief="scheduler sanity failure"/>
;!</proc>
;------------------------------------------------------------------------------

  mov	eax, thread_pools_ring			;
  mov	ebx, eax				;
						;
.attempt_next_pool:				;
%ifdef RT_SANITY_CHECKS				;-o
 mov ecx, ebx					;
%endif						;--o
						;
  mov	ebx, [byte ebx + _rt_ring_links.next]	;
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp eax, thread_pools_ring			;
 jnz .failed_sanity_check_eax			;
 cmp ecx, [byte ebx + _rt_ring_links.previous]	;
 jnz .failed_sanity_check_ring			;
%endif						;--o
						;
  cmp	ebx, eax				;
  jz	short .out_of_thread			;
						;
%ifdef RT_SANITY_CHECKS				;-o
 cmp dword [byte ebx + _rt_thread_pool_t.magic], RT_THREAD_POOL_MAGIC
 jnz .failed_sanity_check_magic			;
%endif						;--o
						;
  bsf	ecx, dword [ebx + _rt_thread_pool_t.bitmap]
  jz	short .attempt_next_pool		;
						;
						;} mark thread bit as busy
  mov   eax, 1					;
  shl   eax, cl					; select thread identity bit
  xor   [byte ebx + _rt_thread_pool_t.bitmap], eax; invert it (set to 0)
						;
						;} compute thread ID
						;
  inc	ecx					; adjust to top of thread
  shl	ecx, _LOG_STACK_SIZE_			; multiply by the stack size
  lea	eax, [byte ecx + ebx + (_rt_thread_pool_t.threads - _rt_thread_t_size)]
						; add thread pool base address
						; add offset to first thread
						; remove size of _rt_thread_t
; additional information:
;------------------------
; The thread ID should now point to the TOS (Top Of Stack) for that thread.
; The space above this address is the thread header, and below is the stack.
;
; Therefore the upper limit of the thread reserved space should match
; the sum of the thread ID + the size of the _rt_thread_t structure.
;
; The lower limit should equal (upper limit - _STACK_SIZE_)
;
						;} compute stack bottom address
						;
  lea	edx, [ebx + (_rt_thread_t_size - _STACK_SIZE_ )]
  mov	[eax + _rt_thread_t.bottom_of_stack], edx
						;
  mov	[eax + _rt_thread_t.thread_pool], ebx	;
						;
%ifdef RT_SANITY_CHECKS				;
 cmp	eax, ebx				;
 jb	short .failed_sanity_check_thread_id	;
 add	ebx, (_STACK_SIZE_ * 32) + _rt_thread_pool_t_size - _rt_thread_t_size
 cmp	eax, ebx				;
 ja	short .failed_sanity_check_thread_id	;
 mov	[eax + _rt_thread_t.start_ring + _rt_ring_links.next], eax
 mov	[eax + _rt_thread_t.start_ring + _rt_ring_links.previous], eax
 mov	[eax + _rt_thread_t.end_ring + _rt_ring_links.next], eax
 mov	[eax + _rt_thread_t.end_ring + _rt_ring_links.previous], eax
 mov	[eax + _rt_thread_t.magic], dword RT_THREAD_MAGIC
%endif						;
  mov	[eax + _rt_thread_t.execution_status], byte RT_SCHED_STATUS_UNSCHEDULED
  mov	[eax + _rt_thread_t.flags], byte 0	;
  clc						; indicate success
  retn						; -done- EAX: Thread ID - TODO
						;
.out_of_thread:					;
  stc
  retn						; TODO: fix with new return macro

%ifdef RT_SANITY_CHECKS				;
 %ifdef RT_SANITY_DEVBENCH
[section .data]
.sanity_eax:
  db .sanity_eax_end - $ - 1
  db "thrd_acquire: eax was modified - does not point to thread_pools_ring anymore", 0x0A
  .sanity_eax_end:
.sanity_ring:
  db .sanity_ring_end - $ - 1
  db "thrd_acquire: thread pool ring sanity failed", 0x0A
  .sanity_ring_end:
.sanity_magic:
  db .sanity_magic_end - $ - 1
  db "thrd_acquire: thread pool magic failure", 0x0A
  .sanity_magic_end
.sanity_id:
  db .sanity_id_end - $ - 1
  db "thrd_acquire: thread id out of thread pool bounds", 0x0A
  .sanity_id_end:
__SECT__
.failed_sanity_check_eax:
 mov [sanity_check_failed.string], dword .sanity_eax	; error message to display
 jmp sanity_check_failed			; display it
.failed_sanity_check_ring:
 mov [sanity_check_failed.string], dword .sanity_ring	; error message to display
 jmp sanity_check_failed			; display it
.failed_sanity_check_magic:
 mov [sanity_check_failed.string], dword .sanity_magic	; error message to display
 jmp sanity_check_failed			; display it
.failed_sanity_check_thread_id:
 mov [sanity_check_failed.string], dword .sanity_id	; error message to display
 jmp sanity_check_failed			; display it
 %else
.failed_sanity_check_eax:
.failed_sanity_check_ring:
.failed_sanity_check_magic:
.failed_sanity_check_thread_id:
  %error "return macro not yet included!"	; TODO
 %endif
%endif
;-------------------------------------------------[/realtime thread acquire ]--



;-------------------------------------------------[ realtime thread release ]--
global rthrd_release
rthrd_release:
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to thread to release"/>
;! <ret fatal="0" brief="deallocation succesfull"/>
;! <ret fatal="1" brief="allocation failed - thread is being used"/>
;! <ret fatal="2" brief="scheduler sanity failure"/>
;!</proc>
;------------------------------------------------------------------------------
%ifdef RT_SANITY_CHECKS
 cmp	[eax + _rt_thread_t.magic], dword RT_THREAD_MAGIC
 jnz	short .failed_sanity_check_magic
%endif

  cmp	[eax + _rt_thread_t.execution_status], byte RT_SCHED_STATUS_UNSCHEDULED
  jnz	short .thread_is_in_use
 
.thread_is_in_use:


%ifdef RT_SANITY_CHECKS
 %ifdef RT_SANITY_DEVBENCH
[section .data]
.sanity_magic:
  db .sanity_magic_end - $ - 1
  db "rthrd_release: magic failed on provided thread", 0x0A
  .sanity_magic_end:
__SECT__
.failed_sanity_check_magic:
 mov [sanity_check_failed.string], dword .sanity_magic	; error message to display
 jmp sanity_check_failed			; display it
 %else
.failed_sanity_check_magic:
  %error "return macro not yet included!"
 %endif
%endif
;-------------------------------------------------[/realtime thread release ]--








;
; The timers are all registered, no matter their priority, in a single queue
;
; Once a timer expires, the associated thread is scheduled in its priority queue and its associated runtime expiration is marked.
;
; Threads are executed in priority, from the lowest priority value to the highest.
;
;
; RT Scheduler algorithm:
; -----------------------
;
; New thread scheduling:
;  - Check if time is future or past
;
;  > future time:
;   
;    register a timer for the scheduler
; 
;  > past time:
;
;    register the thread for execution in its priority queue
;
; Tick interrupt handler:
;    look for 
;  1 look for all expiring timer and register the threads for execution in their respective priority queues
;  2 select the highest priority thread to execute
;  3 if its a different thread, load it
;  4 check thread runtime expiration, if expired send expiration notice and go to 2




global _test_sequence
_test_sequence:
  retn




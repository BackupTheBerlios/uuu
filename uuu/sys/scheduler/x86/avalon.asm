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
%define SANITY_CHECKS
;
; Sanity check is performed the same under the dev bench as outside, but some
; additional information is only provided inside the dev bench. Uncomment the
; next line to enable that additional information.
%define RT_SANITY_VERBOSE
;
; Those values are magic markers to help detect invalid pointers/corruption
%define RT_THREAD_MAGIC		'thrmagic'
%define RT_THREAD_POOL_MAGIC	'thpomagi'
;------------------------------------------------------------------------------




%include "ring_queue.asm"
%include "thread.asm"
%include "ret_counts.asm"





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





; Thread Pools
;------------------------------------------------------------------------------
; Structure grouping together 32 threads (stack and header), an allocation
; bitmap and a ring structure.  Thread acquisition requests are searching
; the thread pools for a free thread entry using the allocation bitmap.  If
; no free thread is available they move on to the next thread pool until all
; pools have been searched.
;------------------------------------------------------------------------------
struc _rt_thread_pool_t		; ----- ; -------------------------------------
.ring		resb _ring_queue_t_size	; ring to other thread pools
.bitmap		resd 1		;   -   ; thread allocation bitmap
.magic		resd 1		;   -   ; magic thread pool identifier
.threads	resb _STACK_SIZE_ * 32	; thread headers and stacks
endstruc			; ----- ; -------------------------------------
;------------------------------------------------------------------------------
;
; Thread Stack
;------------------------------------------------------------------------------
; Describes the order the information is stored on stack from top (highest
; address) to bottom (lowest address).  This structure should be used for
; INVERSE address adjustment. For example, if eax points to the current TOS,
; one would do [eax - _thread_stack_t.eip - 4] to access eip and would do
; [eax - _thread_stack_t.edi - 4] to access edi.
;------------------------------------------------------------------------------
struc _thread_stack_t
.eip		resd 1
.eflags		resd 1
.eax		resd 1
.ecx		resd 1
.edx		resd 1
.ebx		resd 1
.esp		resd 1
.ebp		resd 1
.esi		resd 1
.edi		resd 1
endstruc
;------------------------------------------------------------------------------




;------------------------------------------------------------------------------
;
; IMPORTANT NOTE:
;
; In order to optimize the link/unlink process of threads in mutex wait queue,
; the mutex is acting as a valid thread header member in a ring.  It is of
; the utmost importance that '.next_link' and '.previous_link' are exactly at
; the same offset within the _rt_mutex_t structure as their equivalent in the
; _thread_t structure.
;
;
; Unlocking procedure:
;
; Remove from the wait queue all threads and reschedule them according to
; their priorities, then set the .holding_thread value to 0.  From this
; point the mutex is marked as unlocked.
;
; Once completed, the '.locked_mutexes' count in the _thread_t header should
; be decremented.
;
; If the thread was running on lended time (see '.flags' in _thread_t) the
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
; This ring list uses the _thread_t members '.next_link' and
; '.previous_link'.
queue:
.start_run_timers:	def_ring_queue
;
; End run timers
;------------------------------------------------------------------------------
; Ring list containing all scheduled, waiting, executing and sleeping threads
; sorted by their execution end time.  This list is used to generate event to
; thread event notifier callbacks to notice when a thread execution could not
; be finished before its set deadline.
;
; This ring list uses the _thread_t members '.endrun_next_link' and
; '.endrun_previous_link'.
.end_run_timers:	def_ring_queue
;------------------------------------------------------------------------------



; Thread Pools Ring
;------------------------------------------------------------------------------
thread_pools_ring:	def_ring_queue
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
gproc thrd.acquire
;!<proc>
;! <ret fatal="0" brief="allocation succesfull">
;!  <r reg="eax" brief="pointer to allocated thread"/>
;! </ret>
;! <ret fatal="1" brief="allocation failed - out of thread"/>
;!</proc>
;------------------------------------------------------------------------------
  mov	eax, thread_pools_ring			;
  mov	ebx, eax				;
						;
.attempt_next_pool:				;
%ifdef SANITY_CHECKS				;-o
 mov ecx, ebx					;
%endif						;--o
						;
  mov	ebx, [byte ebx + _ring_queue_t.next]	;
						;
%ifdef SANITY_CHECKS				;-o
 cmp eax, thread_pools_ring			;
 jnz .failed_sanity_check_eax			;
 cmp ecx, [byte ebx + _ring_queue_t.previous]	;
 jnz .failed_sanity_check_ring			;
%endif						;--o
						;
  cmp	ebx, eax				;
  jz	short .out_of_thread			;
						;
%ifdef SANITY_CHECKS				;-o
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
  lea	eax, [byte ecx + ebx + (_rt_thread_pool_t.threads - _thread_t_size)]
						; add thread pool base address
						; add offset to first thread
						; remove size of _thread_t
; additional information:
;------------------------
; The thread ID should now point to the TOS (Top Of Stack) for that thread.
; The space above this address is the thread header, and below is the stack.
;
; Therefore the upper limit of the thread reserved space should match
; the sum of the thread ID + the size of the _thread_t structure.
;
; The lower limit should equal (upper limit - _STACK_SIZE_)
;
						;} compute stack bottom address
						;
  lea	edx, [ebx + (_thread_t_size - _STACK_SIZE_ )]
  mov	[eax + _thread_t.bottom_of_stack], edx
						;
  mov	[eax + _thread_t.thread_pool], ebx	;
						;
%ifdef SANITY_CHECKS				;
 cmp	eax, ebx				;
 jb	short .failed_sanity_check_thread_id	;
 add	ebx, (_STACK_SIZE_ * 32) + _rt_thread_pool_t_size - _thread_t_size
 cmp	eax, ebx				;
 ja	short .failed_sanity_check_thread_id	;
 mov	[eax + _thread_t.start_ring + _ring_queue_t.next], eax
 mov	[eax + _thread_t.start_ring + _ring_queue_t.previous], eax
 mov	[eax + _thread_t.end_ring + _ring_queue_t.next], eax
 mov	[eax + _thread_t.end_ring + _ring_queue_t.previous], eax
 mov	[eax + _thread_t.magic], dword RT_THREAD_MAGIC
%endif						;
  mov	[eax + _thread_t.execution_status], byte RT_SCHED_STATUS_UNSCHEDULED
  mov	[eax + _thread_t.flags], byte 0	;
  return					;
						;
.out_of_thread:					;
  return 1					;
						;
%ifdef SANITY_CHECKS				;
 %ifdef RT_SANITY_VERBOSE
[section .data]
.sanity_eax:
  uuustring "rthrd_acquire: eax was modified - does not point to thread_pools_ring anymore", 0x0A
.sanity_ring:
  uuustring "rthrd_acquire: thread pool ring sanity failed", 0x0A
.sanity_magic:
  uuustring "rthrd_acquire: thread pool magic failure", 0x0A
.sanity_id:
  uuustring "rthrd_acquire: thread id out of thread pool bounds", 0x0A
__SECT__
.failed_sanity_check_eax:			;
 mov ebx, .sanity_eax				;
 jmp short .failed_sanity_common		;
						;
.failed_sanity_check_ring:			;
 mov ebx, dword .sanity_ring			;
 jmp short .failed_sanity_common		;
						;
.failed_sanity_check_magic:			;
 mov ebx, dword .sanity_magic			;
 jmp short .failed_sanity_common		;
						;
.failed_sanity_check_thread_id:			;
 mov ebx, dword .sanity_id			;
.failed_sanity_common:				;
 %else						;
						;
.failed_sanity_check_eax:			;
.failed_sanity_check_ring:			;
.failed_sanity_check_magic:			;
.failed_sanity_check_thread_id:			;
 xor ebx, ebx					;
 %endif						;
 xor eax, eax					; TODO : set error code
 ret_other					;
%endif						;
;-------------------------------------------------[/realtime thread acquire ]--



;-------------------------------------------------[ realtime thread release ]--
gproc thrd.release
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to thread to release"/>
;! <ret fatal="0" brief="deallocation succesfull"/>
;! <ret fatal="1" brief="allocation failed - thread is being used"/>
;!</proc>
;------------------------------------------------------------------------------
%ifdef SANITY_CHECKS				;
 cmp	[eax + _thread_t.magic], dword RT_THREAD_MAGIC
 jnz	short .failed_sanity_check_magic	;
%endif						;
						;
  cmp	[eax + _thread_t.execution_status], byte RT_SCHED_STATUS_UNSCHEDULED
  jnz	short .thread_is_in_use			;
						;
.thread_is_in_use:				;
						;
						;
%ifdef SANITY_CHECKS				;
 %ifdef RT_SANITY_VERBOSE			;
[section .data]					;
.sanity_magic:					;
  uuustring "rthrd_release: magic failed on provided thread", 0x0A
__SECT__					;
.failed_sanity_check_magic:			;
 mov ebx, dword .sanity_magic			;
 %else						;
.failed_sanity_check_magic:			;
 xor ebx, ebx					;
 %endif						;
 xor eax, eax					; TODO : set error code
 ret_other					;
%endif						;
;-------------------------------------------------[/realtime thread release ]--




gproc thrd.initialize
;----------------------------------------------[ realtime thread initialize ]--
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to thread to initialize"/>
;! <p reg="ebx" type="pointer" brief="callback to use for event notification"/>
;! <p reg="ecx" type="pointer" brief="pointer to give as parameter to the thread"/>
;! <p reg="edx" type="pointer" brief="address at which to start thread execution"/>
;! <ret fatal="0" brief="initialization completed"/>
;! <ret fatal="1" brief="initialization failed - thread is being used"/>
;!</proc>
;------------------------------------------------------------------------------
						; validate thread pointer
%ifdef SANITY_CHECKS				;------------------------------
 cmp dword [eax + _thread_t.magic], RT_THREAD_MAGIC
 jnz short .sanity_check_failed_magic		;
%endif						;
						; make sure the thread is
						; not currently scheduled
						;------------------------------
  cmp byte [eax + _thread_t.execution_status], byte RT_SCHED_STATUS_UNSCHEDULED 
  jz short .thread_in_use			;
						; also verify it is unlinked
%ifdef SANITY_CHECKS				;------------------------------
 add eax, byte _thread_t.start_ring		;
 cmp eax, [eax]					;
 jnz short .sanity_check_failed_linked		;
 add eax, byte (_thread_t.end_ring - _thread_t.start_ring)
 cmp eax, [eax]					;
 jnz short .sanity_check_failed_linked		;
 sub eax, byte _thread_t.end_ring		;
%endif						;
						; set event notification hndlr
						;------------------------------
  mov [eax + _thread_t.event_notifier], ebx	;
						;
; additional information:
;------------------------
; The stack should contain, after initialization, the following values from
; top to bottom (structure _thread_stack_t):
;
;   eip, eflags, eax, ecx, edx, ebx, esp, ebp, esi, edi
;
; The pointer to pass to the application has parameter is stored in 'eax'.
; The ecx, edx, ebx, ebp, esi and edi registers will be 0, esp is set to
; the thread ID.
;
; Let's define a small macro to simplify the addressing:
%define STACK(x) eax - (_thread_stack_t. %+ x + 4)
						; set initial register values
						;------------------------------
  xor ebx, ebx					;
  mov [STACK(edi)], ebx				; edi = 0
  mov [STACK(esi)], ebx				; esi = 0
  mov [STACK(ebp)], ebx				; ebp = 0
  mov [STACK(esp)], eax				; esp = pointer to top of stack
  mov [STACK(ebx)], ebx				; ebx = 0
  mov [STACK(edx)], ebx				; edx = 0
  mov [STACK(ecx)], ebx				; ecx = 0
  mov [STACK(eax)], ecx				; eax = parameter to thread
  mov [STACK(eflags)], dword _THREAD_INITIAL_EFLAGS_
  mov [STACK(eip)], edx				; eip = initial control address
						;
						; set stack boundaries
						;------------------------------
  lea ebx, [eax - _thread_stack_t_size]		; 
  lea ecx, [eax + (_thread_t_size - _STACK_SIZE_)]
  mov [eax + _thread_t.top_of_stack], ebx	; top...
  mov [eax + _thread_t.bottom_of_stack], ecx	; bottom...done
						;
						; mark thread as initialized
						;------------------------------
  or [eax + _thread_t.flags], byte RT_FLAGS_INIT_STATUS
  return					;
						;
.thread_in_use:					;
  return 1					;
						;
%ifdef SANITY_CHECKS				; Sanity Handlers
[section .data]					;------------------------------
.sanity_magic:					;
  uuustring "thrd.initialize thread pointer failed magic check", 0x0A
.sanity_linked:
  uuustring "thrd.initialize thread is linked but unscheduled..sanity failed", 0x0A
__SECT__					;
.sanity_check_failed_linked:			;
  mov ebx, .sanity_linked			;
  jmp short .sanity_common			;
.sanity_check_failed_magic:			;
  mov ebx, .sanity_magic			;
.sanity_common:					;
  xor eax, eax					;
  ret_other					;
%endif						;
;----------------------------------------------[/realtime thread initialize ]--




gproc thrd.schedule
;------------------------------------------------[ realtime thread schedule ]--
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to thread to schedule"/>
;! <p reg="ebx" type="uinteger32" brief="inverse priority to set"/>
;! <p reg="ecx" type="pointer" brief="pointer to uuutime start time"/>
;! <p reg="edx" type="pointer" brief="pointer to uuutime deadline"/>
;! <ret fatal="0" brief="thread scheduled"/>
;! <ret fatal="1" brief="deadline already expired"/>
;! <ret fatal="2" brief="failed to scheduled - thread is being used"/>
;! <ret fatal="3" brief="thread not properly initialized"/>
;!</proc>
;------------------------------------------------[/realtime thread schedule ]--
  ret_other




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







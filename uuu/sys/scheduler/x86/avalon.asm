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
%define _RT_TIMER_FORMAT_	TICKS
;%define _RT_TIMER_FORMAT_	MICROSECONDS
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
%assign _RT_TIMER_RESOLUTION_    298
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
%define RT_THREAD_MAGIC		('thrm'+'agic')
%define RT_THREAD_POOL_MAGIC	('thpo'+'magi')
;------------------------------------------------------------------------------




%include "ring_queue.asm"
%include "thread.asm"
%include "interrupts.asm"
%include "ret_counts.asm"

%include "bochs.asm"


extern ring_queue.link_ordered
extern ring_queue.prepend
extern ring_queue.unlink
extern int.set_handler




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
;                                 m a c r o s


%define TIMER_START_PROC(x)	x + (_thread_t.start_timer + _thread_timer_t.procedure)
%define TIMER_START_TIME(x)	x + (_thread_t.start_timer + _thread_timer_t.execution_time)
%define TIMER_START_RING(x)	x + (_thread_t.start_timer + _thread_timer_t.ring)

%define TIMER_END_PROC(x)	x + (_thread_t.end_timer + _thread_timer_t.procedure)
%define TIMER_END_TIME(x)	x + (_thread_t.end_timer + _thread_timer_t.execution_time)
%define TIMER_END_RING(x)	x + (_thread_t.end_timer + _thread_timer_t.ring)

%define TIMER_R_EXEC(x)		x + (_thread_timer_t.ring - _thread_timer_t.execution_time)
%define TIMER_R_PROC(x)		x + (_thread_timer_t.ring - _thread_timer_t.procedure)


; uuu2ticks
;------------------------------------------------------------------------------
; Convert a 64bit microseconds value in its equivalent duration in PIT ticks.
;
; syntax: uuu2ticks
; modifies: eax, ebx, ecx, edx
;
; where:
;
;  -input-
;   ecx:eax		64bit system time
;
;  -output-
;   edx:eax		64bit scheduler internal time (ticks count)
;
; Note: yes, eax:ebx is not common, but its simplify the 64bit multiply
;------------------------------------------------------------------------------
%macro uuu2ticks 0.nolist
   shld ecx, eax, _PIT_ADJ_SHIFT_REQUIRED_
   mov ebx, _PIT_ADJ_MULT_
   shl eax, _PIT_ADJ_SHIFT_REQUIRED_
   mul ebx
   mov eax, ecx
   mov ecx, edx
   mul ebx
   add eax, ecx
   adc edx, byte 0
%endmacro
;------------------------------------------------------------------------------



; ticks2uuu
;------------------------------------------------------------------------------
; Convert a 64bit PIT ticks count to its equivalent duration in microseconds
;
; syntax: ticks2uuu
; modifies: eax, ebx, ecx, edx
;
; where:
;
;  -input-
;   ecx:eax		64bit system time
;
;  -output-
;   edx:eax		64bit scheduler internal time (ticks count)
;
; Note: yes, eax:ebx is not common, but its simplify the 64bit multiply
;------------------------------------------------------------------------------
%macro ticks2uuu 0.nolist
   shld ecx, eax, _PIT_ADJ_SHIFT_REQUIRED_
   mov ebx, _PIT_ADJ_DIV_
   shl eax, _PIT_ADJ_SHIFT_REQUIRED_
   mul ebx
   mov eax, ecx
   mov ecx, edx
   mul ebx
   add eax, ecx
   adc edx, byte 0
%endmacro
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
;------------------------------------------------------------------------------
timer_ring:		def_ring_queue
;------------------------------------------------------------------------------





; Thread Pools Ring
;------------------------------------------------------------------------------
thread_pools_ring:	def_ring_queue
;------------------------------------------------------------------------------



; Ticks per IRQ
;------------------------------------------------------------------------------
; Number of PIT ticks per IRQ currently programmed.  This value should be
; changed only using the thread.change_system_resolution procedure.
;
; Note: while the currently supported underlying hardware support only a 16bit
; value, this variable is made 32bit to allow for a different hardware timing
; mechanism to be used.
;------------------------------------------------------------------------------
ticks_per_irq:		dd 0
;------------------------------------------------------------------------------




; Ready For Execution [threads]
;------------------------------------------------------------------------------
ready_for_execution:	def_ring_queue
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


; Ticks Count
;------------------------------------------------------------------------------
; Number of PIT ticks since the scheduler was initialized.
;
; For each timer interrupt, this value is incremented by the value of
; the variable 'ticks_per_irq'.  See the 'PIT Adjustment Value' section
; above for more information.
;------------------------------------------------------------------------------
ticks_count:			resd 2
;------------------------------------------------------------------------------



; System Time Adjustment
;------------------------------------------------------------------------------
; Value controlling the difference between the system time, as per the
; system_time.get_uuutime, and the scheduler internal time.  This value 64bit
; value is specified in microseconds.
;------------------------------------------------------------------------------
system_time_adjustment:		resd 2
;------------------------------------------------------------------------------


; Tick Drift
;------------------------------------------------------------------------------
; Number of ticks behind/forward to correct the internal time by.  This allows
; for correction of hardware timer drifting.  The value set here will
; progressively be integrated with the scheduler internal time.
;
; 
;
; Note: if any major time modification (more than a few seconds) has to be
; done, it is recommended to change the 'system_time_adjustment' instead of
; correcting tick drift.
;------------------------------------------------------------------------------
tick_drift:			resd 2
;------------------------------------------------------------------------------



; Tick Drift Correction
;------------------------------------------------------------------------------
; Amount of ticks to adjust the 'ticks_count' per PIT IRQ.
;
; Allows to control how fast the tick drift will be integrated to the
; scheduler internal time.  See the system_time.correct_tick_drift procedure
; documentation for more information on how to set this value.
;
; Fixed-point, unsigned.  16.16
;------------------------------------------------------------------------------
tick_drift_correction:		resd 1
;------------------------------------------------------------------------------



; Cummulated Drift Correction
;------------------------------------------------------------------------------
; Decimal part of the summed tick drift corrections. See the documentation of
; system_time.correct_tick_drift for complete details.
;
; Fixed-point, unsigned:  16.16
;------------------------------------------------------------------------------
cummulated_drift_correction:	resd 1
;------------------------------------------------------------------------------




; Executing Thread
;-----------------------------------------------------------------------------
; Pointer to _thread_t of the currently executing thread
;-----------------------------------------------------------------------------
executing_thread:		resd 1
;-----------------------------------------------------------------------------




; Internal Stack
;-----------------------------------------------------------------------------
; Zone of memory reserved for the IRQ handler to use as stack while executing
; timer procedures.  This avoid stack overflow on executing threads.
;-----------------------------------------------------------------------------
__internal_stack__:		resb 1024
.top:
;-----------------------------------------------------------------------------



; New Ticks Per IRQ
;------------------------------------------------------------------------------
; Number of Ticks per IRQ to be reprogrammed by the __resolution_programmer
; timer.  See system_time.set_timer_resolution
;------------------------------------------------------------------------------
new_ticks_per_irq:		resd 1
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
;                s c h e d u l e r   i n i t i a l i s a t i o n
section .text

global __scheduler_init
__scheduler_init:
;------------------------------------------------[ scheduler initialisation ]--
						; Initialize Pre-Allocated
						; Thread Pools
						;------------------------------
  mov esi, _THREAD_POOLS_			; number of thread pools
  mov edi, pre_allocated_thread_pools		; memory location
						;
.initializing_thread_pools:			;
  mov eax, edi					; node to link
  mov ebx, thread_pools_ring			; ring to use
						;
%ifdef SANITY_CHECKS				;
 mov [eax + _ring_queue_t.next], eax		;- loopback unlinked node
 mov [eax + _ring_queue_t.previous], eax	;/
%endif						;
						;
  ecall thread.add_pool, CONT, CONT		; link it up
						;
  add edi, _rt_thread_pool_t_size		; move to next pool space
  dec esi					; # of pools pre-allocated
  jnz short .initializing_thread_pools		; jump if some more left
						;
						; Acquire 'Init' Thread
						;------------------------------
  ecall thread.acquire, CONT, CONT, CONT	;
  push eax					; save thread ID
						;
						; Initialize 'Init' Thread
						;------------------------------
  xor ebx, ebx					; set empty event handler
  ecall thread.initialize, CONT, CONT		;
						;
						; Mark thread as Ready/Running
						;------------------------------
  pop eax					; restore thread ID (pointer)
  mov [eax + _thread_t.execution_status], byte RT_SCHED_STATUS_RUNNING
  mov [executing_thread], eax			;
						;
						; Activate its stack
						;------------------------------
  pop ebx					; get our return address
  mov esp, [eax + _thread_t.top_of_stack]	; get new stack
  push ebx					; push back the return address
						;
						; Link to Ready To Execute Ring
						;------------------------------
  mov ebx, ready_for_execution			;
  lea eax,[TIMER_START_RING(eax)]		;
  ecall ring_queue.prepend, CONT, CONT		;
						;
						; Program the PIT
						;------------------------------
  mov eax, _RT_TIMER_RESOLUTION_		;
%ifidn _RT_TIMER_FORMAT_, TICKS			;
  ecall system_time.set_timer_resolution_ticks, CONT, CONT, CONT
%elifidn _RT_TIMER_FORMAT_, MICROSECONDS	;
  ecall system_timer.set_timer_resolution, CONT, CONT, CONT
%endif						;
						;
						; Connect the PIT IRQ handler
						;------------------------------
  mov eax, 0x20					;
  mov ebx, __pit_interrupt_handler		;
  ecall int.set_handler, CONT, CONT		;
						; Enable IRQ 0
						;------------------------------
  cli						;
  in  al, 0x21					; read current irq mask
  and al, 0xFE					; take out bit 0
  out 0x21, al					; write back new mask
  sti						;
						;
  retn						;
;------------------------------------------------[/scheduler initialisation ]--









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
;; Reprogram the PIT and sets the number of full timer expirations for a given
;; number of ticks
;;
;; parameters
;; ----------
;; edx = number of microseconds before allowing interruption
;;
;;
;; returns
;; -------
;; eax = destroyed
;; edx = destroyed
;; pit_ticks = number of full expiration to let go
;-----------------------------------------------------------------------------
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




__empty_event_handler:
  retn




__thread_expired:
__thread_ready:
__re_evaluate_execution_priority:
  mov eax, 0xDEADBEEF
  jmp short __re_evaluate_execution_priority




; Timer Reprogrammer
;------------------------------------------------------------------------------
__resolution_reprogram_timer:
  istruc _thread_timer_t
at _thread_timer_t.procedure,	dd __resolution_programmer
at _thread_timer_t.execution_time, dd 0, 0
at _thread_timer_t.ring, dd $, $
  iend
;
;
__resolution_programmer:
;---------------------------------------------------[ resolution programmer ]--
; This timer is set by the system_timer.set_timer_resolution procedure.  When
; executed it calls __set_timer to reprogram the number of ticks between fired
; IRQ.
;------------------------------------------------------------------------------
  mov edx, [new_ticks_per_irq]
  mov [ticks_per_irq], edx
  call __set_timer
  retn
;---------------------------------------------------[/resolution programmer ]--









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





gproc thread.add_pool
;---------------------------------------------------------[ thread add pool ]--
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to memory block big enough to hold a thread pool, see thread.get_pool_size"/>
;! <ret fatal="0" brief="success"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
  push eax					;
  ecall ring_queue.prepend, CONT, .unexpected	;
  pop eax					;
  mov [eax + _rt_thread_pool_t.bitmap], dword -1;
  mov [eax + _rt_thread_pool_t.magic], dword RT_THREAD_POOL_MAGIC
  return					;
						;
.unexpected:					;
  pop ecx					;
  ret_other					;
;---------------------------------------------------------[/thread add pool ]--




;-------------------------------------------------[ realtime thread acquire ]--
gproc thread.acquire
;!<proc>
;! <ret fatal="0" brief="allocation succesfull">
;!  <r reg="eax" brief="pointer to allocated thread"/>
;! </ret>
;! <ret fatal="1" brief="allocation failed - out of thread"/>
;! <ret brief="other"/>
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
  lea	edx, [ebx + ecx + (_rt_thread_pool_t.threads - _STACK_SIZE_ )]
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
						;
 lea	ebx, [TIMER_START_RING(eax)]		;
 lea	ecx, [TIMER_END_RING(eax)]		;
 mov	[ebx + _ring_queue_t.next], ebx		;
 mov	[ebx + _ring_queue_t.previous], ebx	;
 mov	[ecx + _ring_queue_t.next], ecx		;
 mov	[ecx + _ring_queue_t.previous], ecx	;
						;
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
gproc thread.release
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to thread to release"/>
;! <ret fatal="0" brief="deallocation succesfull"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
						; validate the thread pointer
%ifdef SANITY_CHECKS				;------------------------------
 cmp	[eax + _thread_t.magic], dword RT_THREAD_MAGIC
 jnz	short .failed_sanity_check_magic	;
%endif						;
						; verify that the thread is
						; not currently used
						;------------------------------
  cmp	[eax + _thread_t.execution_status], byte RT_SCHED_STATUS_UNSCHEDULED
  jnz	short .thread_is_in_use			;
						;
						; also verify it is unlinked
%ifdef SANITY_CHECKS				;------------------------------
 add eax, byte (_thread_t.start_timer + _thread_timer_t.ring)
 cmp eax, [eax]					;
 jnz short .failed_sanity_check_linked		;
 add eax, byte (_thread_t.end_timer - _thread_t.start_timer)
 cmp eax, [eax]					;
 jnz short .failed_sanity_check_linked		;
 sub eax, byte (_thread_t.end_timer + _thread_timer_t.ring)
%endif						;
						; reset thread flags to default
						;------------------------------
  mov [eax + _thread_t.flags], byte 0		;
						;
						; find thread pool parentship
						;------------------------------
  mov ebx, [eax + _thread_t.thread_pool]	;
						;
						; validate thread pool pointer
%ifdef SANITY_CHECKS				;------------------------------
 cmp [ebx + _rt_thread_pool_t.magic], dword RT_THREAD_POOL_MAGIC
 jnz short .failed_sanity_check_pool_magic	;
%endif						;
						; compute thread id
						;------------------------------
  lea ecx, [eax + _thread_t_size]		;
  sub ecx, ebx					;
%ifdef SANITY_CHECKS				;
 jb short .failed_sanity_check_pointer_inconsistency
%endif						;
  shr ecx, _LOG_STACK_SIZE_			;
%ifdef SANITY_CHECKS				;
 cmp ecx, byte 31				;
 ja short .failed_sanity_check_pointer_inconsistency
%endif						;
						; mark thread as available
						;------------------------------
  mov eax, 1					;
  shl eax, cl					;
%ifdef SANITY_CHECKS				;
 test [ebx + _rt_thread_pool_t.bitmap], dword eax	;
 jnz short .failed_sanity_check_bitmap		;
%endif						;
 or dword [ebx + _rt_thread_pool_t.bitmap], eax	;
 return						;
						;
						; error: thread under usage
.thread_is_in_use:				;------------------------------
  xor eax, eax					;
  xor ebx, ebx					;
  ret_other					; TODO: set error code
						;
						;
%ifdef SANITY_CHECKS				;
[section .data]					;
.sanity_magic:					;
  uuustring "thread.release: magic failed on provided thread", 0x0A
.sanity_linked:
  uuustring "thread.release: thread unusued but still linked - sanity failed", 0x0A
.sanity_pool_magic:
  uuustring "thread.release: thread pool magic failed", 0x0A
.sanity_pointer_inconsistency:
  uuustring "thread.release: thread vs pool pointer inconsistency - sanity failed", 0x0A
.sanity_bitmap:
  uuustring "thread.release: pool bitmap has thread marked as free already", 0x0A
__SECT__					;
.failed_sanity_check_magic:			;
 mov ebx, dword .sanity_magic			;
 jmp short .sanity_common			;
.failed_sanity_check_linked:			;
 mov ebx, dword .sanity_linked			;
 jmp short .sanity_common			;
.failed_sanity_check_pool_magic			;
 mov ebx, dword .sanity_pool_magic		;
 jmp short .sanity_common			;
.failed_sanity_check_pointer_inconsistency:	;
 mov ebx, dword .sanity_pointer_inconsistency	;
 jmp short .sanity_common			;
.failed_sanity_check_bitmap:			;
 mov ebx, dword .sanity_bitmap			;
.sanity_common:					;
 xor eax, eax					; TODO : set error code
 ret_other					;
%endif						;
;-------------------------------------------------[/realtime thread release ]--






gproc thread.initialize
;----------------------------------------------[ realtime thread initialize ]--
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to thread to initialize"/>
;! <p reg="ebx" type="pointer" brief="callback to use for event notification"/>
;! <p reg="ecx" type="pointer" brief="pointer to give as parameter to the thread"/>
;! <p reg="edx" type="pointer" brief="address at which to start thread execution"/>
;! <ret fatal="0" brief="initialization completed"/>
;! <ret brief="other"/>
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
  jnz short .thread_in_use			;
						; also verify it is unlinked
%ifdef SANITY_CHECKS				;------------------------------
 add eax, byte (_thread_t.start_timer + _thread_timer_t.ring)
 cmp eax, [eax]					;
 jnz short .sanity_check_failed_linked		;
 add eax, byte (_thread_t.end_timer - _thread_t.start_timer)
 cmp eax, [eax]					;
 jnz short .sanity_check_failed_linked		;
 sub eax, byte (_thread_t.end_timer + _thread_timer_t.ring)
%endif						;
						; set event notification hndlr
						;------------------------------
  test ebx, ebx					;
  jnz short .event_handler_provided		;
  mov ebx, __empty_event_handler		;
.event_handler_provided:			;
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







gproc thread.schedule
;------------------------------------------------[ realtime thread schedule ]--
;!<proc>
;! <p reg="eax" type="pointer" brief="pointer to thread to schedule"/>
;! <p reg="ebx" type="uinteger32" brief="inverse priority to set"/>
;! <p reg="ecx" type="pointer" brief="pointer to delay in microseconds until start time"/>
;! <p reg="edx" type="pointer" brief="pointer to delay microseconds until deadline"/>
;! <ret fatal="0" brief="success"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
						; validate thread pointer
%ifdef SANITY_CHECKS				;------------------------------
 cmp [eax + _thread_t.magic], dword RT_THREAD_MAGIC
 jnz near .sanity_check_failed_magic		;
%endif						;
						; make sure the thread is not
						; currently scheduled
						;------------------------------
  cmp [eax + _thread_t.execution_status], byte RT_SCHED_STATUS_UNSCHEDULED
  jnz near .thread_in_use			;
						;
						; verify that it is not linked
						; in one of the ring queues
%ifdef SANITY_CHECKS				;------------------------------
 add eax, byte (_thread_t.start_timer + _thread_timer_t.ring)
 cmp [eax + _ring_queue_t.next], eax		;
 jnz near .sanity_check_failed_linked		;
 add eax, byte (_thread_t.end_timer - _thread_t.start_timer)
 cmp [eax + _ring_queue_t.next], eax		;
 jnz near .sanity_check_failed_linked		;
 sub eax, byte (_thread_t.end_timer + _thread_timer_t.ring)
%endif						;
						; set requested priority
						;------------------------------
  mov [eax + _thread_t.execution_priority], ebx	;
						;
						;
						; compute expiration time
						;------------------------------
  push esi					;
  mov esi, eax					;-thread pointer
  push ecx					;-ptr to delay until start
  mov eax, [edx]				;
  mov ecx, [edx + 4]				;
  uuu2ticks					;
  add eax, dword [ticks_count]			;
  adc edx, dword [ticks_count + 4]		;
						; store expiration time
						;------------------------------
  mov [TIMER_END_TIME(esi)], eax		;
  mov [TIMER_END_TIME(esi) + 4], edx		;
						; register expiration timer
						;------------------------------
  lea eax, [TIMER_END_RING(esi)]		;
  mov [TIMER_END_PROC(esi)], dword __thread_expired
  mov ebx, timer_ring				;
  ecall ring_queue.link_ordered, CONT, .failed_link
						;
						; compute delay until start
						;------------------------------
  pop ecx					;-ptr to delay until start
  mov eax, [ecx]				;
  mov ecx, [ecx + 4]				;
  mov edx, eax					;
  or  edx, ecx					;
  jz  .ready_immediately			;
  uuu2ticks					;
  add eax, dword [ticks_count]			;
  adc edx, dword [ticks_count + 4]		;
						; store start time
						;------------------------------
  mov [TIMER_START_TIME(esi)], eax		;
  mov [TIMER_START_TIME(esi) + 4], edx		;
						; register ready timer
						;------------------------------
  lea eax, [TIMER_START_RING(esi)]		;
  mov [TIMER_START_PROC(esi)], dword __thread_ready
  mov ebx, timer_ring				;
  ecall ring_queue.link_ordered, .clean_and_exit, .failed_link_unreg_end_timer
						;
						; set thread in ready queue
.ready_immediately:				;------------------------------
  mov ebx, [esi + _thread_t.execution_priority]	;
  mov [TIMER_START_TIME(esi)], ebx		;
  mov [TIMER_START_TIME(esi) + 4], edx		;- edx = 0
  lea eax, [TIMER_START_RING(esi)]		;
  mov ebx, ready_for_execution			;
  ecall ring_queue.link_ordered, CONT, .failed_link_unreg_end_timer
  ;----------------------------------------------------------------------------
  ;
  ; Additional Information:
  ;------------------------
  ; The '_thread_t.start_timer' structure is re-used to ring into the
  ; ready_for_execution.  See the _thread_t structure for more details.
  ;----------------------------------------------------------------------------
						; re-evaluate exec priority
						;------------------------------
  call __re_evaluate_execution_priority		;
						;
						; clean and exit
.clean_and_exit					;------------------------------
  pop esi					; restore original esi
  return					;
						;
						; error: thread already in use
.thread_in_use:					;------------------------------
  xor ebx, ebx					;
  xor eax, eax					;
  ret_other					;
						; error: linking failed
						; no timer registered yet
.failed_link:					;------------------------------
  pop ecx					;
  pop esi					;
  ret_other					;
						; error: linking failed
						; must unregister end timer
.failed_link_unreg_end_timer:			;------------------------------
  push eax					;- save error code
  push ebx					;/
  lea eax, [TIMER_END_RING(esi)]		;
  ecall ring_queue.unlink, CONT, CONT		;
  pop ebx					;- restore error code
  pop eax					;/
  pop esi					; restore original esi
  ret_other					;
						;
%ifdef SANITY_CHECKS				;
[section .data]					;
.sanity_magic:					;
  uuustring "thread.schedule magic failed on thread", 0x0A
.sanity_linked:
  uuustring "thread.schedule - marked as unscheduled but linked - sanity failed", 0x0A
__SECT__					;
.sanity_check_failed_linked:			;
  mov ebx, .sanity_linked			;
  jmp short .sanity_common			;
.sanity_check_failed_magic:			;
  mov ebx, .sanity_magic			;
.sanity_common:					;
  xor eax, eax					;
  ret_other					;
%endif
;------------------------------------------------[/realtime thread schedule ]--






gproc system_time.get_uuutime
;-----------------------------------------------[ system time: get uuu time ]--
;!<proc>
;! <p reg="eax" type="pointer" brief="destination where to store the 64bit uuu-time"/>
;! <ret fatal="0" brief="time returned successfully"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
  push eax					;
						; read current ticks count
						;------------------------------
  mov eax, [ticks_count]			;
  mov ecx, [ticks_count+4]			;
						; convert ticks to microseconds
						;------------------------------
  ticks2uuu					;
						;
						; add system time adjustment
						;------------------------------
  add eax, [system_time_adjustment]		;
  adc edx, [system_time_adjustment + 4]		;
						;
						; place result in given pointer
						;------------------------------
  pop ecx					;
  mov [ecx], eax				;
  mov [ecx + 4], edx				;
  return					;
;-----------------------------------------------[/system time: get uuu time ]--






gproc system_time.correct_tick_drift
;-----------------------------------------[ system time: correct tick drift ]--
;!<proc>
;! <p reg="eax" type="pointer" brief="64bit signed tick drift correctional value"/>
;! <ret fatal="0" brief="tick drift correction recorded"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
						; read 64bit drift correction
						;------------------------------
  mov ebx, [eax]				; low...
  mov ecx, [eax + 4]				; high... done
						;
						; write it to internal variable
						;------------------------------
  mov [tick_drift], ebx				; low...
  mov [tick_drift + 4], ecx			; high... done
  return					;
;-----------------------------------------[/system time: correct tick drift ]--






gproc system_time.set_tick_drift_correction_rate
;-----------------------------[ system time: set tick drift correction rate ]--
;!<proc>
;! <p reg="eax" type="uinteger32">
;!  <para>
;!  Unsigned fixed point 16.16 integer indicating the amount of ticks to adjust the
;!  ticks count per PIT IRQ.
;!  </para><para>
;!  For example a value of 0x00010000 would correct 1 tick per PIT IRQ
;!  </para>
;! </p>
;! <ret fatal="0" brief="drift correction rate adjusted"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
  mov [tick_drift_correction], eax
  return
;-----------------------------[/system time: set tick drift correction rate ]--






gproc system_time.set_timer_resolution
;---------------------------------------[ system time: set timer resolution ]--
;!<proc>
;! <p reg="eax" type="uinteger32" brief="microseconds between PIT interrupts"/>
;! <ret fatal="0" brief="success"/>
;! <ret fatal="1" brief="resolution not supported by current hardware"/>
;! <ret brief="other"/>
;!</proc>
;------------------------------------------------------------------------------
						; convert microseconds to ticks
						;------------------------------
  mov edx, _PIT_ADJ_MULT_			;
  mul edx					;
						;
  ecall system_time.set_timer_resolution_ticks, CONT, .unsupported_range, .unexpected
  return					;
						;
.unsupported_range:				;
  return 1					;
						;
.unexpected:					;
  ret_other					;
;---------------------------------------[/system time: set timer resolution ]--





gproc system_time.set_timer_resolution_ticks
;-------------------------------[ system time: set timer resolution in ticks ]--
;!<proc>
;! <p reg="eax" type="uinteger32" brief="number of ticks between PIT interrupts"/>
;! <ret fatal="0" brief="success"/>
;! <ret fatal="1" brief="resolution not supported by current hardware"/>
;! <ret brief="other"/>
;!</proc>
;-------------------------------------------------------------------------------
						; validate range 1 < x < 65536
						;------------------------------
  cmp eax, 2					;
  jb short .unsupported_range			;
  cmp eax, 65535				;
  ja short .unsupported_range			;
						;
						; set new range to reprogram
						;------------------------------
  mov [new_ticks_per_irq], eax			;
						;
						; set reprogrammation procedure
						;------------------------------
  mov ecx, [ticks_count]			;
  mov edx, [ticks_count]			;
  mov eax, __resolution_reprogram_timer		;
  mov ebx, timer_ring				;
  mov [TIMER_R_EXEC(eax)], ecx			;
  mov [TIMER_R_EXEC(eax)], edx			;
  add eax, byte _thread_timer_t.ring		;
  ecall ring_queue.prepend, CONT, .unexpected	;
						;
  return					;
						;
.unsupported_range:				;
  return 1					;
						;
.unexpected:					;
  ret_other					;
;-------------------------------[/system time: set timer resolution in ticks ]--





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
;                         P I T   i n t e r r u p t
section .text




__pit_interrupt_handler:
;-----------------------------------------------------------[ PIT INTERRUPT ]--
; Receive control directly from the CPU on reception of IRQ 0
;
; stack contains EIP, EFLAGS
; interrupts are disabled
;------------------------------------------------------------------------------
						; save current thread registers
						;------------------------------
  pushad					;
						;
						; send Specific-EOI to PIC
						;------------------------------
  mov al, 0x60					;
  out 0x20, al					;
						;
						; get pointer to current thread
						;------------------------------
  mov ebp, [executing_thread]			;
						;
						; validate acquired pointer
%ifdef SANITY_CHECKS				;------------------------------
 cmp [ebp + _thread_t.magic], dword RT_THREAD_MAGIC
 jnz near .sanity_check_failed_magic		;
%endif						;
						; make sure it is within bound
%ifdef SANITY_CHECKS				;------------------------------
 cmp esp, ebp					; upper bound... thread ID
 ja near .sanity_check_failed_bound		;
 cmp esp, [ebp + _thread_t.bottom_of_stack]	; lower bound...
 jb near .sanity_check_failed_bound		;
%endif						;
						; backup current top of stack
						;------------------------------
  mov [ebp + _thread_t.top_of_stack], esp	;
						;
						; compute new ticks count
						;------------------------------
  mov esi, [ticks_count]			;- read current ticks count
  mov edi, [ticks_count + 4]			;/
						;
  mov ebx, [tick_drift]				;- verify drift tick drifting
  mov ecx, [tick_drift + 4]			;/
  mov eax, ebx					;
  or eax, ecx					;
  jnz short .correct_drift			;
						;
.drift_corrected:				;
  add esi, [ticks_per_irq]			;- add # of ticks per irq
  adc edi, byte 0				;/
						;
  mov [ticks_count], esi			;- store new ticks count
  mov [ticks_count + 4], edi			;/
						;
						; check for expiring timers
						;------------------------------
  mov ebx, timer_ring				; load ring head/tail pointer
.cycle_timer_ring:				;
  mov eax, [ebx + _ring_queue_t.next]		; load next node of ring
  cmp eax, ebx					; verify for complete cycle
  jz short .timer_cycled			;
						;
%ifdef SANITY_CHECKS				; validate next node pointer
 cmp [eax + _ring_queue_t.previous], ebx	;
 jnz short .sanity_check_failed_timer		;
%endif						;
						;

  lea ebp, [eax - _thread_timer_t.ring]		;
  cmp [ebp + _thread_timer_t.execution_time + 4], edi
;  cmp [TIMER_R_EXEC(eax) + 4 - _thread_timer_t.ring], edi		; check set execution time
  ja short .timer_cycled			;
  jb short .execute_timer			;
  cmp [ebp + _thread_timer_t.execution_time], esi
;  cmp [TIMER_R_EXEC(eax) - _thread_timer_t.ring], esi			;
  ja short .timer_cycled			;
						;
						; execute timer
.execute_timer:					;------------------------------
  ecall ring_queue.unlink, CONT, .sanity_check_failed_timer
  mov eax, ebp					;
  mov esp, __internal_stack__.top		; set internal stack
  call [ebp + _thread_timer_t.procedure]	; execute timer procedure
  jmp short .cycle_timer_ring			; check for other timers
						;
						;
.timer_cycled:					; load first ready thread
						;------------------------------
  mov eax, [ready_for_execution + _ring_queue_t.next]
  sub eax, _thread_t.start_timer + _thread_timer_t.ring
						;
						; validate thread pointer
%ifdef SANITY_CHECKS				;------------------------------
 cmp [eax + _thread_t.magic], dword RT_THREAD_MAGIC
 jnz short .sanity_check_failed_magic		;
%endif						;
						; update executing thread ptr
						;------------------------------
  mov [executing_thread], eax			;
						;
						; activate thread
						;------------------------------
  mov esp, [eax + _thread_t.top_of_stack]	; stack...
  popad						; registers...
  iretd						; eflags/eip...done
						;
%ifdef SANITY_CHECKS				;
%macro SANITYLOCK 1.nolist			;
%%label:	mov eax, %{1}			;
		jmp short %%label		;
%endmacro					;
						;
.sanity_check_failed_magic: SANITYLOCK 1	;
.sanity_check_failed_timer: SANITYLOCK 2	;
.sanity_check_failed_bound: SANITYLOCK 3	;
%endif						;
						;
.correct_drift:					; correct timer drift
						;------------------------------
  						; edi:esi - current ticks count
						; ecx:ebx - tick drift
  mov eax, [cummulated_drift_correction]	;
  add eax, [tick_drift_correction]		;
  mov edx, eax					;
  and eax, 0x0000FFFF				;
  shr edx, 16					;
  mov [cummulated_drift_correction], eax	;
  jz near .drift_corrected			;
						;
  test ecx, ecx					;
  jns short .positive_correction		;
  neg edx					;
  cmp ecx, byte -1				;
  jnz short .execute_correction			;
  cmp edx, ebx					;
  jg  short .execute_correction			;
  jmp short .execute_correction_with_overflow	;
.positive_correction:				;
  jnz short .execute_correction			;
  cmp edx, ebx					;
  jl  short .execute_correction			;
.execute_correction_with_overflow:		;
  mov edx, ebx					;
.execute_correction:				;
  sub ebx, edx					;
  sbb ecx, byte 0				;
  add esi, edx					;
  adc edi, byte 0				;
  mov [tick_drift], ebx				;
  mov [tick_drift + 4], ecx			;
  jmp near .drift_corrected			;
;-----------------------------------------------------------[/PIT INTERRUPT ]--


%ifndef __INTERRUPT_INCLUDE__
%define __INTERRUPT_INCLUDE__

%include "ring_queue.asm"

%define __IRQ_CLIENT_MAGIC__	'irqmagic'

struc _irq_client_t
.ring		resb _ring_queue_t_size
.procedure	resd 1
.magic		resd 1
endstruc

%define def_irq_client_queue def_ring_queue


%macro irq_client 1.nolist
  def_ring_queue
  dd %1
  dd __IRQ_CLIENT_MAGIC__
%1:
%endmacro



%endif ;__INTERRUPT_INCLUDE__

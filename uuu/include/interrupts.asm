%ifndef __INTERRUPT_INCLUDE__
%define __INTERRUPT_INCLUDE__

%include "ring_queue.asm"

%define __IRQ_CLIENT_MAGIC__	('irqm'+'agic')

struc _irq_client_t
.ring		resb _ring_queue_t_size
.procedure	resd 1
.magic		resd 1
endstruc



%macro irq_client 1.nolist
%1:
  def_ring_queue
  dd %%procedure
  dd __IRQ_CLIENT_MAGIC__
%%procedure:
%endmacro



%endif ;__INTERRUPT_INCLUDE__

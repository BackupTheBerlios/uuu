
%macro BOCHS_enable_iodebug 0.nolist
  pushad
  mov eax, 0x8A00
  mov edx, eax
  out dx, ax
  popad
%endmacro

%macro BOCHS_prompt 0.nolist
  pushad
  mov eax, 0x8AE0
  mov edx, 0x8A00
  out dx, ax
  popad
%endmacro

%macro BOCHS_instruction_trace_enable 0.nolist
  pushad
  mov eax, 0x8AE3
  mov edx, 0x8A00
  out dx, ax
  popad
%endmacro

%macro BOCHS_instruction_trace_disable 0.nolist
  pushad
  mov eax, 0x8AE2
  mov edx, 0x8A00
  out dx, ax
  popad
%endmacro

%macro BOCHS_register_trace_enable 0.nolist
  pushad
  mov eax, 0x8AE5
  mov edx, 0x8A00
  out dx, ax
  popad
%endmacro

%macro BOCHS_register_trace_disable 0.nolist
  pushad
  mov eax, 0x8AE4
  mov edx, 0x8A00
  out dx, ax
  popad
%endmacro

%macro BOCHS_trace_enable 0.nolist
  pushad
  mov eax, 0x8AE5
  mov edx, 0x8A00
  out dx, ax
  mov al, 0xE3
  out dx, ax
  popad
%endmacro

%macro BOCHS_trace_disable 0.nolist
  pushad
  mov eax, 0x8AE2
  mov edx, 0x8A00
  out dx, ax
  mov al, 0xE4
  out dx, ax
  popad
%endmacro

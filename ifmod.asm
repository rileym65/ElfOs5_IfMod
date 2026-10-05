; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

#include   macros.inc
#include   bios.inc
#include   kernel.inc

           org     2000h

begin:     br      start
           eever
           db      'Written by Michael H. Riley',0

start:     mov     rf,0400h            ; get Elf/OS version
           ldn     rf
           smi     5                   ; must be 5+
           lbdf    isv5                ; jump if Elf/OS 5
           call    o_inmsg             ; display error
           db      'Requires Elf/OS 5+',10,13,0
           ldi     014h                ; set return code to invalid version
           rtn                         ; return to caller
isv5:      mov     r9,k_helpers        ; point to os helpers
           lda     ra                  ; move past any spaces
           smi     ' '
           lbz     isv5
           dec     ra                  ; move back to non-space character
           ldn     ra                  ; get byte
           lbnz    hasarg              ; jump if have at least 1 arg
argerror:  call    o_inmsg             ; display error
           db      'Usage: ifmod filename command',10,13,0
           ldi     0ah                 ; set return vaue
           sep     sret                ; and return to os
hasarg:    mov     rf,filename         ; point to filename
fn_loop:   lda     ra                  ; read byte from command line
           lbz     argerror            ; error if end of command line
           plo     re                  ; save a copy
           smi     ' '                 ; check for a space
           lbz     fn_done             ; jump if done with filename
           glo     re                  ; otherwise recover character
           str     rf                  ; write to filename buffer
           inc     rf
           lbr     fn_loop             ; loop until end of filename
fn_done:   ldi     0                   ; terminate filename
           str     rf
trim_2:    lda     ra                  ; move past any spaces
           lbz     argerror            ; error if no command given
           smi     ' '                 ; check for space
           lbz     trim_2              ; loop until no more spaces
           dec     ra                  ; move back to nonspace
           mov     rf,command          ; point to command buffer
cmd_copy:  lda     ra                  ; copy command
           str     rf
           inc     rf
           lbnz    cmd_copy            ; loop until terminator copied
           mov     rf,filename         ; point to filename
           call    o_dirent            ; find dirent for file
           lbnf    found               ; jump if file was found
           call    o_inmsg             ; display error
           db      'File not found',10,13,0
           ldi     4                   ; set return code
           rtn                         ; and return to caller
found:     glo     ra                  ; point to flags
           adi     6
           plo     rf
           ghi     ra
           adci    0
           phi     rf
           ldn     rf                  ; retrieve flags
           ani     16                  ; has file been modified
           lbnz    modified            ; jump if so
           ldi     0                   ; nothing to do, set return code
           rtn                         ; and return
modified:  ldn     rf                  ; recover flags
           ani     0efh                ; clear modified flag
           str     rf                  ; and put it back
           call    d_savesys           ; save entry back to disk
           mov     rc,150              ; need 150 bytes
           ldi     0ffh                ; need it page aligned
           phi     r7
           ldi     2                   ; mark block as permanent
           plo     r7
           call    o_alloc             ; allocate heap memory
           lbnf    allocated           ; jump if it was allocated
           call    o_inmsg             ; print error
           db      'Could not allocate heap memory',10,13,0
           ldi     5                   ; set return code
           rtn                         ; and return to caller
;allocated: push    rf                  ; save this address for later
allocated: op2     k_save,rf_
           mov     r7,run              ; point to run code
           mov     r8,rf               ; point to heap memory
           mov     rc,149              ; copy 149 bytes
cploop:    lda     r7                  ; read from program code
           str     r8                  ; place onto heap
           inc     r8
           dec     rc                  ; decrement count
           glo     rc                  ; see if done
           lbnz    cploop              ; loop until copy complete
           mov     r7,jump             ; need to setup jump address
           ghi     rf                  ; which is beginning of heap block
           str     r7
           inc     r7
           glo     rf
           str     r7
           ldi     command.0           ; point to command
           plo     rf
           db      0c0h                ; jump to run code
jump:      dw      0
       
           rtn



filename:  ds      128

.align page

run:       call    o_execbin           ; execute command
;           pop     rf                  ; recover heap address
           op2     k_restore,rf_
           call    o_dealloc           ; and deallocate it
           mov     rf,k_retval         ; get return value
           ldn     rf
           rtn                         ; then return to caller
command:   ds      127
           db      0

           end     begin


global so_emul

section .text

; SO emulator.
;
; two arguments: 
; - rdi: code pointer to uint16_t (64-bit)
; - rsi: data pointer to uint8_t (64-bit)
; - rcx: core (32-bit)
; - rdx: count (32-bit)
;
; return result:
; - rax: so_state 
;
; modified registers:
; 

so_emul:
        enter 0, 0

        mov     r13, 0                  ; counter of loops    
        mov     [rel core], rcx

        mov     r12, rsi
        mov     rcx, rdx
        mov     r11, rdi

.loop:

        loop .loop

        leave
        ret


; Writes value arg2 into arg1 (the same as mov in nasm). Doesn't modify flags C and Z.
;
; two arguments: 
; - rdi: arg1 address
; - rsi: arg2 address
;
; return result:
; - arg1's value = arg2's value
;
; modified registers:
; - rsi
MOV:    
        mov     rsi, [rsi]
        mov     [rdi], rsi  

        ret



; Writes value imm8 into arg1. Doesn't modify flags C and Z.
;
; two arguments: 
; - rdi: arg1 address
; - rsi: imm8
;
; return result:
; - arg1's value = imm8
;
; modified registers:
; - 
MOVI:    
        mov     [rdi], rsi  

        ret


; Get function group id from instruction code
;
; two arguments: 
;
; return result:
; - rax: so_state 
;
; modified registers:
; - r8w
get_group:
        mov     r8w, [r11]
        shr     r8w, 14

        ret

get_last_8_bits:
        mov     r8w, [r11]
        and     r8w, 0x00FF

        ret

; Get first 3 bits from operation code
; arguments: 
; - [r11]: operation code
;
; return result:
; - r9w: first 3 bits value
;
; modified registers:
; - r9w
get_first_3_bits:
        mov     r9w, [r11]
        and     r9w, 0x3800
        shr     r9w, 11

        ret

;  Get second 3 bits from operation code
; arguments: 
; - [r11]: operation code
;
; return result:
; - r10w: first 3 bits value
;
; modified registers:
; - r10w
get_second_3_bits:
        mov     r10w, [r11]
        and     r10w, 0x0700
        shr     r10w, 8

        ret

; Get register address from register type code
; arguments: 
; - si: register type code
;
; return result:
; - rax: register adress / id of values [X], [Y], [Y + D] or [X + D] in data
;
; modified registers:
; - r8, r9, r10, si, rax
get_register:
        lea     r9, [rel A] 

        cmp     si, 3
        jg      .x_value

        xor     r10, r10
        mov     r10w, si
        .debug: 
        lea     rax, [r9 + r10]         ; if code <= 3 then it is one of the 4 registers so the register adress = rel A + code
        jmp     .end
.x_value:
        cmp     si, 4
        jne      .y_value

        mov     rax, [r9 + 2]
        lea     rax, [r12 + rax]
        jmp     .end
.y_value:
        cmp     si, 5
        jne      .xd_value

        mov     rax, [r9 + 3]
        lea     rax, [r12 + rax]
        jmp     .end
.xd_value:        
        cmp     si, 6
        jne      .yd_value

        mov     r10, [r9 + 2]
        mov     r8, [r9 + 1]
        mov     rax, [r10 + r8]
        lea     rax, [r12 + rax]
        jmp     .end
.yd_value:        
        mov     r10, [r9 + 3]
        mov     r8, [r9 + 1]
        mov     rax, [r10 + r8]
        lea     rax, [r12 + rax]
.end:
        ret

section .bss
core: resq 1
registers: resq CORES

; A: resb 1 
; D: resb 1 
; X: resb 1 
; Y: resb 1 
; PC: resb 1 
; unused: resb 1
; C: resb 1 
; Z: resb 1 
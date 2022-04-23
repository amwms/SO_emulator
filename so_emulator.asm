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
        push    r12 
        push    r13 

        ; mov     r13, 0                  ; counter of loops    
        xchg    rdx, rcx 
        mov     r12, rsi
        mov     r11, rdi

        lea     r8, [rel registers] 
        lea     rdx, [r8 + rdx * 8]       ; address of the first SO register

        movzx   r13, BYTE [rdx + 4]           ; counter of loops

        cmp     rcx, 0
        je      .save_result

.loop:
        call    get_group                ; group id in register r8w
        call    handle_instruction

        inc     r13b
        loop    .loop
        
.save_result:      
        mov     [rdx + 4], r13
        mov     rax, [rdx]


        pop     r13 
        pop     r12
        leave
        ret

; ================= HANDLE INSTRUCTION =========================
handle_instruction:
        cmp     r8w, 0
        jne     .group_one
;------------- group zero -------------
        ; mov     di, [r11]
        
        ; call    get_group0_args
        ; call    get_function_id         ; function id is in register r8w

        call    get_first_3_bits          ; r9w - second arg
        call    get_second_3_bits         ; r10w - first arg
        call    get_last_8_bits           ; r8w - instruction id

        movzx   rdi, r9w                  ; init instruction args
        movzx   rsi, r10w

        call    get_register

        mov     rsi, rax
        xchg    rsi, rdi

        call    get_register
        mov     rsi, rax                  ; ======================

.debug3:
        cmp     r8w, 0x0000
        jne     .fun_OR
        call    MOV
        jmp     .end
.fun_OR:

;------------- group one ------------- 
.group_one:
        cmp     r8w, 1
        jne     .group_two

        ; call    get_first_3_bits          ; r9w - instruction id
        call    get_second_3_bits         ; r10w
        call    get_last_8_bits           ; r8w

        movzx   rsi, r10w                 ; get arg1 address
        call    get_register
        
        mov     rdi, rax                  ; init instruction args
        movzx   rsi, r8w

        call    get_first_3_bits          ; r9w - instruction id
.debugo:
        cmp     r9w, 0x0000
        jne     .fun_XORI
        call    MOVI
        jmp     .end
.fun_XORI:

.group_two:

.group_three:
.end:
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
        mov     sil, [rsi]
        mov     [rdi], sil  

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
        mov     [rdi], sil  
.debug:
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
        mov     r8w, [r11 + r13 * 2]
        shr     r8w, 14

        ret

get_last_8_bits:
        mov     r8w, [r11 + r13 * 2]
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
        mov     r9w, [r11 + r13 * 2]
        .debug:
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
        mov     r10w, [r11 + r13 * 2]
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
; - r10, r9, si, rax
get_register:
        ; lea     r9, [rel A] 

        cmp     si, 3
        jg      .x_value

        xor     r9, r9
        mov     r9w, si
        .debug: 
        lea     rax, [rdx + r9]         ; if code <= 3 then it is one of the 4 registers so the register adress = rel A + code
        jmp     .end
.x_value:
        cmp     si, 4
        jne      .y_value

        movzx     rax, BYTE [rdx + 2]
        lea     rax, [r12 + rax]
        jmp     .end
.y_value:
        cmp     si, 5
        jne      .xd_value

        movzx     rax, BYTE [rdx + 3]
        lea     rax, [r12 + rax]
        jmp     .end
.xd_value:        
        cmp     si, 6
        jne      .yd_value

        movzx     r10, BYTE [rdx + 2]
        movzx     r9, BYTE [rdx + 1] ; TODO mod 256
        ; mov     rax, [r10 + r9]
        lea     rax, [r9 + r10]
        lea     rax, [r12 + rax]
        jmp     .end
.yd_value:        
        movzx     r10, BYTE [rdx + 3]
        movzx     r9, BYTE [rdx + 1]
        ; mov     rax, [r10 + r9]
        lea     rax, [r9 + r10] 
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
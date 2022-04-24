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
        push    r14

        ; mov     r13, 0                  ; counter of loops    
        xchg    rdx, rcx 
        mov     r12, rsi
        mov     r11, rdi

        lea     r8, [rel registers] 
        lea     rdx, [r8 + rdx * 8]       ; address of the first SO register

        movzx   r13, BYTE [rdx + 4]       ; counter of loops
        mov     r14, 0                    ; flag if to break program

        cmp     rcx, 0
        je      .save_result

.loop:  
        call    get_group                 ; group id in register r8w
        call    handle_instruction

        inc     r13b
        cmp     r14, 1
        je      .save_result

        loop    .loop
        
.save_result:      
        mov     [rdx + 4], r13b
        mov     rax, [rdx]

        pop     r14
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
        cmp     r8w, 0x0002
        jne     .fun_ADD
        call    OR 
        jmp     .end
.fun_ADD:
        cmp     r8w, 0x0004
        jne     .fun_SUB
        call    ADD
        jmp     .end
.fun_SUB:
        cmp     r8w, 0x0005
        jne     .fun_ADC
        call    SUB
        jmp     .end
.fun_ADC:
        cmp     r8w, 0x0006
        jne     .fun_SBB
        call    ADC
        jmp     .end
.fun_SBB:
        cmp     r8w, 0x0007
        jne     .fun_XCHG
        call    SBB
        jmp     .end
.fun_XCHG:
        cmp     r8w, 0x0008
        jne     .end
        call    XCHG
        jmp     .end        

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
        cmp     r9w, 0x0003
        jne     .fun_ADDI
        call    XORI
        jmp     .end
.fun_ADDI:
        cmp     r9w, 0x0004
        jne     .fun_CMPI
        call    ADDI
        jmp     .end
.fun_CMPI:
        cmp     r9w, 0x0005
        jne     .fun_RCR
        call    CMPI
        jmp     .end
.fun_RCR:
        cmp     r9w, 0x0006
        jne     .end
        call    RCR
        jmp     .end

.group_two:
        cmp     r8w, 2
        jne     .group_three

        call    get_second_3_bits         ; r10w

        cmp     r10w, 0x0000
        jne     .fun_STC
        call    CLC
        jmp     .end
.fun_STC:
        cmp     r9w, 0x0001
        jne     .end
        call    STC
        jmp     .end

.group_three:
        cmp     r8w, 3
        jne     .group_three

        call    get_second_3_bits         ; r10w
        call    get_last_8_bits           ; r8w

        movzx   rdi, r8w

        cmp     r10w, 0x0000              ; instruction JMP
        jne     .fun_JNC
        call    JMP
        jmp     .end
.fun_JNC:
        cmp     r10w, 0x0002
        jne     .fun_JC
        call    JNC
        jmp     .end
.fun_JC:
        cmp     r10w, 0x0003
        jne     .fun_JNZ
        call    JC
        jmp     .end
.fun_JNZ:
        cmp     r10w, 0x0004
        jne     .fun_JZ
        call    JNZ
        jmp     .end
.fun_JZ:
        cmp     r10w, 0x0005
        jne     .end
        call    JNZ
        jmp     .end
.fun_BRK:
        cmp     WORD [r11 + r13 * 2], -1
        jne     .end
        call    BRK
        jmp     .end
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
; - sil
MOV:    
        mov     sil, [rsi]
        mov     [rdi], sil  

        ret

; Adds value arg2 to arg1 (the same as add in nasm). Doesn't modify flags C, but modifies Z.
; two arguments: 
; - rdi: arg1 address
; - rsi: arg2 address
;
; return result:
; - arg1's value += arg2's value
;
; modified registers:
; - sil
ADD: 
        mov     sil, [rsi]
        add     [rdi], sil
        call    update_flag_z

        ret

; Writes OR value of arg2, arg1 into arg1 (the same as or in nasm). Doesn't modify flags C, but modifies Z.
; two arguments: 
; - rdi: arg1 address
; - rsi: arg2 address
;
; return result:
; - arg1's value = OR (arg2, arg1)
;
; modified registers:
; - sil
OR: 
        mov     sil, [rsi]
        or      [rdi], sil
        call    update_flag_z

        ret

; Subtracts value arg2 to arg1 (the same as sub in nasm). Doesn't modify flags C, but modifies Z.
; two arguments: 
; - rdi: arg1 address
; - rsi: arg2 address
;
; return result:
; - arg1's value -= arg2's value
;
; modified registers:
; - sil
SUB: 
        mov     sil, [rsi]
        sub     [rdi], sil
        call    update_flag_z

        ret

; Adds value arg2 and C to arg1 (the same as adc in nasm). Modifies flags C and Z.
; two arguments: 
; - rdi: arg1 address
; - rsi: arg2 address
;
; return result:
; - arg1's value += arg2's value + C
;
; modified registers:
; - sil
ADC: 
        call set_my_flag_c

        mov     sil, [rsi]
        adc     [rdi], sil

        call    update_flag_c
        call    update_flag_z

        ret

; Subtracts value arg2 and C to arg1 (the same as sbb in nasm). Modifies flags C and Z.
; two arguments: 
; - rdi: arg1 address
; - rsi: arg2 address
;
; return result:
; - arg1's value -= (arg2's value + C)
;
; modified registers:
; - sil
SBB: 
        call set_my_flag_c

        mov     sil, [rsi]
        sbb     [rdi], sil

        call    update_flag_c
        call    update_flag_z
        
        ret

; Exchanges arg2 and arg1 (the same as xchg in nasm). Doesn't modify flags C and Z.
; two arguments: 
; - rdi: arg1 address
; - rsi: arg2 address
;
; return result:
; - arg1 <= arg2
; - arg2 <= arg1
;
; modified registers:
; - al
XCHG: 
        mov     al, [rsi]
        xchg    [rdi], al
        mov     [rsi], al 
        
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

; Xors value imm8 into arg1. Doesn't modify flags C, but modifies Z.
;
; two arguments: 
; - rdi: arg1 address
; - rsi: imm8
;
; return result:
; - arg1's value = arg1 XOR imm8
;
; modified registers:
; - sil
XORI:    
        xor     [rdi], sil
        call    update_flag_z

        ret

; Adds value imm8 into arg1. Doesn't modify flags C, but modifies Z.
;
; two arguments: 
; - rdi: arg1 address
; - rsi: imm8
;
; return result:
; - arg1's value += imm8
;
; modified registers:
; - sil
ADDI:    
        add     [rdi], sil
        call    update_flag_z

        ret

; Compares value imm8 to arg1. Modifies flags C and Z.
;
; two arguments: 
; - rdi: arg1 address
; - rsi: imm8
;
; return result:
; - set flags Z and C according to the comparison
;
; modified registers:
; - sil
CMPI:    
        cmp     [rdi], sil
        call    update_flag_z
        call    update_flag_c

        ret

; Rotates arg1 by one bit according to flag C. Doesn't modify flags Z, but modifies C.
;
; arguments: 
; - rdi: arg1 address
;
; return result:
; - set flags Z and C according to the comparison and rotates arg1
;
; modified registers:
; 
RCR:    
        call    set_my_flag_c
        rcr     BYTE [rdi], 1
        call    update_flag_c

        ret

; Zeros flag C. Doesn't modify flags Z.
;
; return result:
; - flag C is set to zero
CLC:    
        mov     BYTE [rdx + 6], 0
        ret

; Sets flag C to one. Doesn't modify flags Z.
;
; return result:
; - flag C is set to one
STC:    
        mov     BYTE [rdx + 6], 1
        ret

; Works like jmp in nasm (jumps imm8 instructions). Doesn't modify flags Z and C.
;
; arguments: 
; - rdi: imm8
;
; return result:
; - jumps imm8 instructions
JMP:    
        add     r13b, dil
        ret

; Works like jnc in nasm (jumps imm8 instructions if flag C not is set). Doesn't modify flags Z and C.
;
; arguments: 
; - rdi: imm8
;
; return result:
; - jumps imm8 instructions if flag C is set
JNC:    
        cmp     BYTE [rdx + 6], 0
        jne      .end
        
        add     r13b, dil
.end:
        ret

; Works like jnc in nasm (jumps imm8 instructions if flag C is set). Doesn't modify flags Z and C.
;
; arguments: 
; - rdi: imm8
;
; return result:
; - jumps imm8 instructions if flag C is set
JC:    
        cmp     BYTE [rdx + 6], 1
        jne      .end
        
        add     r13b, dil
.end:
        ret


; Works like jnz in nasm (jumps imm8 instructions if flag Z is not set to 1). Doesn't modify flags Z and C.
;
; arguments: 
; - rdi: imm8
;
; return result:
; - jumps imm8 instructions
JNZ:    
        cmp     BYTE [rdx + 7], 0
        jne      .end
        
        add     r13b, dil
.end:
        ret

; Works like jnz in nasm (jumps imm8 instructions if flag Z is set to 1). Doesn't modify flags Z and C.
;
; arguments: 
; - rdi: imm8
;
; return result:
; - jumps imm8 instructions
JZ:    
        cmp     BYTE [rdx + 7], 1
        jne      .end
        
        add     r13b, dil
.end:
        ret

; Breaks the code. Doesn't modify flags Z and C.
;
; return result:
; - sets flag "to break code" to 1
BRK:    
        mov     r14, 1
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
        jne     .y_value

        movzx   rax, BYTE [rdx + 2]
        lea     rax, [r12 + rax]
        jmp     .end
.y_value:
        cmp     si, 5
        jne      .xd_value

        movzx   rax, BYTE [rdx + 3]
        lea     rax, [r12 + rax]
        jmp     .end
.xd_value:        
        cmp     si, 6
        jne     .yd_value

        movzx   r10, BYTE [rdx + 2]
        movzx   r9, BYTE [rdx + 1] ; TODO mod 256
        ; mov     rax, [r10 + r9]
        lea     rax, [r9 + r10]
        lea     rax, [r12 + rax]
        jmp     .end
.yd_value:        
        movzx   r10, BYTE [rdx + 3]
        movzx   r9, BYTE [rdx + 1]
        ; mov     rax, [r10 + r9]
        lea     rax, [r9 + r10] 
        lea     rax, [r12 + rax]
.end:
        ret

; UPDATE FLAGS
update_flag_z:
        jnz     .not_zero
        mov     BYTE [rdx + 7], 1
        jmp     .end
.not_zero:        
        mov     BYTE [rdx + 7], 0
.end:
        ret

update_flag_c:
        jnc     .not_carry
        mov     BYTE [rdx + 6], 1
        jmp     .end
.not_carry:        
        mov     BYTE [rdx + 6], 0
.end:
        ret

set_my_flag_z:
        cmp     BYTE [rdx + 7], 1
        ret

set_my_flag_c:
        mov     rax, 0
        cmp     al, BYTE [rdx + 6]
        ret

section .bss
core: resq 1
registers: resq CORES

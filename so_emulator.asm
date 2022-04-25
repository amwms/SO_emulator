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
; rdx, rcx, rsi, rdi, rax, r8
so_emul:
        push    r12 
        push    r13 

        xchg    rdx, rcx 
        mov     r12, rsi
        mov     r11, rdi

        lea     r8, [rel registers] 
        lea     rdx, [r8 + rdx * 8]       ; address of the first SO register

        movzx   r13, BYTE [rdx + 4]       ; counter of loops

        cmp     rcx, 0
        je      .save_result

.loop:
        cmp     WORD [r11 + r13 * 2], 0xFFFF
        jne     .not_break
; ============  BRK  ============
; Breaks the code (sets the break flag - r14 - to 1). Doesn't modify flags Z and C.
        inc     r13b
        jmp     .save_result

.not_break:
        call    get_group                 ; group id in register r8w
        call    handle_instruction

        inc     r13b
        loop    .loop
        
.save_result:      
        mov     [rdx + 4], r13b
        mov     rax, [rdx]

        pop     r13 
        pop     r12
        ret

; ================= HANDLE INSTRUCTION =========================
handle_instruction:
        cmp     r8w, 0
        jne     .group_one
; -------------  GROUP ZERO  -------------

        call    get_first_3_bits          ; r9w - second arg
        call    get_second_3_bits         ; r10w - first arg
        call    get_last_8_bits           ; r8w - instruction id

        movzx   rdi, r9w                  ; init instruction args
        movzx   rsi, r10w

        call    get_register

        mov     rsi, rax
        xchg    rsi, rdi

        call    get_register
        mov     rsi, rax                  

        cmp     r8w, 0x0000               ; check if instruction is MOV
        jne     .fun_OR
; ============  MOV  ============
; Writes value arg2 into arg1 (the same as mov in nasm). Doesn't modify flags C and Z.
; arguments: rdi - arg1 address, rsi - arg2 address        
        mov     sil, [rsi]
        mov     [rdi], sil

        jmp     .end
.fun_OR:
        cmp     r8w, 0x0002
        jne     .fun_ADD
; ============  OR   ============
; Writes OR value of arg2, arg1 into arg1 (the same as or in nasm). Doesn't modify flags C, but modifies Z.
; arguments: rdi- arg1 address, rsi - arg2 address
        mov     sil, [rsi]
        or      [rdi], sil
        call    update_flag_z

        jmp     .end
.fun_ADD:
        cmp     r8w, 0x0004
        jne     .fun_SUB
; ============  ADD  ============
; Adds value arg2 to arg1 (the same as add in nasm). Doesn't modify flags C, but modifies Z.
; arguments: rdi - arg1 address, rsi - arg2 address        
        mov     sil, [rsi]
        add     [rdi], sil
        call    update_flag_z

        jmp     .end
.fun_SUB:
        cmp     r8w, 0x0005
        jne     .fun_ADC
; ============  SUB  ============
; Subtracts value arg2 to arg1 (the same as sub in nasm). Doesn't modify flags C, but modifies Z.
; arguments: rdi - arg1 address, rsi - arg2 address
        mov     sil, [rsi]
        sub     [rdi], sil
        call    update_flag_z

        jmp     .end
.fun_ADC:
        cmp     r8w, 0x0006
        jne     .fun_SBB
; ============  ADC  ============
; Adds value arg2 and C to arg1 (the same as adc in nasm). Modifies flags C and Z.
; arguments: rdi - arg1 address, rsi - arg2 address
        call set_my_flag_c

        mov     sil, [rsi]
        adc     [rdi], sil

        call    update_flag_c
        call    update_flag_z

        jmp     .end
.fun_SBB:
        cmp     r8w, 0x0007
        jne     .fun_XCHG
; ============  SBB  ============  
; Subtracts value arg2 and C to arg1 (the same as sbb in nasm). Modifies flags C and Z.
; arguments: rdi - arg1 address, rsi - arg2 address     
        call set_my_flag_c

        mov     sil, [rsi]
        sbb     [rdi], sil

        call    update_flag_c
        call    update_flag_z

        jmp     .end
.fun_XCHG:
        cmp     r8w, 0x0008
        jne     .end
; ===========  XCHG  ============
; Exchanges arg2 and arg1 (the same as xchg in nasm). Doesn't modify flags C and Z.
; arguments: rdi - arg1 address, rsi - arg2 address
        mov     al, [rsi]
        xchg    [rdi], al
        mov     [rsi], al

        jmp     .end        

; -------------  GROUP ONE   ------------- 
.group_one:
        cmp     r8w, 1
        jne     .group_two

        call    get_second_3_bits         ; r10w - arg1
        call    get_last_8_bits           ; r8w - imm8

        movzx   rsi, r10w                 ; get arg1 address
        call    get_register
        
        mov     rdi, rax                  ; init instruction args
        movzx   rsi, r8w

        call    get_first_3_bits          ; r9w - instruction id

        cmp     r9w, 0x0000
        jne     .fun_XORI
; ============  MOVI  ============ 
; Writes value imm8 into arg1. Doesn't modify flags C and Z.
; arguments: rdi - arg1 address, rsi - imm8
        mov     [rdi], sil 

        jmp     .end
.fun_XORI:
        cmp     r9w, 0x0003
        jne     .fun_ADDI
; ============  XORI  ============ 
; Xors value imm8 into arg1. Doesn't modify flags C, but modifies Z.
; arguments: rdi - arg1 address, rsi - imm8
        xor     [rdi], sil
        call    update_flag_z

        jmp     .end
.fun_ADDI:
        cmp     r9w, 0x0004
        jne     .fun_CMPI
; ============  ADDI  ============ 
; Adds value imm8 into arg1. Doesn't modify flags C, but modifies Z.
; arguments: rdi - arg1 address, rsi - imm8
        add     [rdi], sil
        call    update_flag_z

        jmp     .end
.fun_CMPI:
        cmp     r9w, 0x0005
        jne     .fun_RCR
; ============  CMPI  ============ 
; Compares value imm8 to arg1. Modifies flags C and Z.
; arguments: rdi - arg1 address, rsi - imm8
        cmp     [rdi], sil
        call    update_flag_z
        call    update_flag_c

        jmp     .end
.fun_RCR:
        cmp     r9w, 0x0006
        jne     .end
; ============  RCR   ============ 
; Rotates arg1 by one bit according to flag C. Doesn't modify flags Z, but modifies C.
; arguments: rdi - arg1 address
        call    set_my_flag_c
        rcr     BYTE [rdi], 1
        call    update_flag_c

        jmp     .end

; -------------  GROUP TWO   ------------- 
.group_two:                             
        cmp     r8w, 2
        jne     .group_three

        call    get_second_3_bits         ; r10w - instruction id and new flag C value

        mov     BYTE [rdx + 6], r10b      ; set C flag to new value
        jmp     .end

; ------------  GROUP THREE  -------------
.group_three:
        cmp     r8w, 3
        jne     .group_three

        call    get_second_3_bits         ; r10w
        call    get_last_8_bits           ; r8w

        movzx   rdi, r8w

        cmp     r10w, 0x0000              ; instruction JMP
        jne     .fun_JNC
; ============  JMP  ============ 
; Works like jmp in nasm (jumps imm8 instructions). Doesn't modify flags Z and C.
; arguments: rdi - imm8
        add     r13b, dil

        jmp     .end
.fun_JNC:
        cmp     r10w, 0x0002
        jne     .fun_JC
; ============  JNC  ============
; Works like jnc in nasm (jumps imm8 instructions if flag C not is set). Doesn't modify flags Z and C.
; arguments: rdi - imm8
        cmp     BYTE [rdx + 6], 0
        jne      .end_jnc
        add     r13b, dil
.end_jnc:

        jmp     .end
.fun_JC:
        cmp     r10w, 0x0003
        jne     .fun_JNZ
; ============  JC   ============
; Works like jnc in nasm (jumps imm8 instructions if flag C is set). Doesn't modify flags Z and C.
; arguments: rdi - imm8
        cmp     BYTE [rdx + 6], 1
        jne      .end_jc        
        add     r13b, dil
.end_jc:

        jmp     .end
.fun_JNZ:
        cmp     r10w, 0x0004
        jne     .fun_JZ
; ============  JNZ  ============
; Works like jnz in nasm (jumps imm8 instructions if flag Z is not set to 1). Doesn't modify flags Z and C.
; arguments: rdi - imm8
        cmp     BYTE [rdx + 7], 0
        jne      .end_jnz
        add     r13b, dil
.end_jnz:

        jmp     .end
.fun_JZ:
        cmp     r10w, 0x0005
        jne     .end
; ============  JZ   ============
; Works like jz in nasm (jumps imm8 instructions if flag Z is set to 1). Doesn't modify flags Z and C.
; arguments: rdi - imm8
        cmp     BYTE [rdx + 7], 1
        jne      .end
        add     r13b, dil
.end:
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
        cmp     si, 3
        jg      .x_value

        xor     r9, r9
        mov     r9w, si
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
        movzx   r9, BYTE [rdx + 1] 
        
        add     r9b, r10b
        movzx   rax, r9b
        lea     rax, [r12 + rax]

        jmp     .end
.yd_value:        
        movzx   r10, BYTE [rdx + 3]
        movzx   r9, BYTE [rdx + 1]

        add     r9b, r10b
        movzx   rax, r9b
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
registers: resq CORES

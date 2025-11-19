#define FUNCTION_NAME us_stereo
/*
void us_stereo(
    int32_t * coefs,
    int32_t * l_history,
    int32_t * r_history,
    streaming chanend c_in,
    int32_t history_offset,     +1
    int32_t * ring_buffer,      +2
    int32_t * tail,             +3
    int32_t ring_buffer_size,   +4
    int32_t num_phase,          +5  (number of polyphase filter)
    int32_t phase_size,         +6  (in vpu mac size (8word))
    int32_t final_shr);         +7
*/

    #define NSTACKWORDS 32

    .cc_top FUNCTION_NAME.function
    .type   FUNCTION_NAME,@function

    .issue_mode dual
    .align 4

#define BYTES_PER_WORD 4
#define CHANNELS 2
#define WORDS_PER_VECTOR 8
#define BYTES_PER_VECTOR (WORDS_PER_VECTOR*BYTES_PER_WORD)

#define ZERO    0x0
#define ONE     0x40000000
filter_l_1010:
    .word ZERO, ZERO, ZERO, ZERO, ONE, ZERO, ONE, ZERO
filter_l_0101:
    .word ZERO, ZERO, ZERO, ZERO, ZERO, ONE, ZERO, ONE
filter_r_1010:
    .word ONE, ZERO, ONE, ZERO, ZERO, ZERO, ZERO, ZERO
filter_r_0101:
    .word ZERO, ONE, ZERO, ONE, ZERO, ZERO, ZERO, ZERO
zeros:
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .align 16
    .globl FUNCTION_NAME
.globl FUNCTION_NAME.nstackwords
.set   FUNCTION_NAME.nstackwords, NSTACKWORDS
FUNCTION_NAME:
    { dualentsp NSTACKWORDS     ; nop               }

    stw r4, sp[NSTACKWORDS-1]
    stw r5, sp[NSTACKWORDS-2]
    stw r6, sp[NSTACKWORDS-3]
    stw r7, sp[NSTACKWORDS-4]
    stw r8, sp[NSTACKWORDS-5]
    stw r9, sp[NSTACKWORDS-6]
    stw r10, sp[NSTACKWORDS-7]      // sp[25]

    // store coefs to stack[0]
    stw r0, sp[24]
    // store l,r history to stack[1,2]
    std r2, r1, sp[0]   // sp[1] sp[0]
    // store the final_shr for the VLSAT to stack[2-9]
    ldw r0, sp[NSTACKWORDS+7]
    std r0, r0, sp[1]   // sp[2] sp[3]
    std r0, r0, sp[2]   // sp[4] sp[5]
    std r0, r0, sp[3]   // sp[6] sp[7]
    std r0, r0, sp[4]   // sp[8] sp[9]
    // store start of ring buffer and tail to stack[10,11]
    ldw r0, sp[NSTACKWORDS+2]
    ldw r1, sp[NSTACKWORDS+3]
    std r0, r1, sp[5]   // sp[11] sp[10]
    // store sample history offset to stack[12]
    ldw r0, sp[NSTACKWORDS+1]
    stw r0, sp[12]
    // store c_in to stack[13]
    stw r3, sp[13]
    // store num_phase and phase size to stack[14,15]
    ldw r0, sp[NSTACKWORDS+5]
    ldw r1, sp[NSTACKWORDS+6]
    stw r0, sp[14]
    stw r1, sp[15]

    // temp vstr store at stack[16-23]

    // program start
    ldc r9, BYTES_PER_VECTOR        // r9: BYTES_PER_WORD
    ldc r10, BYTES_PER_VECTOR*3     // r10: coefs rewind
    ldd r7, r8, sp[5]              // r7: ring_buffer ptr, r8: tail ptr

outer_loop:
    ldw r4, sp[12]
    ldw r3, sp[13]
    { testct r11, res[r3]       ; ldw r0, sp[0]                 }   // r0: &l_history[0]
    bt r11, exit
    { in r11, res[r3]           ; add r2, r0, r4                }   // r2: &l_history[offset]
    { in r11, res[r3]           ; stw r11, r2[0]                }
    { ldw r2, sp[1]             ; add r1, r0, BYTES_PER_WORD    }   // r2: &r_history[0], r1: &l_history[4]
    { add r4, r2, r4            ; add r3, r2, BYTES_PER_WORD    }   // r4: &r_history[offset], r3: &r_history[4]
    { stw r11, r4[0]            ; nop                           }
    { ldw r4, sp[24]             ; add r11, r2, 0               }   // r4: &coeff[0], r11: r2
    ldw r6, sp[15]                                                  // r6: phase size
    { sub r6, r6, 2             ; ldw r5, sp[14]                }   // burst 2, r5: num of phase
    { vclrdr                    ; nop                           }
    bu mac_loop
phase_loop:
    { nop                       ; ldaw r11, sp[2]               }
    { vlsat r11[0]              ; ldaw r11, sp[16]              }   // turn all accumulators into 32 bits
    { vstr r11[0]               ; nop                           }   // store accumulators result into stack[16-23]
    { vldc r11[0]               ; nop                           }   // load the accumulators result into VC from stack
    { vclrdr                    ; ldap r11, filter_r_1010       }   // clear vR vD
    { vlmaccr r11[0]            ; ldap r11, filter_l_1010       }   // r us t1, vD:vR -> {r_us_t1, 0, 0, 0}
    { vlmaccr r11[0]            ; ldap r11, filter_r_0101       }   // l us t1, vD:vR -> {l_us_t1, r_us_t1, 0, 0}
    { vlmaccr r11[0]            ; ldap r11, filter_l_0101       }   // r us t0, vD:vR -> {r_us_t0, l_us_t1, r_us_t1, 0}
    { vlmaccr r11[0]            ; ldap r11, zeros               }   // l us t0, vD:vR -> {l_us_t0, r_us_t0, l_us_t1, r_us_t1}, r11: all zeros for vlsat
    { vlsat r11[0]              ; ldc r11, BYTES_PER_WORD*4     }   // sat(vD:vR), r11: BYTES_PER_WORD*4 = 4 sample size
    { vstr r7[0]                ; add r7, r7, r11               }   // save result to ring buffer, update ring buffer ptr
    { ldw r11, r8[0]            ; nop                           }   // r11: tail value
    { ldw r6, sp[NSTACKWORDS+4] ; add r11, r11, 4               }   // r6: ring_buffer size, r11: tail + 4
    { stw r11, r8[0]            ; eq r11, r11, r6               }   // update tail ptr, r11: check if tail at ring buffer end
    { bf r11, prepare_mac_loop  ; nop                           }   // if tail not at buffer end, prepare mac loop
    { ldw r7, sp[11]            ; ldc r11, 0                    }   // r7: ring buffer start, r11: 0
    { stw r11, r8[0]            ; nop                           }   // update tail ptr to 0
prepare_mac_loop:
    { ldw r6, sp[15]            ; sub r5, r5, 2                 }   // r6: phase size, r5: r5-2 processed two polyphase filter
    { bf r5, outer_loop         ; sub r6, r6, 2                 }   // burst 2
    ldd r1, r0, sp[0]                                               // r0: &l_history[0], r2: &r_history[0]
    { vclrdr                    ; nop                           }
    bu mac_loop_no_move
mac_loop:
    // swap r11 for channel
    { add r2, r11, 0    ; add r11, r0, 0    }   // r11: r0
    // left channel
    { vldc r1[0]        ; add r1, r1, r9    }
    { vstc r11[0]       ; add r11, r11, r9  }
    { vlmaccr r4[0]     ; add r4, r4, r9    }
    { vlmaccr r4[0]     ; add r4, r4, r9    }
    { vldc r1[0]        ; add r1, r1, r9    }
    { vstc r11[0]       ; add r11, r11, r9  }
    { vlmaccr r4[0]     ; add r4, r4, r9    }
    { vlmaccr r4[0]     ; sub r4, r4, r10   }   // rewind
    // swap r11 for channel
    { add r0, r11, 0    ; add r11, r2, 0    }
    // right channel
    { vldc r3[0]        ; add r3, r3, r9    }
    { vstc r11[0]       ; add r11, r11, r9  }
    { vlmaccr r4[0]     ; add r4, r4, r9    }
    { vlmaccr r4[0]     ; add r4, r4, r9    }
    { vldc r3[0]        ; add r3, r3, r9    }
    { vstc r11[0]       ; add r11, r11, r9  }
    { vlmaccr r4[0]     ; add r4, r4, r9    }
    { vlmaccr r4[0]     ; add r4, r4, r9    }
    { bt r6, mac_loop   ; sub r6, r6, 2     }   // vD:vR -> {right_f1, right_f0, left_f1, left_f0}
    bu phase_loop
mac_loop_no_move:
    // left channel
    { vldc r0[0]                ; add r0, r0, r9    }
    { vlmaccr r4[0]             ; add r4, r4, r9    }
    { vlmaccr r4[0]             ; add r4, r4, r9    }
    { vldc r0[0]                ; add r0, r0, r9    }
    { vlmaccr r4[0]             ; add r4, r4, r9    }
    { vlmaccr r4[0]             ; sub r4, r4, r10   }   // rewind
    // right channel
    { vldc r1[0]                ; add r1, r1, r9    }
    { vlmaccr r4[0]             ; add r4, r4, r9    }
    { vlmaccr r4[0]             ; add r4, r4, r9    }
    { vldc r1[0]                ; add r1, r1, r9    }
    { vlmaccr r4[0]             ; add r4, r4, r9    }
    { vlmaccr r4[0]             ; add r4, r4, r9    }
    { bt r6, mac_loop_no_move   ; sub r6, r6, 2     }
    bu phase_loop

exit:
    {inct r0, res[r3]; nop}
    ldw r4, sp[NSTACKWORDS-1]
    ldw r5, sp[NSTACKWORDS-2]
    ldw r6, sp[NSTACKWORDS-3]
    ldw r7, sp[NSTACKWORDS-4]
    ldw r8, sp[NSTACKWORDS-5]
    ldw r9, sp[NSTACKWORDS-6]
    ldw r10, sp[NSTACKWORDS-7]
    retsp NSTACKWORDS

    .cc_bottom FUNCTION_NAME.function
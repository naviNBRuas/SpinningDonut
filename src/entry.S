.section .text
.global _start

_start:
    /* Clear rbp (stack frame base) */
    xor %rbp, %rbp
    
    /* Move stack pointer to rdi (argc) */
    pop %rdi
    
    /* Move stack pointer to rsi (argv) */
    mov %rsp, %rsi
    
    /* Call main(argc, argv) */
    call main
    
    /* Call exit(result) */
    mov %rax, %rdi
    mov $60, %rax /* sys_exit */
    syscall

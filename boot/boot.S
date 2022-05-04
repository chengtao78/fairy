;文件名: boot.asm
;说明:   加载setup到0x90000处，然后跳转到setup中
;作者:   marsinfan
;日期:   2005/12/29

;---------------------------------------------------------------------------
; 常量定义
;---------------------------------------------------------------------------
SETUP_SEG               EQU 0x9000      ; setup的段地址
SETUP_OFFSET            EQU 0x0000      ; setup加载到的段内偏移量
SS_SEG                  EQU 0x9000      ; 堆栈段地址
SETUP_LEN               EQU 0X02        ; setup占用的扇区数

[BITS 16]
[ORG 0x7C00]
    xor ax, ax            
    mov ds, ax
    mov es, ax                          ; 设置 ds = cs = 0
    mov ax, SS_SEG
    mov ss, ax                          ; 设置 ss = SS_SEG
    mov [boot_drv], dl                  ; 保存boot drive
    mov sp, 0xff00                      ; 初始化堆栈指针

    mov si, load_msg
    call print_msg
    jmp $                               ; 打印出错信息后死机    
       
;加载硬件参数设置程序
load_setup:    
    mov ax, SETUP_SEG                   ; 0x9000
    mov es, ax
    xor bx, bx                          ; 
    mov cx, 0x0002                      ; ch = 磁道号, cl = 扇区号
    mov dx, 0x0000                      ; dh = 磁头号, dl = 驱动器号
    mov ax, 0x0200 + SETUP_LEN          ; setup程序占2个扇区      
    int 0x13;
    jnc read_setup_ok

    mov si, err_msg
    call print_msg
    jmp $                               ; 打印出错信息后死机    

    
read_setup_ok:
    jmp word SETUP_SEG: SETUP_OFFSET;   ; 跳转到setup程序

;---------------------------------------------------------------------------
;工具函数定义    

;---------------------------------
;打印字符串
; print_msg: 利用BIOS中断（int 10h）进行写屏 
; 参数: si：字符串的首地址, 字符串以结尾
;调用:ah=eh
;     al=要写的字符
;--------------------------------------------------------
print_msg:      
    push ax
    mov  ah, 0eh
disp_next_ch:        
    lodsb                               ; `LODSB' loads a byte from `[DS:SI]' or `[DS:ESI]' into `AL'
    cmp  al, 0
    jz   quit
    int  10h                            ; 利用BIOS int 10h中断ah=0eh功能进行打印字符
    jmp  disp_next_ch
quit:   
    pop  ax  
    ret

load_msg    db  10, 13, "Hello Fairy! This is baremetal Operate Syetem", 0
err_msg     db  10, 13, "Kernel loading error!", 0    
boot_drv    db  0                            ; 启动驱动器号


times 510 - ($ - $$)  db  0        ; 填充一个扇区
dw 0x0aa55                         ; 启动扇区标志


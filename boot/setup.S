;文件名: setup.asm
;说明:   获取硬件信息，加载内核到0x10000处，进行分段，
;        移动内核到0x100000处，进行分页，跳转到start_kernel中
;作者:   marsinfan
;日期:   2005/12/29


;---------------------------------------------------------------------------
; 常量定义
;---------------------------------------------------------------------------
REAL_KERNEL_SEG         EQU 0x1000      ; kernel加载到的段地址
REAL_KERNEL_OFFSET      EQU 0x0000      ; kernel加载到的段内偏移量

SETUP_SEG               EQU 0x9000      ; setup的段地址
SETUP_OFFSET            EQU 0x0000      ; setup加载到的段内偏移量

SECTOR_SPER_TRACK       EQU 18          ; 1.44M软盘的扇区数
BYTE_SPERSECTOR         EQU 512         ; 每扇区字节数

LOAD_ADDR               EQU 0x7C00      ; 引导程序地址  
NEW_LOAD_ADDR           EQU 0x0600      ; 移动后的引导程序地址  

PARAM_ADDR              EQU 0x0500      ; 硬件参数存放的地址
    
GDT_SEG                 EQU 0x0000      ; gdt的段地址
GDT_0FFSET              EQU 0x0800      ; gdt的段内偏移量

PAGE_SIZE               EQU 0x1000      ; 页表大小
PAGE_DIR                EQU 0x10000     ; 页目录地址
PAGE_0_ADDR             EQU 0x11000     ; 第一个页表地址
PAGE_1_ADDR             EQU 0x12000     ; 第二个页表地址
PAGE_2_ADDR             EQU 0x13000     ; 第三个页表地址
PAGE_3_ADDR             EQU 0x14000     ; 第四个页表地址
;ADDRS_PAGE              EQU 0x400      ; 每页表所容纳的地址数
PAGE_OFFSET             EQU 0xC0000000  ; 进行分页后，内核所在的虚拟地址
SMAP                    EQU 0x534d4150
E820MAX                 EQU 128         ; number of entries in E820MAP
E820NR                  EQU PARAM_ADDR + 46

[BITS 16]
[ORG 0x90000]
    mov    ax, SETUP_SEG
    mov    ds, ax
    mov    es, ax

    mov    si, boot_msg
    call   print_msg
    
    mov    ax, 0x0000; 
    mov    ds, ax
    mov    es, ax
        
; 读取光标的坐标    
    mov    ah, 0x03    ;
    xor    bh, bh
    int    0x10        ; save it in known place, con_init fetches
    mov    [PARAM_ADDR + 0], dx        ; 光标的位置存放到PARAM_ADDR处
    
; 取得物理内存大小 (1M以上的扩展内存, KB)
    mov    ah, 0x88
    int    0x15

;;探测内存是否小于16M,如果小于，则提示并死机，INT中断获取的大小会少1M，因此后面要加1M
    cmp    ax, 0x3C00
    jae    next
    mov    ax, SETUP_SEG
    mov    ds, ax  
    mov    si, mem_too_small
    call   print_msg
    jmp    $    

next:    
    add    ax, 1024;
    shr    ax, 2                          ; 换成4k个数，需要ax个Page
    shr    ax, 10                         ; 换成所需页表项数，一个页表装1K个Page
    ;mov    [PARAM_ADDR + 2], ax          ; 16M的页目录项数存放到PARAM_ADDR + 2处
    mov    ax, 4                            ;直接给4个页表干嘛，1个页表只能表示4M，难道只想
                                            ;管理16M吗，真土;不如最大256M
    mov    [PARAM_ADDR + 2], ax           ; 16M的页目录项数存放到PARAM_ADDR + 2处


; 取得video-card显示模式
    mov    ah, 0x0f
    int    0x10
    mov    [PARAM_ADDR + 4], bx        ; bh = display page
    mov    [PARAM_ADDR + 6], ax        ; al = video mode, ah = window width
    
; 取得EGA/VGA配置参数
    mov    ah, 0x12
    mov    bl, 0x10
    int    0x10
    mov    [PARAM_ADDR + 8], ax
    mov    [PARAM_ADDR + 10], bx
    mov    [PARAM_ADDR + 12], cx
    
;复制硬盘信息
    lds    si, [4 * 0x41];
    mov    di, PARAM_ADDR + 14
    mov    cx, 0x10;
    cld
    rep
    movsb

;INT 15 E820 - newer BIOSes - GET SYSTEM MEMORY MAP
;Inp.:
;   AX = E820h
;   EAX = 0000E820h
;   EDX = 534D4150h ('SMAP')
;   EBX = continuation value or 00000000h to start at beginning of map
;   ECX = size of buffer for result, in bytes (should be >= 20 bytes)
;   ES:DI -> buffer for result (see #00560)
;Return: CF clear if successful
;       EAX = 534D4150h ('SMAP')
;       ES:DI buffer filled
;       EBX = next offset from which to copy or 00000000h if all done
;
;    ECX = actual length returned in bytes
;   CF set on error
;       AH = error code (86h) (see #00475 at INT 15/AH=80h)
;Notes: originally introduced with the Phoenix BIOS v4.0, this function is
;     now supported by most newer BIOSes, since various versions of Windows
;     call it to find out about the system memory
;   a maximum of 20 bytes will be transferred at one time, even if ECX is
;     higher; some BIOSes (e.g. Award Modular BIOS v4.50PG) ignore the
;     value of ECX on entry, and always copy 20 bytes
;
;some BIOSes expect the high word of EAX to be clear on entry, i.e.
;     EAX=0000E820h
;   if this function is not supported, an application should fall back
;     to AX=E802h, AX=E801h, and then AH=88h
;   the BIOS is permitted to return a nonzero continuation value in EBX
;     and indicate that the end of the list has already been reached by
;     returning with CF set on the next iteration
;   this function will return base memory and ISA/PCI memory contiguous
;     with base memory as normal memory ranges; it will indicate
;
;  chipset-defined address holes which are not in use and motherboard
;     memory-mapped devices, and all occurrences of the system BIOS as
;     reserved; standard PC address ranges will not be reported
;SeeAlso: AH=C7h,AX=E801h"Phoenix",AX=E881h,MEM xxxxh:xxx0h"ACPI"
;
;Format of Phoenix BIOS system memory map address range descriptor:
;Offset Size    Description (Table 00559)
; 00h   QWORD   base address
; 08h   QWORD   length in bytes
; 10h   DWORD   type of address range (see #00560)
;
;(Table 00560)
;Values for System Memory Map address type:
; 01h   memory, available to OS
; 02h   reserved, not available (e.g. system ROM, memory-mapped device)
; 03h   ACPI Reclaim Memory (usable by OS after reading ACPI tables)
; 04h   ACPI NVS Memory (OS is required to save this memory between NVS
;     sessions)
; other not defined yet -- treat as Reserved
;

    mov ax, 0x0000
    mov ds, ax
    mov es, ax
    
    mov     byte [E820NR], 0        ; E820 map数量清零
    jmp     meme820; 
bail820:                            ; 获取meme820失败，死机
    mov    ax, SETUP_SEG
    mov    ds, ax  
    mov    si, get_mem_size_err_msg ;     
    call   print_msg                ; 
    jmp    $      
    
meme820:
    xor     ebx, ebx                ; continuation value or 00000000h to start at beginning of map  
                                    ; Copied from Ralf Brown's Interrupt List
    mov     di, PARAM_ADDR + 48     ; 获取内存信息存放的地址

jmpe820:
    mov     eax, 0x0000e820         ; 必须为 e820
    mov     edx, SMAP               ; 必须为'SMAP'
    mov     ecx, 20                 ; e820结构的大小

    int     0x15                    ; 调用 0x15中断
    jc      bail820                 ; 如果失败，则提示后死机

    cmp     eax, SMAP               ; 检查调用返回值是否是`SMAP'
    jne     bail820                 ; 不是则表示调用失败，提示死机


good820:
    mov     al, byte [E820NR]       ; 检查获取的E820 map数量，
    cmp     al, E820MAX             ; 如果超过128，说明有错误
    jae     bail820

    inc     byte [E820NR]           ; E820 map数量加一
    mov     ax, di
    add     ax, 20                  ; 指向一下个存放E820map地址
    mov     di, ax
again820:
    cmp     ebx, 0                  ; 检测ebx
    jne     jmpe820                 ; 如果不等于0表示后面还有内存需要检测

    call cls                        ; 清屏

 
    mov ax, SETUP_SEG
    mov ds, ax
    mov es, ax
   
    mov ah, 2           
    mov dx, 0                            ; 光标的位置 0,0
    mov bh, 0                            ; video page 0
    int 10h                              ; 设置cursor到 0,0
    mov si, boot_msg                     ;     
    call print_msg                       ; 显示"Starting Fairy Sky...",


;开始加载内核
load_kernel:    
    mov ax, REAL_KERNEL_SEG              ; 0x1000
    mov es, ax
    xor bx, bx                           ; 
    mov cx, 0x0004                       ; ch = 磁道号, cl = 扇区号
    mov dx, 0x0000                       ; dh = 磁头号, dl = 驱动器号
    mov ax, 1024                         ; 内核大小512K; Bios Mapped: 0x10000 -> 0x90000, Usr Self Defined
    mov [kernel_sectors], ax             ; 设置待读取的扇区数

    mov si, kernel_msg                     ;     
    call print_msg                       ; 显示"Starting Fairy Sky...",

    call read_kernel_to_memory           ; 从chs:002读取内核到0x1000处

    mov si, kernel_load
    call print_msg                       ; 显示"Starting Fairy Sky...",

;对8259重新编程
    mov   al,   0x11        ; initialization sequence
    out   0x20, al          ; send it to 8259A-1
    dw    0x00eb, 0x00eb    ; jmp $+2, jmp $+2
    out   0xA0, al          ; and to 8259A-2
    dw    0x00eb, 0x00eb
    mov   al,   0x20        ; start of hardware int's (0x20)
    out   0x21, al
    dw    0x00eb, 0x00eb
    mov   al,   0x28        ; start of hardware int's 2 (0x28)
    out   0xA1, al
    dw    0x00eb, 0x00eb
    mov   al,   0x04        ; 8259-1 is master
    out   0x21, al
    dw    0x00eb, 0x00eb
    mov   al,   0x02        ; 8259-2 is slave
    out   0xA1, al
    dw    0x00eb, 0x00eb
    mov   al,   0x01        ; 8086 mode for both
    out   0x21, al
    dw    0x00eb,0x00eb
    out   0xA1, al
    dw    0x00eb, 0x00eb
    mov   al,0xFF           ; mask off all interrupts for now
    out   0xA1, al
    dw    0x00eb, 0x00eb
    mov   al,   0xFB        ; mask all irq's but irq2 which
    out   0x21, al          ; is cascaded    
        
; 如果运行到这里代表已经完成内核的加载
pre_goto_pm:    
    call cls                            ; 清屏
            
    mov dx, 0x3f2    
    mov al, 0x0c
    out dx, al                          ; 停止软驱

    ;准备开始进入保护模式
    cli                                 ; 关中断
    push es

    mov ax, GDT_SEG
    mov es, ax                          ; 
    mov di, GDT_0FFSET
    mov si, gdt_table
    mov cx, gdt_end - gdt_table
    rep movsb                           ; 把gdt_table移动到0x0000:0x0800处
    pop es
    
    lgdt [tmpgdtr]                         ; 加载GDT     

    mov eax, cr0        
    or al, 0x01           
    mov cr0, eax                        ; 进入保护模式,之后不要用BIOS中断

    ;打开A20,这样可以访问高1M的内存
    in al, 0x92
    or al, 2
    out 0x92, al
        
    jmp dword KERNEL_CS: go_pm           ; 跳到32位code中, 此时是TMP，所以能跳过去

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

;--------------------------------------------------------
;清屏
;调用：ah=7
;      al=向下滚动的行数
;      bh=空白顶行所使用的属性
;      ch=滚动的顶行
;      cl=滚动的左边列
;      dh=滚动的底行
;      dl=滚动的右边列
;--------------------------------------------------------
cls: 
    mov ax, 0x0700    
    mov bh, 0x07                        ; 
    mov cx, 0x0000
    mov dx, 0x174f                      ; 利用BIOS int 10h中断ah=07h功能进行清屏
    int 0x10
    ret
    
;--------------------------------------------------------    
;  read_kernel_to_memory : 读指定的扇区到内存中 
;  Input parameters: 
;              es:bx = 待写的内存地址
;              ch = 磁道号 
;              cl = 开始的扇区号
;              dh = 磁头号
;              dl = 驱动器号
;              [kernel_sectors] = 待读的扇区数
;--------------------------------------------------------    
read_kernel_to_memory:
readon:
    call read_one_sector            ; 每个磁道有512*18=9k字节
    dec word [kernel_sectors]       ; 每读一个扇区后，待读内核扇区数减一，读到0为止
    jz read_kernel_ok               ; 读取内核完成
    cmp bx, 0  
    je got_64k                      ; 完成64k读写后,下移64k进行写

next_sector:
    cmp cl, SECTOR_SPER_TRACK - 1   ; 是否是磁道的最后一个扇区
    ja read_next_track              ; 如果读到最后一个扇区，就开始读下一个磁道 
    inc cl                          ; 设置读取第cl个扇区
    jmp readon                      ; 又开始读扇区

got_64k: 
    call print_dot                  ; 
    push ax
    mov ax, es
    add ax, 0x1000                  ; 设置ES为下个64k的边界
    mov es, ax
    pop ax
    jmp next_sector    

read_next_track:
    mov cl, 1
    inc dh                          ; 下一个磁头
    and dh, 0x01                
    cmp dh, 0                   
    jnz same_track                  ; 如果磁头号为奇数，则读同一磁道第1磁头
    inc ch                          ; 跳到下个磁道

same_track: 
    jmp readon      
    
read_kernel_ok: 
    ret                             ;读内核完成

read_one_sector: 
    mov ax, 0x0201
    ;mov ah, 2                       ; 利用BIOS int 13h的功能2读取磁盘
    ;mov al, 1                       ; 每次读取一个扇区
    ;mov dl, [boot_drv]          
    call read_data_from_floppy         
    add bx, 512                     ; 读内核的内存指针往后移动512字节,每一扇区为512字节,当读完64k后,bx会溢出恢复为0
    ret

;-------------------------------------------------------    
; 打印'.'(0x2e):
;-------------------------------------------------------    
print_dot:    
    push ax    
    mov ax, 0x0e2e    
    int 0x10    
    pop ax    
    ret     
    
;-------------------------------------------------------    
; read_data_from_floppy: 
;          从软驱中读取,如果出错则重试3次,超过3次则死机ayed.    
;-------------------------------------------------------
read_data_from_floppy:    
    push ax  
    push bx  
    push cx  
    push dx  
    int 0x13                    ; 读取
    jnc read_ok
    xor ax, ax  
    xor dx, dx  
    int 0x13                    ; 如果读失败，则软驱重启
    dec byte [retries]
    jz .load_error              ; 死机
    pop dx  
    pop cx  
    pop bx  
    pop ax  
    jmp read_data_from_floppy

.load_error  
    mov si, err_msg
    call print_msg
    jmp $                        ; 打印出错信息后死机

read_ok:    
    mov byte [retries], 3        ; 恢复重试次数
    pop dx  
    pop cx  
    pop bx  
    add sp, 2                    ; 保存ax
    ret 
;---------------------------------------------------------------------------
    
[BITS 32]
go_pm: 
    mov ax, KERNEL_DS   
    mov ds, ax        
    mov es, ax    
    mov ss, ax        
    mov fs, ax     
    mov gs, ax                  ; 重新设置段寄存器
    mov esp, 0x9FFFF            ; 重新初始化堆栈指针

;移动内核到1M处
move_kernel_high_mem:
    mov edi, 0x100000
    mov esi, 0x10000
    mov ecx, 512 * 1024
    rep movsb

;清空原先存放内核的内存
    mov ecx, 0                  ;
    mov ebx, PAGE_DIR           ;
clear_page_table:
    mov dword [ebx], 0          ;    
    add ebx, 4                  ;
    add ecx, 4                  ;
    cmp ecx, 524288             ;  
    jne clear_page_table        ;  

;在0x10000处建立页目录，16M
;PAGE_OFFSET >> 20得到一个page_dir_entry, 这个20最好注释一下, 
;PAGE_OFFSET >> 22得到page dir index, 然后在乘以4， 所以右移20位，而不是22位 
;映射16M
    mov cx, 0                   ;
    mov ebx, PAGE_DIR + (PAGE_OFFSET >> 20)           ;
    mov eax, PAGE_0_ADDR + 7    ; User, SuperVisor, R/W, Present  
create_page_table:
    mov dword [ebx], eax        ;    
    add eax, PAGE_SIZE          ;        
    add ebx, 4                  ;
    inc cx;    
    cmp cx, [PARAM_ADDR + 2]    ;  
    jne create_page_table       ;  

;建立线性地址与物理地址相同的页目录,一定要建立，只用把0号PDE使能就可以了
;不然当开启分页时后马上就会出错,因为旧的内容全是旧的地址
;等进入start_kernel之后就要取消此页映射
;不然如果有编码错误，且落在低地址区，就麻烦了！！！
;这里只映射0--4M
    mov cx, 0                   ;
    mov ebx, PAGE_DIR           ;
    mov eax, PAGE_0_ADDR + 7    ;
    mov dword [ebx], eax        ;    

;建立页表，此时还是用BIOS空间做页表映射的，等Kernel起来后，要转到其他地址上，把整个内存全映射起来，然后做内存管理
    mov edi, PAGE_3_ADDR + 4092 ; Filling the PDT, 0 ~ 16M to 0xC0000000 ~ 0xC100_0000
    mov eax, 0x00fff007    
    std
l1:    
    stosd    
    sub eax, 0x1000
    jge l1

;准备开启分页
    ;设置页目录地址
    mov eax, PAGE_DIR
    mov cr3, eax

    ;开启分页
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    lgdt [gdtr]    ; 完成分页之后，还需得加载GDT，因为内核在0xC0000000处 
    
    mov esp, 0xC00A0000             ;栈顶指针

high_init:
    ; 将要进入c编写的代码,此处还没有开中断,等到全部加载后便可开中断
    jmp $
    jmp KERNEL_CS: 0xC0100000    ; jmp to kernel 
    
;---------------------------------------------------------------------------
; 以下定义数据

;---------------------------------
;加载到gdtr寄存器中，由于gdt_table会移动到线性地址0x00000800处，所以gdtr得基地址为0x00000800
;---------------------------------
tmpgdtr:
    dw 0x01FF            ; gdt_table的16位界限
    dd 0x00000800        ; 32位基地址, 此处为线性地址0x00000800

gdtr:
    dw 0x01FF            ; gdt_table的16位界限
    dd 0xC0000800        ; 32位基地址, 此处为虚拟地址地址0xC0000800
    
; 中断描述符表暂时还没有用
idtr:
    dw 0
    dd 0x1000 

;---------------------------------
;gdt段描述表 (每段占8bytes)
;---------------------------------
gdt_table
gdt_null                ; 
    dd 0                ; 
    dd 0                ; 
    
k_code_gdt              ; 内核代码段描述符
    dw 0x0ffff          ; 段限为4GB
    dw 0x0000           ; 段基址(0-15) L
    db 0x00             ; 段基址(16-23) M
    db 0x09a            ; 可读可执行代码段,ring0,尚未受到访问
    db 0x0cf            ; 粒度为4k, 32位指令,四个段都在内存,段限为4GB
    db 0x00             ; 段基址(24-31)H
    
k_data_gdt              ; 内核数据段描述符
    dw 0x0ffff          ; 段限为4GB
    dw 0x0000           ; 段基址(0-15) L
    db 0x00             ; 段基址(16-23) M
    db 0x092            ; 可读可写数据段,ring0,尚未受到访问
    db 0x0cf            ; 粒度为4k, 段限为4GB
    db 0x00             ; 段基址(24-31)H
    
u_code_gdt              ; 用户内核代码段描述符
    dw 0x0ffff          ; 段限为4GB                                      
    dw 0x0000           ; 段基址(0-15) L                                 
    db 0x00             ; 段基址(16-23) M                                
    db 0x0fa            ; 可读可执行代码段,ring3,尚未受到访问            
    db 0x0cf            ; 粒度为4k, 32位指令,四个段都在内存,段限为4GB    
    db 0x00             ; 段基址(24-31)H                                 
    
u_data_gdt              ; 用户数据段描述符
    dw 0x0ffff          ; 段限为4GB                                         
    dw 0x0000           ; 段基址(0-15) L                                    
    db 0x00             ; 段基址(16-23) M                                   
    db 0x0f2            ; 可读可写数据段,ring3,尚未受到访问                 
    db 0x0cf            ; 粒度为4k, 段限为4GB                               
    db 0x00             ; 段基址(24-31)H                                    
    
gdt_no_use              ;
    dd 0                ;
    dd 0                ;
gdt_end                 ;

null_sel    equ gdt_null - gdt_table        ;
KERNEL_CS   equ k_code_gdt - gdt_table      ; KERNEL_CS =   8h
KERNEL_DS   equ k_data_gdt - gdt_table      ; KERNEL_DS =   10h       
USER_CS     equ u_code_gdt - gdt_table      ; USER_CS   =   18h
USER_DS     equ u_data_gdt - gdt_table      ; USER_DS   =   20h      

boot_msg    db  "Starting Fairy", 0
kernel_msg  db  10, 13, "Ready to load kernel", 0   
kernel_load  db  10, 13, "Load kernel finished", 0   
err_msg     db  10, 13, "Kernel loading error!", 0   
mem_too_small db 10, 13, "Memory is too small, die!", 0
get_mem_size_err_msg db 10, 13, "Get memory failed, die!", 0
boot_drv    db  0                            ; 启动驱动器号
retries     db  3                            ; 启动时读磁盘失败的重试次数
kernel_sectors    dw  523                    ; 内核所占的扇区数,变量

times 1024 - ($ - $$)  db  0                 ; 填充两个扇区


;;引导到此结束



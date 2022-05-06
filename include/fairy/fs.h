#ifndef __FS_H__
#define __FS_H__

struct inode {
    dev_t       i_dev;              //i节点所在的设备号
    //u32           i_ino;
    umode_t     i_mode;             //文件类型和属性(rwx)位
    nlink_t     i_nlink;            //文件链接数
    uid_t       i_uid;              //用户id(文件拥有者的标识符)
    gid_t       i_gid;              //组id(文件拥有者所在的组)
    dev_t       i_rdev;             //如果该文件是设备文件，代表该设备的设备号
    off_t       i_size;             //文件的大小(字节数)
    time_t      i_atime;            //最后访问的时间
    time_t      i_mtime;            //修改时间(1970.1.1:0秒起)
    time_t      i_ctime;            //i节点自身修改时间
    unsigned long i_data[16];       //逻辑块，其中的直接块，间接块根据不同的文件系统也有差别 
    struct inode_operations * i_op; //操作i节点的具体跳转指针
    struct super_block * i_sb;      //i节点所在文件系统的超级块
    struct wait_queue * i_wait;     //等待该i节点的进程
    struct wait_queue * i_wait2;    /* for pipes */
    unsigned short i_count;         //引用数
    unsigned short i_flags;         //i节点所在文件系统的标志
    unsigned char i_lock;           //是否上锁
    unsigned char i_dirt;           //是否已修改标志
    unsigned char i_pipe;           //管道标志
    unsigned char i_mount;          //安装标志
    unsigned char i_seek;           //搜寻标志(lseek时)
    unsigned char i_update;         //更新标志
};

struct file {
    u16 f_mode;         //文件操作模式(RW位)
    u16 f_flags;        //文件打开和控制的标志
    u16 f_count;        //对应文件句柄(文件描述附)数
    u16 f_rdev;         // 为/dev/tty准备 
    struct inode *f_inode;          //文件对应i节点
    struct file_operations *f_op;   //读写等操作文件的具体跳转指针
    off_t f_pos;        //文件的当前读写位置        
};

//文件操作跳转表结构(不同的文件系统有不同的方法)
struct file_operations {
    int (*lseek) (struct inode *, struct file *, off_t, s32);           //定位文件当前的读写位置
    int (*read) (struct inode *, struct file *, char *, s32);           //读文件
    int (*write) (struct inode *, struct file *, char *, s32);          //写文件
    int (*readdir) (struct inode *, struct file *, struct direntry *, count_t count);   //如果文件是目录，则提供读目录的方法
    int (*select) (struct inode *, struct file *, int, select_table *); //等待文件的状态
    int (*ioctl) (struct inode *, struct file *, u32, u32);             //对文件的其他操作
    int (*open) (struct inode *, struct file *);                        //打开或创建文件
    void (*release) (struct inode *, struct file *);                    //释放
};

//i节点操作跳转表结构(不同的文件系统有不同的方法)
struct inode_operations {
    struct file_operations * default_file_ops;
    int (*create) (struct inode *, const char *, int, int, struct inode **);
    int (*lookup) (struct inode *, const char *, int, struct inode **);
    int (*link) (struct inode *, struct inode *, const char *, int);
    int (*unlink) (struct inode *, const char *, int);
    int (*symlink) (struct inode *, const char *,int, const char *);
    int (*mkdir) (struct inode *, const char *, int,int);
    int (*rmdir) (struct inode *, const char *, int);
    int (*mknod) (struct inode *, const char *, int, int, int);
    int (*rename) (struct inode *, const char *, int, struct inode *, const char *, int);
    int (*readlink) (struct inode *, char *, int);
    struct inode * (*follow_link) (struct inode *, struct inode *);
    int (*bmap) (struct inode *, int);
    void (*truncate) (struct inode *);
};

//超级块操作跳转表结构(不同的文件系统有不同的方法)
struct super_operations {
    void (*read_inode)(struct inode *inode);            //从磁盘上读一个i节点
    void (*write_inode) (struct inode *inode);          //往磁盘上写一个i节点
    void (*put_inode) (struct inode *inode);            //往磁盘上更新一个i节点
    void (*put_super)(struct super_block *sb);          //更新超级块
    void (*write_super) (struct super_block *sb);       //写超级块的其他信息(不确定)
    //void (*statfs) (struct super_block *sb, struct statfs *buf);    //获取文件系统的信息
};

#endif /* __FS_H__ */


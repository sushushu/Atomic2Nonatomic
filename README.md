### atomic是什么
atomic和nonatomic是OC里面修饰属性的一对修饰符，表示原子性和非原子性。

用atomic修饰的时候，编译器会在编译期间在setter, getter 方法里加入一些互斥锁，保证在多线程开发，读取变量的值正确。

但是在setter和getter里面加锁就万事大吉了吗？

看看下面这个示例：

```
@property (atomic, assign) NSInteger obj;

- (void)viewDidLoad {
    [super viewDidLoad];

    NSLock *m_lock = [NSLock new];
    
    //开启一个异步线程对obj的值+1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0;i < 10000;i ++){

             self.obj = self.obj + 1;
            
        }
        NSLog(@"obj : %ld  线程：%@",(long)self.obj , [NSThread currentThread]);
    });
    
    //开启一个异步线程对obj的值+1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0;i < 10000;i ++){

            self.obj = self.obj + 1;
            
        }
        NSLog(@"obj : %ld 线程: %@",(long)self.obj , [NSThread currentThread]);
    });
}

```

上面这段代码是开启两个异步线程频繁的去对ojb执行+1操作，按照正常逻辑来说应该一定会有一个线程打印出20000，但是我们来看一下打印结果：
```
2020-04-15 16:06:45.388099+0800 Atomic2Nonatomic[31861:4542875] obj : 8856  线程：<NSThread: 0x6000033b92c0>{number = 5, name = (null)}
2020-04-15 16:06:45.388126+0800 Atomic2Nonatomic[31861:4542873] obj : 11952 线程: <NSThread: 0x600003386700>{number = 6, name = (null)}
```
然而并没有！

### 替换成nonatomic并且加上互斥锁看看
```
@property (nonatomic, assign) NSInteger obj;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLock *m_lock = [NSLock new];
    
    //开启一个异步线程对obj的值+1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0;i < 10000;i ++){
            [m_lock lock];
             self.obj = self.obj + 1;
            [m_lock unlock];
        }
        NSLog(@"obj : %ld  线程：%@",(long)self.obj , [NSThread currentThread]);
    });
    
    //开启一个异步线程对obj的值+1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0;i < 10000;i ++){
            [m_lock lock];
             self.obj = self.obj + 1;
            [m_lock unlock];
        }
        NSLog(@"obj : %ld 线程: %@",(long)self.obj , [NSThread currentThread]);
    });
}

// 输出：
2020-04-15 16:19:54.566420+0800 Atomic2Nonatomic[31970:4554604] obj : 15712 线程: <NSThread: 0x600000f22880>{number = 6, name = (null)}
2020-04-15 16:19:54.566542+0800 Atomic2Nonatomic[31970:4554603] obj : 20000  线程：<NSThread: 0x600000f1e040>{number = 4, name = (null)}
```
atomic只是对set方法加锁，而我们程序里面的self.obj = self.obj + 1; 这一部分不是线程安全的，后面这个+1操作不是线程安全的，所以要想最终得到20000的结果，需要使用锁对self.intA = self.intA + 1加锁。代码就会得到我们想要的结果。``所以atomic并不能保证线程绝对安全。``

### 最后来看看看看atomic在runtime的内部实现

property 的 atomic 用的是 spinlock_t 自旋锁实现的
```
// getter
id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic) 
{
    // ...
    if (!atomic) return *slot;

    // Atomic retain release world
    spinlock_t& slotlock = PropertyLocks[slot];
    slotlock.lock();
    id value = objc_retain(*slot);
    slotlock.unlock();
    // ...
}
```

```
// setter
static inline void reallySetProperty(id self, SEL _cmd, id newValue, ptrdiff_t offset, bool atomic, bool copy, bool mutableCopy)
{
    // ...
    if (!atomic) {
        oldValue = *slot;
        *slot = newValue;
    } else {
        spinlock_t& slotlock = PropertyLocks[slot];
        slotlock.lock();
        oldValue = *slot;
        *slot = newValue;        
        slotlock.unlock();
    }
    // ...
}
```


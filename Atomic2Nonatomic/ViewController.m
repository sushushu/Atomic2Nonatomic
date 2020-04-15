//
//  ViewController.m
//  Atomic2Nonatomic
//
//  Created by softlipa on 2020/4/15.
//  Copyright © 2020 softlipa. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (atomic, assign) NSInteger obj;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLock *m_lock = [NSLock new];
    
    // 开启一个异步线程对obj的值+1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0;i < 10000;i ++){
//            [m_lock lock];
            self.obj = self.obj + 1;
//            [m_lock unlock];
        }
        NSLog(@"obj : %ld  线程：%@",(long)self.obj , [NSThread currentThread]);
    });
    
    //开启一个异步线程对obj的值+1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0;i < 10000;i ++){
//            [m_lock lock];
            self.obj =  self.obj + 1;
//            [m_lock unlock];
        }
        NSLog(@"obj : %ld 线程: %@",(long)self.obj , [NSThread currentThread]);
    });
}


@end

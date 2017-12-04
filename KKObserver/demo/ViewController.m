//
//  ViewController.m
//  demo
//
//  Created by 张海龙 on 2017/12/4.
//  Copyright © 2017年 kkmofang.cn. All rights reserved.
//

#import "ViewController.h"
#import <KKObserver/KKObserver.h>

#include <objc/runtime.h>


@interface NSObject(Data)

@property(nonatomic,strong,readonly) KKObserver* data;

@end

@implementation NSObject(Data)

-(KKObserver *) data {
    KKObserver * v = objc_getAssociatedObject(self, "_data");
    if(v == nil) {
        v = [[KKObserver alloc] init];
        objc_setAssociatedObject(self, "_data", v, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return v;
}

@end

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    {
        // 绑定表格数据
        __weak UITableView * v = self.tableView;
        
        [self.data on:^(id value, NSArray *changedKeys, void *context) {
            [v reloadData];
        } keys:@[@"items"] context:nil];
        
    }
    
    {
        // 绑定底部计数
        __weak UILabel * v = self.titleLabel;
        [self.data on:^(id value, NSArray *changedKeys, void *context) {
            v.text = value;
        } evaluateScript:@"'总数: ' + (items.length)" context:nil];
    }
    
    {
        // 加载数据
        __weak KKObserver * data = self.data;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [data set:@[@"page"] value:@{@"title":@"Item"}];
            
            [data set:@[@"items"] value:@[
                                          @{@"title":@"A",@"subtitle":@"a",@"ctime":@(1512373388)},
                                          @{@"title":@"B",@"subtitle":@"b",@"ctime":@(1512373388)},
                                          @{@"title":@"C",@"subtitle":@"c",@"ctime":@(1512373388)}
                                        ]];
        });
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"Item"];
    
    if(cell == nil) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Item"];
        
        cell.data.parent = self.data;
        
        __weak UITableViewCell * v = cell;
        
        {
            // 绑定标题
            [cell.data on:^(id value, NSArray *changedKeys, void *context) {
                
                if(v) {
                    v.textLabel.text = (NSString*) value;
                }
                
            } evaluateScript:@"item.title" context:nil];
        }
        
        {
            // 绑定子标题
            [cell.data on:^(id value, NSArray *changedKeys, void *context) {
                
                if(v) {
                    v.detailTextLabel.text = (NSString*) value;
                }
                
            } evaluateScript:@"page.title + ' ' + item.subtitle +'@' + kk.date.format(item.ctime,'yyyy-MM-dd')" context:nil];
        }
    }
    
    [cell.data set:@[@"item"] value:[self.data get:@[@"items",[NSString stringWithFormat:@"%ld",indexPath.row]] defaultValue:nil]];
    
    return cell;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.data get:@[@"items",@"length"] defaultValue:nil] integerValue];
}


@end

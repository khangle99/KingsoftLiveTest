    //
//  UIImageView+SK.m
//  showker
//
//  Created by cain on 14-5-21.
//  Copyright (c) 2014年 cain. All rights reserved.
//

#import "Category.h"

@implementation NSDictionary (DeepCopy)
- (NSMutableDictionary *)mutableDeepCopy {
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] initWithCapacity:[self count]];
    NSArray *keys = [self allKeys];
    for (id key in keys) {
        id oneValue = [self valueForKey:key];
        id oneCopy = nil;

        if(oneValue == (id)[NSNull null]){
            oneValue = nil;
        }else if ([oneValue respondsToSelector:@selector(mutableDeepCopy)]) {
            oneCopy = [oneValue mutableDeepCopy];
        }else if ([oneValue respondsToSelector:@selector(mutableCopy)]) {
            oneCopy = [oneValue mutableCopy];
        }
        if (oneCopy == nil) {
            oneCopy = [oneValue copy];
        }
        [ret setValue:oneCopy forKey:key];
    }
    return ret;
}

@end

@implementation NSArray (DeepCopy)
- (NSMutableArray *)mutableDeepCopy {
    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.count];
    id copyValue;
    for (id obj in self) {
        if(obj == (id)[NSNull null]){
            copyValue = nil;
        }else if ([obj respondsToSelector:@selector(mutableDeepCopy)]){
            copyValue = [obj mutableDeepCopy];
        }else if ([obj respondsToSelector:@selector(mutableCopy)]) {
            copyValue = [obj mutableCopy];
        }
        if (copyValue == nil) {
            copyValue = [obj copy];
        }
        [newArray addObject:copyValue];
    }
    return newArray;
}
@end

@implementation NSNumber (DeepCopy)
- (id)mutableDeepCopy{
    return [self copy];
}
@end

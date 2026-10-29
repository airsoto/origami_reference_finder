#import "RFBridge.h"
#include "MobileEngine.hpp"
@implementation RFBridge
+ (NSString *)searchX:(NSString *)x y:(NSString *)y x2:(NSString *)x2 y2:(NSString *)y2
                width:(NSString *)width height:(NSString *)height line:(BOOL)line rank:(NSInteger)rank {
    mobile::Request r;
    r.x = x.UTF8String; r.y = y.UTF8String;
    r.x2 = x2.UTF8String; r.y2 = y2.UTF8String;
    r.width = width.UTF8String; r.height = height.UTF8String;
    r.line = line; r.rank = (int)rank;
    return [NSString stringWithUTF8String:mobile::solve(r).c_str()];
}
+ (void)cancel { mobile::cancel(); }
@end

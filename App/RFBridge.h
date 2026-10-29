#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface RFBridge : NSObject
+ (NSString *)searchX:(NSString *)x y:(NSString *)y
                   x2:(NSString *)x2 y2:(NSString *)y2
                width:(NSString *)width height:(NSString *)height
                 line:(BOOL)line rank:(NSInteger)rank
    NS_SWIFT_NAME(search(x:y:x2:y2:width:height:line:rank:));
+ (void)cancel;
@end
NS_ASSUME_NONNULL_END

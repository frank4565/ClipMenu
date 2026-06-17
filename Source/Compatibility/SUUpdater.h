#import <Cocoa/Cocoa.h>

@interface SUUpdater : NSObject
@property (nonatomic, retain) NSURL *feedURL;
@property (nonatomic) BOOL automaticallyChecksForUpdates;
@property (nonatomic) NSTimeInterval updateCheckInterval;
@property (nonatomic, readonly) NSDate *lastUpdateCheckDate;

+ (SUUpdater *)sharedUpdater;
- (IBAction)checkForUpdates:(id)sender;
@end

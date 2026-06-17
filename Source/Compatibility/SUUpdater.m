#import "SUUpdater.h"

@implementation SUUpdater

@synthesize feedURL;
@synthesize automaticallyChecksForUpdates;
@synthesize updateCheckInterval;

+ (SUUpdater *)sharedUpdater
{
	static SUUpdater *sharedUpdater = nil;
	if (!sharedUpdater) {
		sharedUpdater = [[self alloc] init];
	}
	return sharedUpdater;
}

- (NSDate *)lastUpdateCheckDate
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDate *lastCheckDate = [defaults objectForKey:@"SULastCheckTime"];
	return [lastCheckDate isKindOfClass:[NSDate class]] ? lastCheckDate : nil;
}

- (IBAction)checkForUpdates:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSDate date] forKey:@"SULastCheckTime"];
}

- (void)dealloc
{
	[feedURL release], feedURL = nil;
	[super dealloc];
}

@end

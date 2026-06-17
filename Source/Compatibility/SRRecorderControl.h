#import <Cocoa/Cocoa.h>

typedef struct {
	NSUInteger flags;
	NSInteger code;
} KeyCombo;

@interface SRRecorderCell : NSActionCell
{
	KeyCombo keyCombo;
}
@property (nonatomic) KeyCombo keyCombo;
@property (nonatomic) NSInteger keyComboCode;
@property (nonatomic) NSUInteger keyComboFlags;
@end

@interface SRRecorderControl : NSControl
{
	id delegate;
	BOOL animates;
	KeyCombo keyCombo;
}
@property (nonatomic, assign) id delegate;
@property (nonatomic) BOOL animates;
@property (nonatomic) KeyCombo keyCombo;

- (NSUInteger)cocoaToCarbonFlags:(NSUInteger)cocoaFlags;
- (NSUInteger)carbonToCocoaFlags:(NSUInteger)carbonFlags;
@end

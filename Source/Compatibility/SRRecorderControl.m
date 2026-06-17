#import "SRRecorderControl.h"
#import <Carbon/Carbon.h>
#import <objc/runtime.h>

static NSString *CMStringForKeyCombo(KeyCombo combo)
{
	if (combo.code < 0 || combo.flags == 0) {
		return @"None";
	}
	
	NSMutableString *string = [NSMutableString string];
	if (combo.flags & NSCommandKeyMask) {
		[string appendString:@"Command-"];
	}
	if (combo.flags & NSAlternateKeyMask) {
		[string appendString:@"Option-"];
	}
	if (combo.flags & NSControlKeyMask) {
		[string appendString:@"Control-"];
	}
	if (combo.flags & NSShiftKeyMask) {
		[string appendString:@"Shift-"];
	}
	[string appendFormat:@"%ld", (long)combo.code];
	return string;
}

@implementation SRRecorderCell

@synthesize keyCombo;

- (id)init
{
	self = [super initTextCell:@""];
	if (self) {
		keyCombo.code = -1;
		keyCombo.flags = 0;
		[self setEditable:NO];
		[self setBordered:YES];
		[self setBezeled:YES];
	}
	return self;
}

- (NSInteger)keyComboCode
{
	return keyCombo.code;
}

- (void)setKeyComboCode:(NSInteger)code
{
	keyCombo.code = code;
	[self setStringValue:CMStringForKeyCombo(keyCombo)];
}

- (NSUInteger)keyComboFlags
{
	return keyCombo.flags;
}

- (void)setKeyComboFlags:(NSUInteger)flags
{
	keyCombo.flags = flags;
	[self setStringValue:CMStringForKeyCombo(keyCombo)];
}

- (void)setKeyCombo:(KeyCombo)newKeyCombo
{
	keyCombo = newKeyCombo;
	[self setStringValue:CMStringForKeyCombo(keyCombo)];
}

@end

@implementation NSControl (CMShortcutRecorderCompatibility)

- (KeyCombo)keyCombo
{
	NSValue *value = objc_getAssociatedObject(self, @selector(keyCombo));
	KeyCombo combo;
	combo.code = -1;
	combo.flags = 0;
	if (value) {
		[value getValue:&combo];
	}
	return combo;
}

- (void)setKeyCombo:(KeyCombo)newKeyCombo
{
	NSValue *value = [NSValue valueWithBytes:&newKeyCombo objCType:@encode(KeyCombo)];
	objc_setAssociatedObject(self, @selector(keyCombo), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if ([self respondsToSelector:@selector(setStringValue:)]) {
		[(id)self setStringValue:CMStringForKeyCombo(newKeyCombo)];
	}
	else if ([[self cell] respondsToSelector:@selector(setStringValue:)]) {
		[[self cell] setStringValue:CMStringForKeyCombo(newKeyCombo)];
	}
}

- (void)setAnimates:(BOOL)flag
{
	objc_setAssociatedObject(self, @selector(animates), [NSNumber numberWithBool:flag], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)animates
{
	return [objc_getAssociatedObject(self, @selector(animates)) boolValue];
}

- (NSUInteger)cocoaToCarbonFlags:(NSUInteger)cocoaFlags
{
	NSUInteger carbonFlags = 0;
	if (cocoaFlags & NSCommandKeyMask) {
		carbonFlags |= cmdKey;
	}
	if (cocoaFlags & NSAlternateKeyMask) {
		carbonFlags |= optionKey;
	}
	if (cocoaFlags & NSControlKeyMask) {
		carbonFlags |= controlKey;
	}
	if (cocoaFlags & NSShiftKeyMask) {
		carbonFlags |= shiftKey;
	}
	return carbonFlags;
}

- (NSUInteger)carbonToCocoaFlags:(NSUInteger)carbonFlags
{
	NSUInteger cocoaFlags = 0;
	if (carbonFlags & cmdKey) {
		cocoaFlags |= NSCommandKeyMask;
	}
	if (carbonFlags & optionKey) {
		cocoaFlags |= NSAlternateKeyMask;
	}
	if (carbonFlags & controlKey) {
		cocoaFlags |= NSControlKeyMask;
	}
	if (carbonFlags & shiftKey) {
		cocoaFlags |= NSShiftKeyMask;
	}
	return cocoaFlags;
}

@end

@implementation SRRecorderControl

@synthesize delegate;
@synthesize animates;

+ (Class)cellClass
{
	return [SRRecorderCell class];
}

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		keyCombo.code = -1;
		keyCombo.flags = 0;
		[self setCell:[[[SRRecorderCell alloc] init] autorelease]];
	}
	return self;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	if ([[self cell] respondsToSelector:@selector(keyCombo)]) {
		keyCombo = [(SRRecorderCell *)[self cell] keyCombo];
	}
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}

- (BOOL)resignFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}

- (KeyCombo)keyCombo
{
	return keyCombo;
}

- (void)setKeyCombo:(KeyCombo)newKeyCombo
{
	keyCombo = newKeyCombo;
	if ([[self cell] respondsToSelector:@selector(setKeyCombo:)]) {
		[(SRRecorderCell *)[self cell] setKeyCombo:keyCombo];
	}
	[self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event
{
	[[self window] makeFirstResponder:self];
}

- (void)keyDown:(NSEvent *)event
{
	KeyCombo newKeyCombo;
	newKeyCombo.code = [event keyCode];
	newKeyCombo.flags = [event modifierFlags] & (NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSShiftKeyMask);
	[self setKeyCombo:newKeyCombo];
	
	if ([delegate respondsToSelector:@selector(shortcutRecorder:keyComboDidChange:)]) {
		[delegate shortcutRecorder:self keyComboDidChange:newKeyCombo];
	}
}

- (NSUInteger)cocoaToCarbonFlags:(NSUInteger)cocoaFlags
{
	NSUInteger carbonFlags = 0;
	if (cocoaFlags & NSCommandKeyMask) {
		carbonFlags |= cmdKey;
	}
	if (cocoaFlags & NSAlternateKeyMask) {
		carbonFlags |= optionKey;
	}
	if (cocoaFlags & NSControlKeyMask) {
		carbonFlags |= controlKey;
	}
	if (cocoaFlags & NSShiftKeyMask) {
		carbonFlags |= shiftKey;
	}
	return carbonFlags;
}

- (NSUInteger)carbonToCocoaFlags:(NSUInteger)carbonFlags
{
	NSUInteger cocoaFlags = 0;
	if (carbonFlags & cmdKey) {
		cocoaFlags |= NSCommandKeyMask;
	}
	if (carbonFlags & optionKey) {
		cocoaFlags |= NSAlternateKeyMask;
	}
	if (carbonFlags & controlKey) {
		cocoaFlags |= NSControlKeyMask;
	}
	if (carbonFlags & shiftKey) {
		cocoaFlags |= NSShiftKeyMask;
	}
	return cocoaFlags;
}

@end

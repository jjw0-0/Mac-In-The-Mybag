#import "CVirtualDisplay.h"

// Private CoreGraphics interfaces (verified via ObjC runtime introspection on
// current macOS). Declared here only so the compiler knows the selectors; the
// classes themselves are resolved at runtime via NSClassFromString, so there is
// no link-time dependency on private symbols.

@interface CGVirtualDisplayDescriptor : NSObject
@property (nonatomic, retain) dispatch_queue_t queue;
@property (nonatomic, copy) void (^terminationHandler)(void);
@property (nonatomic, assign) NSUInteger maxPixelsWide;
@property (nonatomic, assign) NSUInteger maxPixelsHigh;
@property (nonatomic, assign) CGSize sizeInMillimeters;
@property (nonatomic, assign) NSUInteger productID;
@property (nonatomic, assign) NSUInteger vendorID;
@property (nonatomic, assign) NSUInteger serialNum;
@property (nonatomic, copy) NSString *name;
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (nonatomic, assign) NSUInteger hiDPI;
@property (nonatomic, retain) NSArray<CGVirtualDisplayMode *> *modes;
@end

@interface CGVirtualDisplay : NSObject
@property (nonatomic, readonly) CGDirectDisplayID displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

// Strong references keep each virtual display alive until it is released.
static NSMutableDictionary<NSNumber *, CGVirtualDisplay *> *ActiveDisplays(void) {
    static NSMutableDictionary *displays = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ displays = [NSMutableDictionary dictionary]; });
    return displays;
}

CGDirectDisplayID CVirtualDisplayCreate(const char *name, NSUInteger width, NSUInteger height, double refreshRate) {
    Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class modeClass       = NSClassFromString(@"CGVirtualDisplayMode");
    Class settingsClass   = NSClassFromString(@"CGVirtualDisplaySettings");
    Class displayClass    = NSClassFromString(@"CGVirtualDisplay");
    if (!descriptorClass || !modeClass || !settingsClass || !displayClass) {
        return 0; // private interface unavailable on this OS
    }

    CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
    descriptor.name              = name ? [NSString stringWithUTF8String:name] : @"Mac-In-The-Myphone";
    descriptor.maxPixelsWide     = width;
    descriptor.maxPixelsHigh     = height;
    descriptor.sizeInMillimeters = CGSizeMake(527, 296); // ~24" equivalent
    descriptor.productID         = 0x1a2b;
    descriptor.vendorID          = 0x3c4d;
    descriptor.serialNum         = 0x0001;
    descriptor.queue             = dispatch_get_main_queue();
    descriptor.terminationHandler = ^{};

    CGVirtualDisplay *display = [[displayClass alloc] initWithDescriptor:descriptor];
    if (!display) return 0;

    CGVirtualDisplayMode *mode = [[modeClass alloc] initWithWidth:width height:height refreshRate:refreshRate];
    CGVirtualDisplaySettings *settings = [[settingsClass alloc] init];
    settings.hiDPI = 0;
    settings.modes = @[mode];
    if (![display applySettings:settings]) return 0;

    CGDirectDisplayID displayID = display.displayID;
    ActiveDisplays()[@(displayID)] = display;
    return displayID;
}

BOOL CVirtualDisplayRelease(CGDirectDisplayID displayID) {
    NSMutableDictionary *displays = ActiveDisplays();
    if (displays[@(displayID)] == nil) return NO;
    [displays removeObjectForKey:@(displayID)];
    return YES;
}

void CVirtualDisplayReleaseAll(void) {
    [ActiveDisplays() removeAllObjects];
}

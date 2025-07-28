//
//  MouseSideButtonsHelper.m
//  Mouse Buttons Helper
//
//  Based on SensibleSideButtons by Alexei Baboulevitch
//

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

// From TouchEvents.h
typedef uint32_t TLInfoSwipeDirection;
enum {
    kTLInfoSwipeUp = 1,
    kTLInfoSwipeDown = 2,
    kTLInfoSwipeLeft = 4,
    kTLInfoSwipeRight = 8
};

// Function declarations from TouchEvents
extern CGEventRef tl_CGEventCreateFromGesture(CFDictionaryRef gesture, CFArrayRef touches);
extern const CFStringRef kTLInfoKeyGestureSubtype;
extern const CFStringRef kTLInfoKeyGesturePhase;
extern const CFStringRef kTLInfoKeySwipeDirection;

#define kTLInfoSubtypeSwipe 0x10
#define PREFS_DOMAIN @"Wowfunhappy.sidebuttons.prefpane"

@interface MouseSideButtonsHelper : NSObject

@property (nonatomic, assign) CFMachPortRef eventTap;
@property (nonatomic, assign) NSInteger backButton;
@property (nonatomic, assign) NSInteger forwardButton;
@property (nonatomic, assign) NSInteger passthroughButton;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSTimer *restartTimer;

- (void)start;
- (void)stop;
- (void)loadPreferences;
- (void)preferencesChanged:(NSNotification *)notification;
- (void)scheduleRestart;

@end

static NSMutableDictionary* swipeInfo = nil;
static NSArray* nullArray = nil;
static MouseSideButtonsHelper *helperInstance = nil;

static void SBFFakeSwipe(TLInfoSwipeDirection dir) {
    if (!swipeInfo || !nullArray) return;
    
    CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][0]), (__bridge CFArrayRef)nullArray);
    CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][1]), (__bridge CFArrayRef)nullArray);
    
    if (event1 && event2) {
        CGEventPost(kCGHIDEventTap, event1);
        CGEventPost(kCGHIDEventTap, event2);
        
        CFRelease(event1);
        CFRelease(event2);
    }
}

static NSString* RunExtraScript(NSString *scriptName) {
    // Look for script in preference pane resources - check both user and system locations
    NSArray *searchPaths = @[
        [@"~/Library/PreferencePanes/MouseButtons.prefPane" stringByExpandingTildeInPath],
        @"/Library/PreferencePanes/MouseButtons.prefPane"
    ];
    
    NSString *scriptPath = nil;
    for (NSString *prefPanePath in searchPaths) {
        NSString *candidatePath = [prefPanePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Contents/Resources/Scripts/%@", scriptName]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:candidatePath]) {
            scriptPath = candidatePath;
            break;
        }
    }
    
    if (scriptPath) {
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:scriptPath];
        
        // Create pipe to capture output
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        
        @try {
            [task launch];
            [task waitUntilExit];
            
            // Read output from the pipe
            NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            // Trim whitespace and newlines
            output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            return output;
        }
        @catch (NSException *exception) {
            NSLog(@"MouseSideButtonsHelper: Failed to run script: %@", exception);
        }
    }
    
    return nil;
}

static CGEventRef MouseEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MouseSideButtonsHelper *helper = (__bridge MouseSideButtonsHelper *)refcon;
    
    if (!helper.enabled) {
        return event;
    }
    
    int64_t buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    BOOL isButtonDown = (type == kCGEventOtherMouseDown || type == kCGEventRightMouseDown);
    
    // For right mouse button events, the button number is always 1
    if (type == kCGEventRightMouseDown || type == kCGEventRightMouseUp) {
        buttonNumber = 1;
    }
    
    // Check if passthrough button is held
    BOOL passthroughActive = NO;
    if (helper.passthroughButton > 0) {
        NSUInteger mouseButtonMask = [NSEvent pressedMouseButtons];
        passthroughActive = (mouseButtonMask & (1 << helper.passthroughButton)) != 0;
    }
    
    if (passthroughActive) {
        return event; // Let original button functions work
    }
    
    // Handle back button
    if (buttonNumber == helper.backButton && helper.backButton > 0) {
        if (isButtonDown) {
            // Run extra script first and check if it returns "complete"
            NSString *scriptResult = RunExtraScript(@"back-extra-script");
            
            // Only skip the swipe if script explicitly returned "complete"
            if (scriptResult == nil || ![scriptResult isEqualToString:@"complete"]) {
                SBFFakeSwipe(kTLInfoSwipeLeft);
            }
        }
        return NULL; // Consume the event
    }
    
    // Handle forward button
    if (buttonNumber == helper.forwardButton && helper.forwardButton > 0) {
        if (isButtonDown) {
            // Run extra script first and check if it returns "complete"
            NSString *scriptResult = RunExtraScript(@"forward-extra-script");
            
            // Only skip the swipe if script explicitly returned "complete"
            if (scriptResult == nil || ![scriptResult isEqualToString:@"complete"]) {
                SBFFakeSwipe(kTLInfoSwipeRight);
            }
        }
        return NULL; // Consume the event
    }
    
    return event;
}

@implementation MouseSideButtonsHelper

- (id)init {
    self = [super init];
    if (self) {
        self.eventTap = NULL;
        [self setupSwipeInfo];
        [self loadPreferences];
        
        // Listen for preference changes
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(preferencesChanged:)
                                                                name:@"Wowfunhappy.sidebuttons.prefsChanged"
                                                              object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [self.restartTimer invalidate];
    [self stop];
}

- (void)setupSwipeInfo {
    swipeInfo = [NSMutableDictionary dictionary];
    
    for (NSNumber* direction in @[@(kTLInfoSwipeUp), @(kTLInfoSwipeDown), @(kTLInfoSwipeLeft), @(kTLInfoSwipeRight)]) {
        NSDictionary* swipeInfo1 = @{
            (__bridge NSString*)kTLInfoKeyGestureSubtype: @(kTLInfoSubtypeSwipe),
            (__bridge NSString*)kTLInfoKeyGesturePhase: @(1)
        };
        
        NSDictionary* swipeInfo2 = @{
            (__bridge NSString*)kTLInfoKeyGestureSubtype: @(kTLInfoSubtypeSwipe),
            (__bridge NSString*)kTLInfoKeySwipeDirection: direction,
            (__bridge NSString*)kTLInfoKeyGesturePhase: @(4)
        };
        
        swipeInfo[direction] = @[swipeInfo1, swipeInfo2];
    }
    
    nullArray = @[];
}

- (void)loadPreferences {
    // Use CFPreferences to read from the correct domain
    CFPropertyListRef enabledValue = CFPreferencesCopyValue(CFSTR("Enabled"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPropertyListRef backButtonValue = CFPreferencesCopyValue(CFSTR("BackButton"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPropertyListRef forwardButtonValue = CFPreferencesCopyValue(CFSTR("ForwardButton"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPropertyListRef passthroughButtonValue = CFPreferencesCopyValue(CFSTR("PassthroughButton"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    
    self.enabled = enabledValue ? [(NSNumber *)CFBridgingRelease(enabledValue) boolValue] : NO;
    self.backButton = backButtonValue ? [(NSNumber *)CFBridgingRelease(backButtonValue) integerValue] : 0;
    self.forwardButton = forwardButtonValue ? [(NSNumber *)CFBridgingRelease(forwardButtonValue) integerValue] : 0;
    self.passthroughButton = passthroughButtonValue ? [(NSNumber *)CFBridgingRelease(passthroughButtonValue) integerValue] : 2;
    
    
    // Only set default for passthrough button
    if (self.passthroughButton == 0) self.passthroughButton = 2;
    
}

- (void)preferencesChanged:(NSNotification *)notification {
    [self loadPreferences];
}

- (void)start {
    if (self.eventTap != NULL) {
        return; // Already running
    }
    
    // Create event tap - include right mouse button events
    CGEventMask eventMask = CGEventMaskBit(kCGEventOtherMouseUp) | 
                           CGEventMaskBit(kCGEventOtherMouseDown) |
                           CGEventMaskBit(kCGEventRightMouseUp) |
                           CGEventMaskBit(kCGEventRightMouseDown);
    
    self.eventTap = CGEventTapCreate(kCGHIDEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                eventMask,
                                &MouseEventCallback,
                                (__bridge void *)self);
    
    if (self.eventTap == NULL) {
        return;
    }
    
    // Add to run loop
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(NULL, self.eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    
    CGEventTapEnable(self.eventTap, true);
    
    // Schedule restart timer
    [self scheduleRestart];
}

- (void)stop {
    if (self.eventTap != NULL) {
        CGEventTapEnable(self.eventTap, false);
        CFRelease(self.eventTap);
        self.eventTap = NULL;
    }
}

- (void)scheduleRestart {
    // Cancel existing timer if any
    [self.restartTimer invalidate];
    
    // Schedule restart in 30 minutes
    self.restartTimer = [NSTimer scheduledTimerWithTimeInterval:1800.0 // 30 minutes
                                                          target:self
                                                        selector:@selector(performRestart)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)performRestart {
    
    // Exit with a special code that indicates a restart is needed
    // The launch agent should be configured to restart on this exit code
    exit(42);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        helperInstance = [[MouseSideButtonsHelper alloc] init];
        
        // Check for accessibility permissions - this will prompt and add us to the list
        NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
        BOOL accessEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
        
        if (!accessEnabled) {
            
            // If we're not configured to do anything, just exit after showing the dialog
            CFPropertyListRef enabledValue = CFPreferencesCopyValue(CFSTR("Enabled"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
            BOOL enabled = enabledValue ? [(NSNumber *)CFBridgingRelease(enabledValue) boolValue] : NO;
            
            if (!enabled) {
                // Give the dialog time to show
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    exit(0);
                });
            } else {
                // Keep running and wait for permission
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    while (!AXIsProcessTrusted()) {
                        sleep(1);
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [helperInstance start];
                    });
                });
            }
        } else {
            
            // Check if we should be running
            [helperInstance loadPreferences];
            if (helperInstance.enabled) {
                [helperInstance start];
            } else {
                exit(0);
            }
        }
        
        // Run the run loop
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
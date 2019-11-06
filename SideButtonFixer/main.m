//
//  main.m
//
// SensibleSideButtons, a utility that fixes the navigation buttons on third-party mice in macOS
// Copyright (C) 2018 Alexei Baboulevitch (ssb@archagon.net)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

#import "main.h"
#import "TouchEvents.h"
#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

static NSMutableDictionary<NSNumber*, NSArray<NSDictionary*>*>* swipeInfo = nil;
static NSArray* nullArray = nil;

static void SBFFakeSwipe(TLInfoSwipeDirection dir) {
    CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][0]), (__bridge CFArrayRef)nullArray);
    CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][1]), (__bridge CFArrayRef)nullArray);
    
    CGEventPost(kCGHIDEventTap, event1);
    CGEventPost(kCGHIDEventTap, event2);
    
    CFRelease(event1);
    CFRelease(event2);
}

static CGEventRef SBFMouseCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    int64_t number = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    BOOL down = (CGEventGetType(event) == kCGEventOtherMouseDown);
    
    NSUInteger mouseButtonMask = [NSEvent pressedMouseButtons];
    BOOL middleButtonDown = (mouseButtonMask & (1 << 2)) != 0;
    
    if (number == 3 && !middleButtonDown) {
        if (down) {
            SBFFakeSwipe(kTLInfoSwipeLeft);
        }
        
        return NULL;
    }
    else if (number == 4 && !middleButtonDown) {
        if (down) {
            SBFFakeSwipe(kTLInfoSwipeRight);
        }
        
        return NULL;
    }
    else {
        return event;
    }
}

@interface AppDelegate ()
@property (nonatomic, assign) CFMachPortRef tap;
@end

@implementation AppDelegate

-(void) dealloc {
    [self startTap:NO];
    
    swipeInfo = nil;
    nullArray = nil;
}

-(void) applicationDidFinishLaunching:(NSNotification *)aNotification {
    // setup globals
    {
        swipeInfo = [NSMutableDictionary dictionary];

        for (NSNumber* direction in @[ @(kTLInfoSwipeUp), @(kTLInfoSwipeDown), @(kTLInfoSwipeLeft), @(kTLInfoSwipeRight) ]) {
            NSDictionary* swipeInfo1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                        @(1), kTLInfoKeyGesturePhase,
                                        nil];

            NSDictionary* swipeInfo2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                        direction, kTLInfoKeySwipeDirection,
                                        @(4), kTLInfoKeyGesturePhase,
                                        nil];

            swipeInfo[direction] = @[ swipeInfo1, swipeInfo2 ];
        }

        nullArray = @[];
    }

    [self startTap:true];

}

-(void) startTap:(BOOL)start {
    if (start) {
        if (self.tap == NULL) {
            self.tap = CGEventTapCreate(kCGHIDEventTap,
                                        kCGHeadInsertEventTap,
                                        kCGEventTapOptionDefault,
                                        CGEventMaskBit(kCGEventOtherMouseUp)|CGEventMaskBit(kCGEventOtherMouseDown),
                                        &SBFMouseCallback,
                                        NULL);
            
            if (self.tap != NULL) {
                CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(NULL, self.tap, 0);
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
                CFRelease(runLoopSource);
                
                CGEventTapEnable(self.tap, true);
            }
        }
    }
    else {
        if (self.tap != NULL) {
            CGEventTapEnable(self.tap, NO);
            CFRelease(self.tap);
            
            self.tap = NULL;
        }
    }
}

@end

//
//  MouseSideButtonsPane.m
//  Mouse Buttons Preference Pane
//
//  Based on SensibleSideButtons by Alexei Baboulevitch
//

#import "MouseSideButtonsPane.h"

#define HELPER_BUNDLE_ID @"Wowfunhappy.sidebuttons.helper"
#define PREFS_DOMAIN @"Wowfunhappy.sidebuttons.prefpane"

@implementation MouseSideButtonsPane

- (NSView *)loadMainView {
    // Create the main view - much shorter height
    NSView *mainView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 668, 180)];
    [self setMainView:mainView];
    
    [self setupUI];
    
    return mainView;
}

- (void)setupUI {
    NSView *mainView = [self mainView];
    
    // Compact layout starting from top
    NSInteger yPosition = 140;
    NSInteger leftMargin = 165;
    NSInteger labelWidth = 100;
    NSInteger popupWidth = 185;
    NSInteger lineHeight = 26;
    
    // Back button mapping
    NSTextField *backLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(leftMargin - labelWidth - 10, yPosition, labelWidth, 20)];
    [backLabel setStringValue:@"Back:"];
    [backLabel setBezeled:NO];
    [backLabel setDrawsBackground:NO];
    [backLabel setEditable:NO];
    [backLabel setSelectable:NO];
    [backLabel setAlignment:NSRightTextAlignment];
    [mainView addSubview:backLabel];
    
    backButtonPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(leftMargin, yPosition - 2, popupWidth, 25) pullsDown:NO];
    [self populateButtonMenu:backButtonPopup];
    [backButtonPopup setTarget:self];
    [backButtonPopup setAction:@selector(dropdownClicked:)];
    [backButtonPopup setTag:1];
    [mainView addSubview:backButtonPopup];
    
    yPosition -= lineHeight;
    
    // Forward button mapping
    NSTextField *forwardLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(leftMargin - labelWidth - 10, yPosition, labelWidth, 20)];
    [forwardLabel setStringValue:@"Forward:"];
    [forwardLabel setBezeled:NO];
    [forwardLabel setDrawsBackground:NO];
    [forwardLabel setEditable:NO];
    [forwardLabel setSelectable:NO];
    [forwardLabel setAlignment:NSRightTextAlignment];
    [mainView addSubview:forwardLabel];
    
    forwardButtonPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(leftMargin, yPosition - 2, popupWidth, 25) pullsDown:NO];
    [self populateButtonMenu:forwardButtonPopup];
    [forwardButtonPopup setTarget:self];
    [forwardButtonPopup setAction:@selector(dropdownClicked:)];
    [forwardButtonPopup setTag:2];
    [mainView addSubview:forwardButtonPopup];
    
    yPosition -= lineHeight;
    
    // Passthrough button mapping
    NSTextField *passthroughLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(leftMargin - labelWidth - 10, yPosition, labelWidth, 20)];
    [passthroughLabel setStringValue:@"Passthrough:"];
    [passthroughLabel setBezeled:NO];
    [passthroughLabel setDrawsBackground:NO];
    [passthroughLabel setEditable:NO];
    [passthroughLabel setSelectable:NO];
    [passthroughLabel setAlignment:NSRightTextAlignment];
    [mainView addSubview:passthroughLabel];
    
    passthroughButtonPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(leftMargin, yPosition - 2, popupWidth, 25) pullsDown:NO];
    [self populateButtonMenu:passthroughButtonPopup];
    [passthroughButtonPopup setTarget:self];
    [passthroughButtonPopup setAction:@selector(dropdownClicked:)];
    [passthroughButtonPopup setTag:3];
    [mainView addSubview:passthroughButtonPopup];
    
    yPosition -= lineHeight + 10;
    
    // Passthrough explanation - use full width
    passthroughExplanation = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 628, 30)];
    [passthroughExplanation setStringValue:@"While the passthrough button is held down, other mouse buttons will perform their original functions."];
    [passthroughExplanation setBezeled:NO];
    [passthroughExplanation setDrawsBackground:NO];
    [passthroughExplanation setEditable:NO];
    [passthroughExplanation setSelectable:NO];
    [passthroughExplanation setFont:[NSFont systemFontOfSize:11]];
    [passthroughExplanation setTextColor:[NSColor disabledControlTextColor]];
    [[passthroughExplanation cell] setWraps:YES];
    [mainView addSubview:passthroughExplanation];
    
    // Load preferences
    [self loadPreferences];
}

- (void)populateButtonMenu:(NSPopUpButton *)popup {
    [popup removeAllItems];
    [popup addItemWithTitle:@"-"];
    [[popup lastItem] setTag:0];
    
    // Add separator after "None" option
    [[popup menu] addItem:[NSMenuItem separatorItem]];
    
    // Add secondary mouse button (right-click)
    [popup addItemWithTitle:@"Secondary Mouse Button"];
    [[popup lastItem] setTag:1];
    
    // Mouse buttons in macOS: 0=left, 1=right, 2=middle, 3=button4, 4=button5, etc.
    // Show Button 3 (index 2) through Button 16 (index 15)
    for (int i = 2; i <= 15; i++) {
        [popup addItemWithTitle:[NSString stringWithFormat:@"Button %d", i + 1]];
        [[popup lastItem] setTag:i];
    }
}

- (void)loadPreferences {
    // Use CFPreferences to read from the correct domain
    CFPropertyListRef backButtonValue = CFPreferencesCopyValue(CFSTR("BackButton"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPropertyListRef forwardButtonValue = CFPreferencesCopyValue(CFSTR("ForwardButton"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPropertyListRef passthroughButtonValue = CFPreferencesCopyValue(CFSTR("PassthroughButton"), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    
    NSInteger backButton = backButtonValue ? [(NSNumber *)CFBridgingRelease(backButtonValue) integerValue] : 0;
    NSInteger forwardButton = forwardButtonValue ? [(NSNumber *)CFBridgingRelease(forwardButtonValue) integerValue] : 0;
    NSInteger passthroughButton = passthroughButtonValue ? [(NSNumber *)CFBridgingRelease(passthroughButtonValue) integerValue] : 2;
    
    [backButtonPopup selectItemWithTag:backButton];
    [forwardButtonPopup selectItemWithTag:forwardButton];
    [passthroughButtonPopup selectItemWithTag:passthroughButton];
}

- (void)savePreferences {
    NSInteger backButton = [[backButtonPopup selectedItem] tag];
    NSInteger forwardButton = [[forwardButtonPopup selectedItem] tag];
    NSInteger passthroughButton = [[passthroughButtonPopup selectedItem] tag];
    
    // Enable if either back or forward is set to something other than None
    BOOL enabled = (backButton != 0 || forwardButton != 0);
    
    NSLog(@"MouseSideButtons: Saving preferences - Enabled: %d, Back: %ld, Forward: %ld", enabled, (long)backButton, (long)forwardButton);
    
    // Use CFPreferences to write to the correct domain
    CFPreferencesSetValue(CFSTR("Enabled"), (__bridge CFPropertyListRef)@(enabled), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSetValue(CFSTR("BackButton"), (__bridge CFPropertyListRef)@(backButton), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSetValue(CFSTR("ForwardButton"), (__bridge CFPropertyListRef)@(forwardButton), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSetValue(CFSTR("PassthroughButton"), (__bridge CFPropertyListRef)@(passthroughButton), CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    
    // Force synchronization
    CFPreferencesSynchronize(CFSTR("Wowfunhappy.sidebuttons.prefpane"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    
    // Start or stop helper based on enabled state
    if (enabled) {
        [self startHelper];
    } else {
        [self stopHelper];
    }
    
    // Notify helper of changes
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"Wowfunhappy.sidebuttons.prefsChanged"
                                                                   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}


- (void)dropdownClicked:(id)sender {
    [self buttonMappingChanged:sender];
}

- (void)buttonMappingChanged:(id)sender {
    NSLog(@"MouseSideButtons: Button mapping changed");
    
    // Check for conflicts
    NSInteger backTag = [[backButtonPopup selectedItem] tag];
    NSInteger forwardTag = [[forwardButtonPopup selectedItem] tag];
    NSInteger passthroughTag = [[passthroughButtonPopup selectedItem] tag];
    
    // Ensure no duplicate assignments (except for "None")
    if (backTag != 0 && (backTag == forwardTag || backTag == passthroughTag)) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Button Conflict"];
        [alert setInformativeText:@"Each mouse button can only be assigned to one function."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        // Revert the change
        [self loadPreferences];
        return;
    }
    
    if (forwardTag != 0 && (forwardTag == backTag || forwardTag == passthroughTag)) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Button Conflict"];
        [alert setInformativeText:@"Each mouse button can only be assigned to one function."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        // Revert the change
        [self loadPreferences];
        return;
    }
    
    if (passthroughTag != 0 && (passthroughTag == backTag || passthroughTag == forwardTag)) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Button Conflict"];
        [alert setInformativeText:@"Each mouse button can only be assigned to one function."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        // Revert the change
        [self loadPreferences];
        return;
    }
    
    [self savePreferences];
    
}

- (NSString *)findHelperPath {
    // Look for the helper in both user and system preference pane locations
    NSArray *searchPaths = @[
        [@"~/Library/PreferencePanes/MouseButtons.prefPane/Contents/MacOS/Mouse Buttons.app/Contents/MacOS/MouseSideButtonsHelper" stringByExpandingTildeInPath],
        @"/Library/PreferencePanes/MouseButtons.prefPane/Contents/MacOS/Mouse Buttons.app/Contents/MacOS/MouseSideButtonsHelper"
    ];
    
    for (NSString *path in searchPaths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return path;
        }
    }
    
    NSLog(@"MouseSideButtons: Warning - Could not find helper binary");
    return nil;
}

- (void)ensureLaunchAgentPlist {
    NSString *helperPath = [self findHelperPath];
    if (!helperPath) return;
    
    // Create LaunchAgents directory if needed
    NSString *launchAgentsDir = [@"~/Library/LaunchAgents" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:launchAgentsDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    // Create the plist
    NSDictionary *plistDict = @{
        @"Label": @"Wowfunhappy.sidebuttons.helper",
        @"ProgramArguments": @[helperPath],
        @"RunAtLoad": @YES,
        @"KeepAlive": @YES,
        @"StandardOutPath": @"/tmp/Wowfunhappy.sidebuttons.helper.log",
        @"StandardErrorPath": @"/tmp/Wowfunhappy.sidebuttons.helper.error.log"
    };
    
    NSString *plistPath = [@"~/Library/LaunchAgents/Wowfunhappy.sidebuttons.helper.plist" stringByExpandingTildeInPath];
    [plistDict writeToFile:plistPath atomically:YES];
}

- (void)startHelper {
    // Ensure the launch agent plist exists with the correct helper path
    [self ensureLaunchAgentPlist];
    
    // Start the helper using launchctl
    NSString *plistPath = [@"~/Library/LaunchAgents/Wowfunhappy.sidebuttons.helper.plist" stringByExpandingTildeInPath];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/launchctl"];
    [task setArguments:@[@"load", plistPath]];
    [task launch];
    [task waitUntilExit];
    
}

- (void)stopHelper {
    // Stop the helper using launchctl
    NSString *plistPath = [@"~/Library/LaunchAgents/Wowfunhappy.sidebuttons.helper.plist" stringByExpandingTildeInPath];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/launchctl"];
    [task setArguments:@[@"unload", plistPath]];
    [task launch];
    [task waitUntilExit];
}

- (void)willSelect {
    // Called when pane is about to be selected
    [self loadPreferences];
}

- (void)didSelect {
    // Called after pane has been selected
}

@end
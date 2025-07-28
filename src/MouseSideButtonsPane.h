//
//  MouseSideButtonsPane.h
//  Mouse Buttons Preference Pane
//
//  Based on SensibleSideButtons by Alexei Baboulevitch
//

#import <PreferencePanes/PreferencePanes.h>

@interface MouseSideButtonsPane : NSPreferencePane {
    NSPopUpButton *backButtonPopup;
    NSPopUpButton *forwardButtonPopup;
    NSPopUpButton *passthroughButtonPopup;
    NSTextField *passthroughExplanation;
}
- (void)buttonMappingChanged:(id)sender;
- (void)dropdownClicked:(id)sender;
- (void)startHelper;
- (void)stopHelper;

@end
//
//  iReSignAppDelegate.h
//  iReSign
//
//  Created by Maciej Swic on 2011-05-16.
//  Copyright (c) 2011 Maciej Swic, Licensed under the MIT License.
//  See README.md for details
//

#import <Cocoa/Cocoa.h>
#import "IRTextFieldDrag.h"

@interface iReSignAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *__unsafe_unretained window;
    
    NSUserDefaults *defaults;
    
    NSTask *unzipTask;
    NSTask *copyTask;
    NSTask *provisioningTask;
    NSTask *generateEntitlementsTask;
    
    NSTask *zipTask;
    NSString *sourcePath;
    
    NSString *workingPath;
    NSString *appName;
    NSString *fileName;
    
    
    IBOutlet IRTextFieldDrag *pathField;
    IBOutlet IRTextFieldDrag *provisioningPathField;
    
    IBOutlet IRTextFieldDrag *watchAppProvisioningPathField;
    IBOutlet IRTextFieldDrag *watchExtensionProvisioningPathField;
    
    IBOutlet IRTextFieldDrag *entitlementField;
    IBOutlet IRTextFieldDrag *watchAppEntitlementField;
    IBOutlet IRTextFieldDrag *watchExtensionEntitlementField;
    
    
    IBOutlet IRTextFieldDrag *bundleIDField;
    IBOutlet NSButton    *browseButton;
    IBOutlet NSButton    *provisioningBrowseButton;
    
    IBOutlet NSButton    *watchAppProvisioningBrowseButton;
    IBOutlet NSButton    *watchExtensionProvisioningBrowseButton;
    
    IBOutlet NSButton *entitlementBrowseButton;
    
    IBOutlet NSButton *watchEntitlementBrowseButton;
    IBOutlet NSButton *watchExtensionEntitlementBrowseButton;
    
    IBOutlet NSButton    *resignButton;
    
    IBOutlet NSTextField *statusLabel;
    IBOutlet NSProgressIndicator *flurry;
    IBOutlet NSButton *changeBundleIDCheckbox;
    
    IBOutlet NSComboBox *certComboBox;
    NSMutableArray *certComboBoxItems;
    NSTask *certTask;
    NSArray *getCertsResult;
    
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@property (nonatomic, strong) NSString *workingPath;

- (IBAction)resign:(id)sender;
- (IBAction)browse:(id)sender;
- (IBAction)provisioningBrowse:(id)sender;

- (IBAction)watchAppProvisioningBrowse:(id)sender;
- (IBAction)watchExtensionProvisioningBrowse:(id)sender;

- (IBAction)entitlementBrowse:(id)sender;
- (IBAction)changeBundleIDPressed:(id)sender;

- (void)checkUnzip:(NSTimer *)timer;
- (void)checkCopy:(NSTimer *)timer;
- (void)doProvisioning;
- (void)checkProvisioning:(NSTimer *)timer;
- (void)doCodeSigning;

- (void)doZip;
- (void)checkZip:(NSTimer *)timer;
- (void)disableControls;
- (void)enableControls;

@end

//
//  iReSignAppDelegate.m
//  iReSign
//
//  Created by Maciej Swic on 2011-05-16.
//  Copyright (c) 2011 Maciej Swic, Licensed under the MIT License.
//  See README.md for details
//

#import "iReSignAppDelegate.h"
#import "iReSignAndVerify.h"

static NSString *kKeyPrefsBundleIDChange            = @"keyBundleIDChange";

static NSString *kKeyBundleIDPlistApp               = @"CFBundleIdentifier";

static NSString *kKeyWKCompanionAppBundleId         = @"WKCompanionAppBundleIdentifier";
static NSString *kKeyWKAppBundleId                  = @"NSExtension:NSExtensionAttributes:WKAppBundleIdentifier";

static NSString *kKeyBundleIDPlistiTunesArtwork     = @"softwareVersionBundleId";
static NSString *kKeyInfoPlistApplicationProperties = @"ApplicationProperties";
static NSString *kKeyInfoPlistApplicationPath       = @"ApplicationPath";
static NSString *kFrameworksDirName                 = @"Frameworks";
static NSString *kPayloadDirName                    = @"Payload";
static NSString *kProductsDirName                   = @"Products";
static NSString *kInfoPlistFilename                 = @"Info.plist";
static NSString *kiTunesMetadataFileName            = @"iTunesMetadata";

@interface iReSignAppDelegate(){
    iReSignAndVerify *signWatchExtensionObject;
    iReSignAndVerify *signWatchKitAppObject;
    iReSignAndVerify *signAppObject;
}

@end
@implementation iReSignAppDelegate

@synthesize window,workingPath;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [flurry setAlphaValue:0.5];
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    // Look up available signing certificates
    [self getCerts];
    
    if ([defaults valueForKey:@"ENTITLEMENT_PATH"])
        [entitlementField setStringValue:[defaults valueForKey:@"ENTITLEMENT_PATH"]];
    if ([defaults valueForKey:@"WATCH_ENTITLEMENT_PATH"])
        [watchAppEntitlementField setStringValue:[defaults valueForKey:@"WATCH_ENTITLEMENT_PATH"]];
    if ([defaults valueForKey:@"WATCH_EXTENSION_ENTITLEMENT_PATH"])
        [watchExtensionEntitlementField setStringValue:[defaults valueForKey:@"WATCH_EXTENSION_ENTITLEMENT_PATH"]];
    
    if ([defaults valueForKey:@"MOBILEPROVISION_PATH"])
        [provisioningPathField setStringValue:[defaults valueForKey:@"MOBILEPROVISION_PATH"]];
    
    if ([defaults valueForKey:@"WATCHKITAPP_MOBILEPROVISION_PATH"])
        [watchAppProvisioningPathField setStringValue:[defaults valueForKey:@"WATCHKITAPP_MOBILEPROVISION_PATH"]];
    if ([defaults valueForKey:@"WATCHKITEXTENSION_MOBILEPROVISION_PATH"])
        [watchExtensionProvisioningPathField setStringValue:[defaults valueForKey:@"WATCHKITEXTENSION_MOBILEPROVISION_PATH"]];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the zip utility present at /usr/bin/zip"];
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/unzip"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the unzip utility present at /usr/bin/unzip"];
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the codesign utility present at /usr/bin/codesign"];
        exit(0);
    }
}


- (IBAction)resign:(id)sender {
    //Save cert name
    [defaults setValue:[NSNumber numberWithInteger:[certComboBox indexOfSelectedItem]] forKey:@"CERT_INDEX"];
    [defaults setValue:[entitlementField stringValue] forKey:@"ENTITLEMENT_PATH"];
    [defaults setValue:[watchAppEntitlementField stringValue] forKey:@"WATCH_ENTITLEMENT_PATH"];
    [defaults setValue:[watchExtensionEntitlementField stringValue] forKey:@"WATCH_EXTENSION_ENTITLEMENT_PATH"];
    
    [defaults setValue:[provisioningPathField stringValue] forKey:@"MOBILEPROVISION_PATH"];
    
    if([watchAppProvisioningPathField stringValue].length > 0){
        [defaults setValue:[watchAppProvisioningPathField stringValue] forKey:@"WATCHKITAPP_MOBILEPROVISION_PATH"];
    }
    if([watchExtensionProvisioningPathField stringValue].length > 0){
        [defaults setValue:[watchExtensionProvisioningPathField stringValue] forKey:@"WATCHKITEXTENSION_MOBILEPROVISION_PATH"];
    }
    
    [defaults setValue:[bundleIDField stringValue] forKey:kKeyPrefsBundleIDChange];
    [defaults synchronize];
    
    sourcePath = [pathField stringValue];
    workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.appulize.iresign"];
    
    if ([certComboBox objectValue]) {
        if (([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) ||
            ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"xcarchive"])) {
            [self disableControls];
            
            NSLog(@"Setting up working directory in %@",workingPath);
            [statusLabel setHidden:NO];
            [statusLabel setStringValue:@"Setting up working directory"];
            
            [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
            
            [[NSFileManager defaultManager] createDirectoryAtPath:workingPath withIntermediateDirectories:TRUE attributes:nil error:nil];
            
            if ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
                if (sourcePath && [sourcePath length] > 0) {
                    NSLog(@"Unzipping %@",sourcePath);
                    [statusLabel setStringValue:@"Extracting original app"];
                }
                
                unzipTask = [[NSTask alloc] init];
                [unzipTask setLaunchPath:@"/usr/bin/unzip"];
                [unzipTask setArguments:[NSArray arrayWithObjects:@"-q", sourcePath, @"-d", workingPath, nil]];
                
                [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkUnzip:) userInfo:nil repeats:TRUE];
                
                [unzipTask launch];
            }
            else {
                NSString* payloadPath = [workingPath stringByAppendingPathComponent:kPayloadDirName];
                
                NSLog(@"Setting up %@ path in %@", kPayloadDirName, payloadPath);
                [statusLabel setStringValue:[NSString stringWithFormat:@"Setting up %@ path", kPayloadDirName]];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:payloadPath withIntermediateDirectories:TRUE attributes:nil error:nil];
                
                NSLog(@"Retrieving %@", kInfoPlistFilename);
                [statusLabel setStringValue:[NSString stringWithFormat:@"Retrieving %@", kInfoPlistFilename]];
                
                NSString* infoPListPath = [sourcePath stringByAppendingPathComponent:kInfoPlistFilename];
                
                NSDictionary* infoPListDict = [NSDictionary dictionaryWithContentsOfFile:infoPListPath];
                
                if (infoPListDict != nil) {
                    NSString* applicationPath = nil;
                    
                    NSDictionary* applicationPropertiesDict = [infoPListDict objectForKey:kKeyInfoPlistApplicationProperties];
                    
                    if (applicationPropertiesDict != nil) {
                        applicationPath = [applicationPropertiesDict objectForKey:kKeyInfoPlistApplicationPath];
                    }
                    
                    if (applicationPath != nil) {
                        applicationPath = [[sourcePath stringByAppendingPathComponent:kProductsDirName] stringByAppendingPathComponent:applicationPath];
                        
                        NSLog(@"Copying %@ to %@ path in %@", applicationPath, kPayloadDirName, payloadPath);
                        [statusLabel setStringValue:[NSString stringWithFormat:@"Copying .xcarchive app to %@ path", kPayloadDirName]];
                        
                        copyTask = [[NSTask alloc] init];
                        [copyTask setLaunchPath:@"/bin/cp"];
                        [copyTask setArguments:[NSArray arrayWithObjects:@"-r", applicationPath, payloadPath, nil]];
                        
                        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCopy:) userInfo:nil repeats:TRUE];
                        
                        [copyTask launch];
                    }
                    else {
                        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:[NSString stringWithFormat:@"Unable to parse %@", kInfoPlistFilename]];
                        [self enableControls];
                        [statusLabel setStringValue:@"Ready"];
                    }
                }
                else {
                    [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:[NSString stringWithFormat:@"Retrieve %@ failed", kInfoPlistFilename]];
                    [self enableControls];
                    [statusLabel setStringValue:@"Ready"];
                }
            }
        }
        else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"You must choose an *.ipa or *.xcarchive file"];
            [self enableControls];
            [statusLabel setStringValue:@"Please try again"];
        }
    } else {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"You must choose an signing certificate from dropdown."];
        [self enableControls];
        [statusLabel setStringValue:@"Please try again"];
    }
}

- (void)checkUnzip:(NSTimer *)timer {
    if ([unzipTask isRunning] == 0) {
        [timer invalidate];
        unzipTask = nil;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName]]) {
            NSLog(@"Unzipping done");
            [statusLabel setStringValue:@"Original app extracted"];
            
            if (changeBundleIDCheckbox.state == NSOnState) {
                [self doBundleIDChange:bundleIDField.stringValue];
            }
            
            if ([[provisioningPathField stringValue] isEqualTo:@""]) {
                [self doCodeSigning];
            } else {
                [self doProvisioning];
            }
        } else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Unzip failed"];
            [self enableControls];
            [statusLabel setStringValue:@"Ready"];
        }
    }
}

- (void)checkCopy:(NSTimer *)timer {
    if ([copyTask isRunning] == 0) {
        [timer invalidate];
        copyTask = nil;
        
        NSLog(@"Copy done");
        [statusLabel setStringValue:@".xcarchive app copied"];
        
        if (changeBundleIDCheckbox.state == NSOnState) {
            [self doBundleIDChange:bundleIDField.stringValue];
        }
        
        if ([[provisioningPathField stringValue] isEqualTo:@""]) {
            [self doCodeSigning];
        } else {
            [self doProvisioning];
        }
    }
}

- (BOOL)doBundleIDChange:(NSString *)newBundleID {
    BOOL success = YES;
    
    success &= [self doAppBundleIDChange:newBundleID];
    success &= [self doITunesMetadataBundleIDChange:newBundleID];
    
    return success;
}


- (BOOL)doITunesMetadataBundleIDChange:(NSString *)newBundleID {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workingPath error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"plist"]) {
            infoPlistPath = [workingPath stringByAppendingPathComponent:file];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistiTunesArtwork newBundleID:newBundleID plistOutOptions:NSPropertyListXMLFormat_v1_0];
    
}

- (BOOL)doAppBundleIDChange:(NSString *)newBundleID {
    
    NSString *infoPlistPath = [[self appFilePath] stringByAppendingPathComponent:kInfoPlistFilename];
    
    BOOL changeAppBundleId = [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistApp newBundleID:newBundleID plistOutOptions:NSPropertyListBinaryFormat_v1_0];
    if(!changeAppBundleId)
        return NO;
    
    if([self watchAppFilePath]){
        // change bundle id for watch app
        NSString *watchAppInfoPlistPath = [[self watchAppFilePath] stringByAppendingPathComponent:kInfoPlistFilename];
        NSString *watchAppBundleId = [newBundleID stringByAppendingString:@".watchkitapp"];
        
        BOOL changeAppBundleId = [self changeBundleIDForFile:watchAppInfoPlistPath bundleIDKey:kKeyBundleIDPlistApp newBundleID:watchAppBundleId plistOutOptions:NSPropertyListBinaryFormat_v1_0];
        if(changeAppBundleId){
            changeAppBundleId = [self changeBundleIDForFile:watchAppInfoPlistPath bundleIDKey:kKeyWKCompanionAppBundleId newBundleID:newBundleID plistOutOptions:NSPropertyListBinaryFormat_v1_0];
        }
        
        if(changeAppBundleId && [self watchExtensionFilePath]){
            NSString *watchExtensionInfoPlistPath = [[self watchExtensionFilePath] stringByAppendingPathComponent:kInfoPlistFilename];
            NSString *watchExtensionBundleId = [watchAppBundleId stringByAppendingString:@".watchkitextension"];
            
            changeAppBundleId = [self changeBundleIDForFile:watchExtensionInfoPlistPath bundleIDKey:kKeyBundleIDPlistApp newBundleID:watchExtensionBundleId plistOutOptions:NSPropertyListBinaryFormat_v1_0];
            if(changeAppBundleId){
                changeAppBundleId = [self changeBundleIDForFile:watchExtensionInfoPlistPath bundleIDKey:kKeyWKAppBundleId newBundleID:watchAppBundleId plistOutOptions:NSPropertyListBinaryFormat_v1_0];
            }
        }
        return changeAppBundleId;
    }
    return YES;
}

- (BOOL)changeBundleIDForFile:(NSString *)filePath bundleIDKey:(NSString *)bundleIDKey newBundleID:(NSString *)newBundleID plistOutOptions:(NSPropertyListWriteOptions)options {
    
    NSMutableDictionary *plist = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        plist = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        if([bundleIDKey rangeOfString:@":"].location != NSNotFound){
            NSArray *keys = [bundleIDKey componentsSeparatedByString:@":"];
            NSMutableDictionary *dic = plist;
            NSString *lastkey = @"";
            for(NSString *key in keys){
                if(dic[key]){
                    if([dic[key] isKindOfClass:[NSDictionary class]]){
                        dic = dic[key];
                    }
                    else{
                        lastkey = key;
                        break;
                    }
                }
            }
            dic[lastkey] = newBundleID;
        }
        else{
            plist[bundleIDKey] = newBundleID;
        }
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:options options:kCFPropertyListImmutable error:nil];
        
        return [xmlData writeToFile:filePath atomically:YES];
    }
    
    return NO;
}

- (NSString *)appFilePath{
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    NSString *appFilePath = nil;
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appFilePath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
        }
        break;
    }
    return appFilePath;
}

- (NSString *)watchAppFilePath{
    NSString *appFilePath = [[self appFilePath] stringByAppendingPathComponent:@"Watch"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:appFilePath]){
        return nil;
    }
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appFilePath error:nil];
    NSString *watchAppFilePath = nil;
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            watchAppFilePath = [appFilePath stringByAppendingPathComponent:file];
        }
        break;
    }
    return watchAppFilePath;
}

- (NSString *)watchExtensionFilePath{
    NSString *appFilePath = [[self watchAppFilePath] stringByAppendingPathComponent:@"PlugIns"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:appFilePath]){
        return nil;
    }
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appFilePath error:nil];
    NSString *watchExtensionFilePath = nil;
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"appex"]) {
            watchExtensionFilePath = [appFilePath stringByAppendingPathComponent:file];
        }
        break;
    }
    return watchExtensionFilePath;
}

- (void) doAppProvisioningAtPath:(NSString *)appFilePath withProvision:(NSString *)provisionFile{
    
    if(!appFilePath)
        return;
    
    NSString *targetPath = [appFilePath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath]) {
        NSLog(@"Found embedded.mobileprovision, deleting.");
        [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
    }
    provisioningTask = [[NSTask alloc] init];
    [provisioningTask setLaunchPath:@"/bin/cp"];
    [provisioningTask setArguments:[NSArray arrayWithObjects:provisionFile, targetPath, nil]];
    
    [provisioningTask launch];
}

- (void)doProvisioning {
    
    NSString *appFilePath = [self appFilePath];
    if(!appFilePath)
        return;
    
    [self doAppProvisioningAtPath:appFilePath withProvision:[provisioningPathField stringValue]];
    
    if([self watchAppFilePath]){
        [self doAppProvisioningAtPath:[self watchAppFilePath] withProvision:[watchAppProvisioningPathField stringValue]];
        if([self watchExtensionFilePath]){
            [self doAppProvisioningAtPath:[self watchExtensionFilePath] withProvision:[watchExtensionProvisioningPathField stringValue]];
        }
    }
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkProvisioning:) userInfo:nil repeats:TRUE];
}

- (void) checkFailed{
    
    [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Product identifiers don't match"];
    [self enableControls];
    [statusLabel setStringValue:@"Ready"];
    
}
- (void)checkProvisioning:(NSTimer *)timer {
    if ([provisioningTask isRunning] == 0) {
        [timer invalidate];
        provisioningTask = nil;
        
        BOOL identifierOK = NO;
        NSString *watchExtensionPath = [self watchExtensionFilePath];
        if(watchExtensionPath){
            
            if(![self checkAppProvisionAtPath:watchExtensionPath]){
                [self checkFailed];
                return;
            }
        }
        NSString *watchAppPath = [self watchAppFilePath];
        if(watchAppPath){
            if(![self checkAppProvisionAtPath:watchAppPath]){
                [self checkFailed];
                return;
            }
        }
        
        identifierOK = [self checkAppProvisionAtPath:[self appFilePath]];
        
        if (identifierOK) {
            NSLog(@"Provisioning completed.");
            [statusLabel setStringValue:@"Provisioning completed"];
            [self doEntitlementsFixing];
        } else {
            [self checkFailed];
        }
    }
}

- (BOOL) checkAppProvisionAtPath:(NSString *)strPath{
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[strPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
        
        BOOL identifierOK = FALSE;
        NSString *identifierInProvisioning = @"";
        
        NSString *embeddedProvisioning = [NSString stringWithContentsOfFile:[strPath stringByAppendingPathComponent:@"embedded.mobileprovision"] encoding:NSASCIIStringEncoding error:nil];
        NSArray* embeddedProvisioningLines = [embeddedProvisioning componentsSeparatedByCharactersInSet:
                                              [NSCharacterSet newlineCharacterSet]];
        
        for (int i = 0; i < [embeddedProvisioningLines count]; i++) {
            if ([[embeddedProvisioningLines objectAtIndex:i] rangeOfString:@"application-identifier"].location != NSNotFound) {
                
                NSInteger fromPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"<string>"].location + 8;
                
                NSInteger toPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"</string>"].location;
                
                NSRange range;
                range.location = fromPosition;
                range.length = toPosition-fromPosition;
                
                NSString *fullIdentifier = [[embeddedProvisioningLines objectAtIndex:i+1] substringWithRange:range];
                
                NSArray *identifierComponents = [fullIdentifier componentsSeparatedByString:@"."];
                
                if ([[identifierComponents lastObject] isEqualTo:@"*"]) {
                    identifierOK = TRUE;
                }
                
                for (int i = 1; i < [identifierComponents count]; i++) {
                    identifierInProvisioning = [identifierInProvisioning stringByAppendingString:[identifierComponents objectAtIndex:i]];
                    if (i < [identifierComponents count]-1) {
                        identifierInProvisioning = [identifierInProvisioning stringByAppendingString:@"."];
                    }
                }
                break;
            }
        }
        
        NSLog(@"Mobileprovision identifier: %@",identifierInProvisioning);
        
        NSDictionary *infoplist = [NSDictionary dictionaryWithContentsOfFile:[strPath stringByAppendingPathComponent:@"Info.plist"]];
        if ([identifierInProvisioning isEqualTo:[infoplist objectForKey:kKeyBundleIDPlistApp]]) {
            NSLog(@"Identifiers match");
            identifierOK = TRUE;
        }
        
        return identifierOK;
    } else {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Provisioning failed"];
        [self enableControls];
        [statusLabel setStringValue:@"Ready"];
    }
    return NO;
}

- (BOOL) hasWatchApp{
    return [self watchAppFilePath] && [self watchExtensionFilePath];
}

- (void)doEntitlementsFixing
{
    if (![entitlementField.stringValue isEqualToString:@""] || [provisioningPathField.stringValue isEqualToString:@""]) {
        if(![self hasWatchApp] || ([self hasWatchApp] && ![watchExtensionEntitlementField.stringValue isEqualToString:@""] && ![watchAppEntitlementField.stringValue isEqualToString:@""])){
            
            [self doCodeSigning];
            return; // Using a pre-made entitlements file or we're not re-provisioning.
        }
    }
    
    [statusLabel setStringValue:@"Generating entitlements"];

    
    [self generateEntitlementFiles];
}

- (void) generateEntitlementFiles{
    
    if([self hasWatchApp]){
        NSString *watchExtensionPath = [self watchExtensionFilePath];
        if(watchExtensionPath && [[watchExtensionEntitlementField stringValue] isEqualToString:@""]){
            // Generate watch extension entitlement file;
            [self generateEntitlementFileFrom:watchExtensionProvisioningPathField.stringValue withName:@"watchExtensionEntitlement.plist"  pathWriteTo:watchExtensionEntitlementField];
        }
        NSString *watchAppPath = [self watchAppFilePath];
        if(watchAppPath && [[watchAppEntitlementField stringValue] isEqualToString:@""]){
            [self generateEntitlementFileFrom:watchAppProvisioningPathField.stringValue withName:@"watchAppEntitlement.plist" pathWriteTo:watchAppEntitlementField];
        }
    }
    
    if ([self appFilePath] && [[entitlementField stringValue] isEqualToString:@""]) {
        [self generateEntitlementFileFrom:provisioningPathField.stringValue withName:@"entitlement.plist" pathWriteTo:entitlementField];
    }
    
    [self doCodeSigning];
}

- (void) generateEntitlementFileFrom:(NSString *)provisionPath withName:(NSString *)entitlementFile pathWriteTo:(IRTextFieldDrag *)textField{
    // Generate entitlement file, and write it's path to textField
    
    if([generateEntitlementsTask isRunning] == 0){
        generateEntitlementsTask = nil;
    }
    
    generateEntitlementsTask = [[NSTask alloc] init];
    [generateEntitlementsTask setLaunchPath:@"/usr/bin/security"];
    [generateEntitlementsTask setArguments:@[@"cms", @"-D", @"-i", provisionPath]];
    [generateEntitlementsTask setCurrentDirectoryPath:workingPath];
    
    NSPipe *pipe=[NSPipe pipe];
    [generateEntitlementsTask setStandardOutput:pipe];
    [generateEntitlementsTask setStandardError:pipe];
    NSFileHandle *handle = [pipe fileHandleForReading];
    
    [generateEntitlementsTask launch];
    
    NSString *entitlementsResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    [self doEntitlementsEdit:entitlementsResult toFile:entitlementFile writeTo:textField];
}

- (void)doEntitlementsEdit:(NSString *)entitlementsResult toFile:(NSString *)entitlementFile  writeTo:(IRTextFieldDrag *)textField
{
    NSDictionary* entitlements = entitlementsResult.propertyList;
    entitlements = entitlements[@"Entitlements"];
    NSString* filePath = [workingPath stringByAppendingPathComponent:entitlementFile];
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlements format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
    if(![xmlData writeToFile:filePath atomically:YES]) {
        NSLog(@"Error writing entitlements file.");
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Failed entitlements generation"];
        [self enableControls];
        [statusLabel setStringValue:@"Ready"];
    }
    else {
        textField.stringValue = filePath;
        
    }
}

- (void) signApp{
    
    if(!signAppObject){
        signAppObject = [[iReSignAndVerify alloc] initWithPath:[self appFilePath] entitlement:entitlementField.stringValue andCert:[certComboBox objectValue]];
        iReSignAppDelegate* bself = self;
        signAppObject.signBlock = ^(BOOL finish, NSString *codeSignResult){
            NSLog(@"signAppResult:  %@", codeSignResult);
            if(finish){
                [bself verifySignature];
            }
        };
    }
    [signAppObject doCodeSigning];
}

- (void) signWatchKitApp{
    
    NSString *watchAppFile = [self watchAppFilePath];
    if(watchAppFile){
        
        if(!signWatchKitAppObject){
            signWatchKitAppObject = [[iReSignAndVerify alloc] initWithPath:watchAppFile entitlement:watchAppEntitlementField.stringValue andCert:[certComboBox objectValue]];
            iReSignAppDelegate* bself = self;
            signWatchKitAppObject.signBlock = ^(BOOL finish, NSString *codeSignResult){
                NSLog(@"signWatchKitAppResult:  %@", codeSignResult);
                if(finish){
                    [bself signApp];
                }
            };
        }
        [signWatchKitAppObject doCodeSigning];
    }
}

- (void) signWatchKitExtension{
    
    NSString *extensionFile = [self watchExtensionFilePath];
    
    if(extensionFile)  {
        if(!signWatchExtensionObject){
            signWatchExtensionObject = [[iReSignAndVerify alloc] initWithPath:extensionFile entitlement:watchExtensionEntitlementField.stringValue andCert:[certComboBox objectValue]];
            iReSignAppDelegate* bself = self;
            signWatchExtensionObject.signBlock = ^(BOOL finish,  NSString *codeSignResult){
                NSLog(@"signWatchKitExtensionResult:  %@", codeSignResult);
                if(finish){
                    [bself signWatchKitApp];
                }
            };
        }
        [signWatchExtensionObject doCodeSigning];
    }
}

- (void) doCodeSigning{
    
    appName = [[self appFilePath] lastPathComponent];
    [statusLabel setStringValue:[NSString stringWithFormat:@"Codesigning %@",appName]];
    
    if([self hasWatchApp]){
        [self signWatchKitExtension];
    }
    
    [self signApp];
}

- (void) verifyWatchKitExtension{
    if(signWatchExtensionObject){
        iReSignAppDelegate* bself = self;
        signWatchExtensionObject.verifyBlock = ^(BOOL success, NSString *verifyResult){
            if(success){
                [bself verifyWatchKitApp];
            }
        };
        [signWatchExtensionObject doVerifySignature];
    }
}

- (void) verifyWatchKitApp{
    
    if(signWatchKitAppObject){
        iReSignAppDelegate* bself = self;
        signWatchKitAppObject.verifyBlock = ^(BOOL success, NSString *verifyResult){
            if(success){
                [bself verifyApp];
            }
        };
        [signWatchKitAppObject doVerifySignature];
    }
}

- (void) verifyApp{
    
    if(signAppObject){
        iReSignAppDelegate* bself = self;
        signAppObject.verifyBlock = ^(BOOL success, NSString *verifyResult){
            if(success){
                [bself checkVerificationSuccess:success withMessage:verifyResult];
            }
        };
        [signAppObject doVerifySignature];
    }
}

- (void) verifySignature{
    
    appName = [[self appFilePath] lastPathComponent];
    [statusLabel setStringValue:[NSString stringWithFormat:@"Verifying %@",appName]];
    
    
    if([self hasWatchApp]){
        [self verifyWatchKitExtension];
    }
    
    [self verifyApp];
}

- (void)checkVerificationSuccess:(BOOL)success withMessage:(NSString *)message {
    if (success) {
        [statusLabel setStringValue:@"Verification completed"];
        [self doZip];
    } else {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Signing failed" AndMessage:message];
        [self enableControls];
        [statusLabel setStringValue:@"Please try again"];
    }
}

- (void)doZip {
    if ([self appFilePath]) {
        NSArray *destinationPathComponents = [sourcePath pathComponents];
        NSString *destinationPath = @"";
        
        for (int i = 0; i < ([destinationPathComponents count]-1); i++) {
            destinationPath = [destinationPath stringByAppendingPathComponent:[destinationPathComponents objectAtIndex:i]];
        }
        
        fileName = [sourcePath lastPathComponent];
        fileName = [fileName substringToIndex:([fileName length] - ([[sourcePath pathExtension] length] + 1))];
        fileName = [fileName stringByAppendingString:@"-resigned"];
        fileName = [fileName stringByAppendingPathExtension:@"ipa"];
        
        destinationPath = [destinationPath stringByAppendingPathComponent:fileName];
        
        NSLog(@"Dest: %@",destinationPath);
        
        zipTask = [[NSTask alloc] init];
        [zipTask setLaunchPath:@"/usr/bin/zip"];
        [zipTask setCurrentDirectoryPath:workingPath];
        [zipTask setArguments:[NSArray arrayWithObjects:@"-qry", destinationPath, @".", nil]];
		
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkZip:) userInfo:nil repeats:TRUE];
        
        NSLog(@"Zipping %@", destinationPath);
        [statusLabel setStringValue:[NSString stringWithFormat:@"Saving %@",fileName]];
        
        [zipTask launch];
    }
}

- (void)checkZip:(NSTimer *)timer {
    if ([zipTask isRunning] == 0) {
        [timer invalidate];
        zipTask = nil;
        NSLog(@"Zipping done");
        [statusLabel setStringValue:[NSString stringWithFormat:@"Saved %@",fileName]];
        
        [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
        
        [self enableControls];
    }
}

- (IBAction)browse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"ipa", @"IPA", @"xcarchive"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [pathField setStringValue:fileNameOpened];
    }
}

- (IBAction)provisioningBrowse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"mobileprovision", @"MOBILEPROVISION"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [provisioningPathField setStringValue:fileNameOpened];
    }
}

- (IBAction)watchAppProvisioningBrowse:(id)sender{
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"mobileprovision", @"MOBILEPROVISION"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [watchAppProvisioningPathField setStringValue:fileNameOpened];
    }
}

- (IBAction)watchExtensionProvisioningBrowse:(id)sender{
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"mobileprovision", @"MOBILEPROVISION"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [watchExtensionProvisioningPathField setStringValue:fileNameOpened];
    }
}

- (IBAction)entitlementBrowse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"plist", @"PLIST"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [entitlementField setStringValue:fileNameOpened];
    }
}

- (IBAction)watchAppEntitlementBrowse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"plist", @"PLIST"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [watchAppEntitlementField setStringValue:fileNameOpened];
    }
}

- (IBAction)watchExtensionEntitlementBrowse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"plist", @"PLIST"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [watchExtensionEntitlementField setStringValue:fileNameOpened];
    }
}
- (IBAction)changeBundleIDPressed:(id)sender {
    
    if (sender != changeBundleIDCheckbox) {
        return;
    }
    
    bundleIDField.enabled = changeBundleIDCheckbox.state == NSOnState;
}

- (void)disableControls {
    [pathField setEnabled:NO];
    [entitlementField setEnabled:NO];
    [browseButton setEnabled:NO];
    [resignButton setEnabled:NO];
    [provisioningBrowseButton setEnabled:NO];
    [provisioningPathField setEnabled:NO];
    
    [entitlementBrowseButton setEnabled:NO];
    [watchAppEntitlementField setEnabled:NO];
    [watchEntitlementBrowseButton setEnabled:NO];
    [watchExtensionEntitlementField setEnabled:NO];
    [watchExtensionEntitlementBrowseButton setEnabled:NO];
    
    [watchAppProvisioningPathField setEnabled:NO];
    [watchAppProvisioningBrowseButton setEnabled:NO];
    [watchExtensionProvisioningPathField setEnabled:NO];
    [watchExtensionProvisioningBrowseButton setEnabled:NO];
    
    [changeBundleIDCheckbox setEnabled:NO];
    [bundleIDField setEnabled:NO];
    [certComboBox setEnabled:NO];
    
    [flurry startAnimation:self];
    [flurry setAlphaValue:1.0];
}

- (void)enableControls {
    [pathField setEnabled:TRUE];
    [entitlementField setEnabled:TRUE];
    [browseButton setEnabled:TRUE];
    [resignButton setEnabled:TRUE];
    [provisioningBrowseButton setEnabled:YES];
    [provisioningPathField setEnabled:YES];
    
    [entitlementBrowseButton setEnabled:YES];
    [watchAppEntitlementField setEnabled:YES];
    [watchEntitlementBrowseButton setEnabled:YES];
    [watchExtensionEntitlementField setEnabled:YES];
    [watchExtensionEntitlementBrowseButton setEnabled:YES];
    
    [watchAppProvisioningPathField setEnabled:YES];
    [watchAppProvisioningBrowseButton setEnabled:YES];
    [watchExtensionProvisioningPathField setEnabled:YES];
    [watchExtensionProvisioningBrowseButton setEnabled:YES];
    
    [changeBundleIDCheckbox setEnabled:YES];
    [bundleIDField setEnabled:changeBundleIDCheckbox.state == NSOnState];
    [certComboBox setEnabled:YES];
    
    [flurry stopAnimation:self];
    [flurry setAlphaValue:0.5];
}

-(NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    NSInteger count = 0;
    if ([aComboBox isEqual:certComboBox]) {
        count = [certComboBoxItems count];
    }
    return count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    id item = nil;
    if ([aComboBox isEqual:certComboBox]) {
        item = [certComboBoxItems objectAtIndex:index];
    }
    return item;
}

- (void)getCerts {
    
    getCertsResult = nil;
    
    NSLog(@"Getting Certificate IDs");
    [statusLabel setStringValue:@"Getting Signing Certificate IDs"];
    
    certTask = [[NSTask alloc] init];
    [certTask setLaunchPath:@"/usr/bin/security"];
    [certTask setArguments:[NSArray arrayWithObjects:@"find-identity", @"-v", @"-p", @"codesigning", nil]];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCerts:) userInfo:nil repeats:TRUE];
    
    NSPipe *pipe=[NSPipe pipe];
    [certTask setStandardOutput:pipe];
    [certTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [certTask launch];
    
    [NSThread detachNewThreadSelector:@selector(watchGetCerts:) toTarget:self withObject:handle];
}

- (void)watchGetCerts:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        
        NSString *securityResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        // Verify the security result
        if (securityResult == nil || securityResult.length < 1) {
            // Nothing in the result, return
            return;
        }
        NSArray *rawResult = [securityResult componentsSeparatedByString:@"\""];
        NSMutableArray *tempGetCertsResult = [NSMutableArray arrayWithCapacity:20];
        for (int i = 0; i <= [rawResult count] - 2; i+=2) {
            
            NSLog(@"i:%d", i+1);
            if (rawResult.count - 1 < i + 1) {
                // Invalid array, don't add an object to that position
            } else {
                // Valid object
                [tempGetCertsResult addObject:[rawResult objectAtIndex:i+1]];
            }
        }
        
        certComboBoxItems = [NSMutableArray arrayWithArray:tempGetCertsResult];
        
        [certComboBox reloadData];
        
    }
}

- (void)checkCerts:(NSTimer *)timer {
    if ([certTask isRunning] == 0) {
        [timer invalidate];
        certTask = nil;
        
        if ([certComboBoxItems count] > 0) {
            NSLog(@"Get Certs done");
            [statusLabel setStringValue:@"Signing Certificate IDs extracted"];
            
            if ([defaults valueForKey:@"CERT_INDEX"]) {
                
                NSInteger selectedIndex = [[defaults valueForKey:@"CERT_INDEX"] integerValue];
                if (selectedIndex != -1) {
                    NSString *selectedItem = [self comboBox:certComboBox objectValueForItemAtIndex:selectedIndex];
                    [certComboBox setObjectValue:selectedItem];
                    [certComboBox selectItemAtIndex:selectedIndex];
                }
                
                [self enableControls];
            }
        } else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Getting Certificate ID's failed"];
            [self enableControls];
            [statusLabel setStringValue:@"Ready"];
        }
    }
}

// If the application dock icon is clicked, reopen the window
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    // Make sure the window is visible
    if (![self.window isVisible]) {
        // Window isn't shown, show it
        [self.window makeKeyAndOrderFront:self];
    }
    
    // Return YES
    return YES;
}

#pragma mark - Alert Methods

/* NSRunAlerts are being deprecated in 10.9 */

// Show a critical alert
- (void)showAlertOfKind:(NSAlertStyle)style WithTitle:(NSString *)title AndMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:style];
    [alert runModal];
}

@end

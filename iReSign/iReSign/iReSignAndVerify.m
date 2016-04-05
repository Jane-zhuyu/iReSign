//
//  iReSignAndVerify.m
//  iReSign
//
//  Created by Jane on 4/4/16.
//  Copyright © 2016 nil. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iReSignAndVerify.h"
#import "iReSignAppDelegate.h"

static NSString *kFrameworksDirName                 = @"Frameworks";

@interface iReSignAndVerify(){
    NSMutableArray *frameworks;
    NSString *frameworksDirPath;
    BOOL hasFrameworks;
    
    
    NSTask *codesignTask;
    NSTask *generateEntitlementsTask;
    NSTask *verifyTask;
    
    NSString *codesigningResult;
    NSString *verificationResult;
}


@end

@implementation iReSignAndVerify

- (id)initWithPath:(NSString *)appPath entitlement:(NSString *)entitlement andCert:(id)cert{
    if (self = [super init]) {
        self.cert = cert;
        self.appPath = appPath;
        self.entitlement = entitlement;
    }
    return self;
}

- (void)doCodeSigning{
    
    frameworksDirPath = nil;
    hasFrameworks = NO;
    frameworks = [[NSMutableArray alloc] init];
    
    frameworksDirPath = [self.appPath stringByAppendingPathComponent:kFrameworksDirName];
    NSLog(@"Found %@",self.appPath);
    if ([[NSFileManager defaultManager] fileExistsAtPath:frameworksDirPath]) {
        NSLog(@"Found %@",frameworksDirPath);
        hasFrameworks = YES;
        NSArray *frameworksContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:frameworksDirPath error:nil];
        for (NSString *frameworkFile in frameworksContents) {
            NSString *extension = [[frameworkFile pathExtension] lowercaseString];
            NSString *frameworkPath = @"";
            if ([extension isEqualTo:@"framework"] || [extension isEqualTo:@"dylib"]) {
                frameworkPath = [frameworksDirPath stringByAppendingPathComponent:frameworkFile];
                NSLog(@"Found %@",frameworkPath);
                [frameworks addObject:frameworkPath];
            }
        }
    }
    
    if (self.appPath) {
        if (hasFrameworks) {
            [self signFile:[frameworks lastObject]];
            [frameworks removeLastObject];
        } else {
            [self signFile:self.appPath];
        }
    }
}


- (void) signFile:(NSString *)filePath{
    
    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-fs", self.cert, nil];
    NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    NSString * systemVersion = [systemVersionDictionary objectForKey:@"ProductVersion"];
    NSArray * version = [systemVersion componentsSeparatedByString:@"."];
    if ([version[0] intValue]<10 || ([version[0] intValue]==10 && ([version[1] intValue]<9 || ([version[1] intValue]==9 && [version[2] intValue]<5)))) {
        
        /*
         Before OSX 10.9, code signing requires a version 1 signature.
         The resource envelope is necessary.
         To ensure it is added, append the resource flag to the arguments.
         */
        
        NSString *resourceRulesPath = [[NSBundle mainBundle] pathForResource:@"ResourceRules" ofType:@"plist"];
        NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@",resourceRulesPath];
        [arguments addObject:resourceRulesArgument];
    } else {
        
        /*
         For OSX 10.9 and later, code signing requires a version 2 signature.
         The resource envelope is obsolete.
         To ensure it is ignored, remove the resource key from the Info.plist file.
         */
        
        NSString *infoPath = [NSString stringWithFormat:@"%@/Info.plist", filePath];
        NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
        [infoDict removeObjectForKey:@"CFBundleResourceSpecification"];
        [infoDict writeToFile:infoPath atomically:YES];
        [arguments addObject:@"--no-strict"]; // http://stackoverflow.com/a/26204757
    }
    
    if (![self.entitlement isEqualToString:@""]) {
        [arguments addObject:[NSString stringWithFormat:@"--entitlements=%@", self.entitlement]];
    }
    
    [arguments addObjectsFromArray:[NSArray arrayWithObjects:filePath, nil]];
    
    codesignTask = [[NSTask alloc] init];
    [codesignTask setLaunchPath:@"/usr/bin/codesign"];
    [codesignTask setArguments:arguments];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCodesigning:) userInfo:nil repeats:TRUE];
    
    NSPipe *pipe=[NSPipe pipe];
    [codesignTask setStandardOutput:pipe];
    [codesignTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [codesignTask launch];
    
    [NSThread detachNewThreadSelector:@selector(watchCodesigning:)
                             toTarget:self withObject:handle];
}

- (void)watchCodesigning:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        
        codesigningResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        
    }
}

- (void)checkCodesigning:(NSTimer *)timer {
    if ([codesignTask isRunning] == 0) {
        [timer invalidate];
        codesignTask = nil;
        if (frameworks.count > 0) {
            [self signFile:[frameworks lastObject]];
            [frameworks removeLastObject];
        } else if (hasFrameworks) {
            hasFrameworks = NO;
            [self signFile:self.appPath];
        } else {
            if(self.signBlock){
                self.signBlock(YES, codesigningResult);
            }
        }
    }
}

- (void)doVerifySignature {
    if (self.appPath) {
        verifyTask = [[NSTask alloc] init];
        [verifyTask setLaunchPath:@"/usr/bin/codesign"];
        [verifyTask setArguments:[NSArray arrayWithObjects:@"-v", self.appPath, nil]];
        
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkVerificationProcess:) userInfo:nil repeats:TRUE];
        
        
        NSPipe *pipe=[NSPipe pipe];
        [verifyTask setStandardOutput:pipe];
        [verifyTask setStandardError:pipe];
        NSFileHandle *handle=[pipe fileHandleForReading];
        
        [verifyTask launch];
        
        [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:)
                                 toTarget:self withObject:handle];
    }
}

- (void)watchVerificationProcess:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        
        verificationResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        
    }
}

- (void)checkVerificationProcess:(NSTimer *)timer {
    if ([verifyTask isRunning] == 0) {
        [timer invalidate];
        verifyTask = nil;
        BOOL success;
        if ([verificationResult length] == 0) {
            success = YES;
                
//                [statusLabel setStringValue:@"Verification completed"];
//                [self doZip];
        } else {
            success = NO;
//            NSString *error = [[codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:verificationResult];
//            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Signing failed" AndMessage:error];
//            [self enableControls];
//            [statusLabel setStringValue:@"Please try again"];
        }
        if(self.verifyBlock){
            self.verifyBlock(success, verificationResult);
        }
    }
}


@end
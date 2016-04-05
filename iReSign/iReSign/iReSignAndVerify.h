//
//  iReSignAndVerify.h
//  iReSign
//
//  Created by Jane on 4/4/16.
//  Copyright © 2016 nil. All rights reserved.
//

#ifndef iReSignAndVerify_h
#define iReSignAndVerify_h


#endif /* iReSignAndVerify_h */


@interface iReSignAndVerify : NSObject
typedef void (^signBlock)(BOOL, NSString *);
typedef void (^verifyBlock)(BOOL, NSString *);

@property (nonatomic, retain) NSString *entitlement;
@property (nonatomic, retain) NSString *appPath;
@property (nonatomic) id cert;
@property (nonatomic, copy) signBlock signBlock;
@property (nonatomic, copy) verifyBlock verifyBlock;

- (id)initWithPath:(NSString *)appPath entitlement:(NSString *)entitlement andCert:(id)cert;

- (void)doCodeSigning;

- (void) doVerifySignature;

@end
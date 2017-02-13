#import <XCTest/XCTest.h>
#import <ZeroKit/ZeroKit-Swift.h>
#import "ZeroKitExampleTests-Swift.h"

#define kExpectationDefaultTimeout 90

@interface ObjcCompatibilityTests : XCTestCase
@property (strong, nonatomic) ZeroKit *zeroKit;
@property (strong, nonatomic) ExampleAppMock *mockApp;
@end

@implementation ObjcCompatibilityTests

- (void)setUp {
    [super setUp];
    [self resetZeroKit];
    self.mockApp = [[ExampleAppMock alloc] init];
}

- (void)tearDown {
    self.zeroKit = nil;
    [super tearDown];
}

- (void)resetZeroKit {
    NSURL *apiURL = [NSURL URLWithString:[NSBundle mainBundle].infoDictionary[@"ZeroKitAPIURL"]];
    ZeroKitConfig *config = [[ZeroKitConfig alloc] initWithApiUrl:apiURL];
    
    NSError *error = nil;
    self.zeroKit = [[ZeroKit alloc] initWithConfig:config error:&error];
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"ZeroKit setup"];
    
    id obsSucc = [[NSNotificationCenter defaultCenter] addObserverForName:[ZeroKit DidLoadNotification] object:self.zeroKit queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [expectation fulfill];
    }];
    
    id obsFail = [[NSNotificationCenter defaultCenter] addObserverForName:[ZeroKit DidFailLoadingNotification] object:self.zeroKit queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail("Failed to load ZeroKit API");
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:obsSucc];
    [[NSNotificationCenter defaultCenter] removeObserver:obsFail];
}

#pragma mark - Convenience

- (TestUser *)registerUser {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Init registration"];
    
    NSString * __block userId = nil;
    NSString * __block regSessionId = nil;
    NSString * __block regSessionVerifier = nil;
    
    [self.mockApp initUserRegistration:^(BOOL success, NSString * _Nullable aUserId, NSString * _Nullable aRegSessionId, NSString * _Nullable aRegSessionVerifier) {
        XCTAssertTrue(success);
        
        userId = aUserId;
        regSessionId = aRegSessionId;
        regSessionVerifier = aRegSessionVerifier;
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    expectation = [self expectationWithDescription:@"Registration"];
    
    NSString *__block regValidationVerifier = nil;
    NSString *password = @"Abc123";
    
    [self.zeroKit registerWithUserId:userId registrationId:regSessionId password:password completion:^(NSString * _Nullable aRegValidationVerifier, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Registration failed %@", error);
            return;
        }
        
        regValidationVerifier = aRegValidationVerifier;
        NSLog(@"Registration validation verifier: %@", regValidationVerifier);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    expectation = [self expectationWithDescription:@"User validation"];
    
    
    [self.mockApp validateUser:userId regSessionId:regSessionId regSessionVerifier:regSessionVerifier regValidationVerifier:regValidationVerifier completion:^(BOOL success) {
        XCTAssertTrue(success);
        NSLog(@"Reg validation: %d", success);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    return [[TestUser alloc] initWithId:userId password:password];
}

- (void)loginUser:(TestUser *)user {
    [self loginUser:user rememberMe:NO expectErrorCode:0];
}

- (void)loginUser:(TestUser *)user rememberMe:(BOOL)rememberMe {
    [self loginUser:user rememberMe:rememberMe expectErrorCode:0];
}

- (void)loginUser:(TestUser *)user rememberMe:(BOOL)rememberMe expectErrorCode:(ZeroKitError)errorCode {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Login"];
    [self.zeroKit loginWithUserId:user.id password:user.password rememberMe:rememberMe completion:^(NSError * _Nullable error) {
        if (error) {
            XCTAssertTrue(errorCode == error.code, @"Login failed with unexpected error: %@", error);
        } else {
            XCTAssertTrue(errorCode == 0, @"Login succeeded while expecting error code: %ld", (long)errorCode);
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

- (void)loginByRememberMeWithUserId:(NSString *)userId {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Login by remember me"];
    
    [self.zeroKit loginByRememberMeWith:userId completion:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Failed to log in by remember me: %@", error);
        }
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

- (void)logout {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Logout"];
    [self.zeroKit logoutWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Logout failed %@", error);
        }
        
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

- (NSString *)whoAmI {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Who am I?"];
    NSString * __block userId = nil;
    [self.zeroKit whoAmIWithCompletion:^(NSString * _Nullable aUserId, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Who am I failed: %@", error);
        }
        userId = aUserId;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    return userId;
}

- (NSString *)createTresor {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Tresor creation"];
    NSString * __block tresorId = nil;
    
    [self.zeroKit createTresorWithCompletion:^(NSString * _Nullable aTresorId, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Tresor creation failed: %@", error);
        }
        
        [self.mockApp approveTresorCreation:aTresorId approve:YES completion:^(BOOL success) {
            XCTAssertTrue(success);
            tresorId = aTresorId;
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    return tresorId;
}

- (InvitationLinkPublicInfo *)infoForInvitationLink:(InvitationLink *)link {
    InvitationLinkPublicInfo * __block info = nil;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Getting link info"];
    NSString *secret = link.url.fragment;
    
    [self.zeroKit getInvitationLinkInfoWith:secret completion:^(InvitationLinkPublicInfo * _Nullable aInfo, NSError * _Nullable error) {
        if (error) {
            XCTFail("Failed to get invitation link info: %@", error);
        }
        
        info = aInfo;
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    return info;
}

- (TestUser *)changePasswordForUser:(TestUser *)user newPassword:(NSString *)newPassword {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Changing password"];
    
    [self.zeroKit changePasswordFor:user.id currentPassword:user.password newPassword:newPassword completion:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Failed to change password: %@", error);
        }
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    return [[TestUser alloc] initWithId:user.id password:newPassword];
}

#pragma mark - Tests

- (void)testRegistration {
    [self registerUser];
}

- (void)testLoginLogout {
    TestUser *user = [self registerUser];
    [self loginUser:user];
    [self logout];
}

- (void)testLoginWithInvalidUser {
    TestUser *user = [[TestUser alloc] initWithId:@"InvalidUserID" password:@"Password"];
    [self loginUser:user rememberMe:NO expectErrorCode:ZeroKitErrorInvalidUserId];
}

- (void)testLoginWithInvalidPassword {
    TestUser *user = [self registerUser];
    TestUser *invalidPwUser = [[TestUser alloc] initWithId:user.id password:@"Invalid password"];
    [self loginUser:invalidPwUser rememberMe:NO expectErrorCode:ZeroKitErrorInvalidAuthorization];
}

- (void)testRememberMe {
    TestUser *user = [self registerUser];
    [self loginUser:user rememberMe:YES];
    
    [self resetZeroKit];
    
    [self loginByRememberMeWithUserId:user.id];
    
    [self logout];
}

- (void)testPasswordChange {
    TestUser *user = [self registerUser];
    [self loginUser:user];
    
    TestUser *userNewPassword = [self changePasswordForUser:user newPassword:@"Xyz987"];
    
    [self logout];
    
    [self loginUser:userNewPassword];
    [self logout];
}

- (void)testPasswordChangeRememberMe {
    TestUser *user = [self registerUser];
    [self loginUser:user rememberMe:YES];
    
    [self changePasswordForUser:user newPassword:@"Xyz987"];
    
    [self resetZeroKit];
    
    [self loginByRememberMeWithUserId:user.id];
    
    [self logout];
}

- (void)testWhoAmI {
    XCTAssertTrue([self whoAmI] == nil);
    
    TestUser *user = [self registerUser];
    [self loginUser:user];
    
    XCTAssertTrue([[self whoAmI] isEqualToString:user.id]);
    
    [self logout];
    
    XCTAssertTrue([self whoAmI] == nil);
}

- (void)testCreateTresor {
    TestUser *user = [self registerUser];
    [self loginUser:user];
    NSString *tresorId = [self createTresor];
    XCTAssertTrue(tresorId.length > 0);
    [self logout];
}

- (void)testTextEncryption {
    TestUser *user = [self registerUser];
    [self loginUser:user];
    NSString *tresorId = [self createTresor];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Text encryption"];
    
    NSString *plainText = @"Encrypting this.";
    
    [self.zeroKit encryptWithPlainText:plainText inTresor:tresorId completion:^(NSString * _Nullable cipherText, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Text encryption failed: %@", error);
        }
        
        [self.zeroKit decryptWithCipherText:cipherText completion:^(NSString * _Nullable aPlainText, NSError * _Nullable error) {
            if (error) {
                XCTFail(@"Text decryption failed: %@", error);
            }
            
            XCTAssertTrue([aPlainText isEqualToString:plainText]);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

- (void)testDataEncryption {
    TestUser *user = [self registerUser];
    [self loginUser:user];
    NSString *tresorId = [self createTresor];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Text encryption"];
    
    NSData *plainData = [@"Encrypting this." dataUsingEncoding:NSUTF8StringEncoding];
    
    [self.zeroKit encryptWithPlainData:plainData inTresor:tresorId completion:^(NSData * _Nullable cipherData, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Data encryption failed: %@", error);
        }
        
        [self.zeroKit decryptWithCipherData:cipherData completion:^(NSData * _Nullable aPlainData, NSError * _Nullable error) {
            if (error) {
                XCTFail(@"Data decryption failed: %@", error);
            }
            
            XCTAssertTrue([aPlainData isEqual:plainData]);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

- (void)testTresorSharingAndKick {
    TestUser *owner = [self registerUser];
    TestUser *invitee = [self registerUser];
    
    [self loginUser:owner];
    
    NSString *tresorId = [self createTresor];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Tresor sharing"];
    
    [self.zeroKit shareWithTresorWithId:tresorId withUser:invitee.id completion:^(NSString * _Nullable operationId, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Tresor sharing failed: %@", error);
        }
        
        [self.mockApp approveShare:operationId approve:YES completion:^(BOOL success) {
            XCTAssertTrue(success);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    expectation = [self expectationWithDescription:@"Kicking user"];
    
    [self.zeroKit kickWithUserWithId:invitee.id fromTresor:tresorId completion:^(NSString * _Nullable operationId, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Kicking user failed: %@", error);
        }
        
        [self.mockApp approveKick:operationId approve:YES completion:^(BOOL success) {
            XCTAssertTrue(success);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

- (void)testInvitationLinkNoPassword {
    TestUser *owner = [self registerUser];
    TestUser *invitee = [self registerUser];
    
    [self loginUser:owner];
    
    NSString *tresorId = [self createTresor];
    
    NSURL *baseUrl = [NSURL URLWithString:@"https://tresorit.io/"];
    NSString *message = @"This is the message";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Creating link without password"];
    
    InvitationLink * __block link = nil;
    
    [self.zeroKit createInvitationLinkWithoutPasswordWith:baseUrl forTresor:tresorId withMessage:message completion:^(InvitationLink * _Nullable aLink, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Failed to create invitation link without password: %@", error);
        }
        
        [self.mockApp approveCreateInvitationLink:aLink.id approve:YES completion:^(BOOL success) {
            XCTAssertTrue(success);
            link = aLink;
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    [self logout];
    
    [self loginUser:invitee];
    
    InvitationLinkPublicInfo *info = [self infoForInvitationLink:link];
    
    XCTAssertTrue([info.creatorUserId isEqualToString:owner.id]);
    XCTAssertTrue([info.message isEqualToString:message]);
    XCTAssertFalse(info.isPasswordProtected);

    expectation = [self expectationWithDescription:@"Accepting link without password"];
    
    [self.zeroKit acceptInvitationLinkWithoutPasswordWith:info.token completion:^(NSString * _Nullable operationId, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Failed to accept invitation link without password: %@", error);
        }
        
        [self.mockApp approveAcceptInvitationLink:operationId approve:YES completion:^(BOOL success) {
            XCTAssertTrue(success);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

- (void)testInvitationLink {
    TestUser *owner = [self registerUser];
    TestUser *invitee = [self registerUser];
    
    [self loginUser:owner];
    
    NSString *tresorId = [self createTresor];
    
    NSURL *baseUrl = [NSURL URLWithString:@"https://tresorit.io/"];
    NSString *message = @"This is the message";
    NSString *password = @"Password1.";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Creating link without password"];
    
    InvitationLink * __block link = nil;
    
    [self.zeroKit createInvitationLinkWith:baseUrl forTresor:tresorId withMessage:message password:password completion:^(InvitationLink * _Nullable aLink, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Failed to create invitation link without password: %@", error);
        }
        
        [self.mockApp approveCreateInvitationLink:aLink.id approve:YES completion:^(BOOL success) {
            XCTAssertTrue(success);
            link = aLink;
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
    
    [self logout];
    
    [self loginUser:invitee];
    
    InvitationLinkPublicInfo *info = [self infoForInvitationLink:link];
    
    XCTAssertTrue([info.creatorUserId isEqualToString:owner.id]);
    XCTAssertTrue([info.message isEqualToString:message]);
    XCTAssertTrue(info.isPasswordProtected);
    
    expectation = [self expectationWithDescription:@"Accepting link without password"];
    
    [self.zeroKit acceptInvitationLinkWith:info.token password:password completion:^(NSString * _Nullable operationId, NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Failed to accept invitation link without password: %@", error);
        }
        
        [self.mockApp approveAcceptInvitationLink:operationId approve:YES completion:^(BOOL success) {
            XCTAssertTrue(success);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:kExpectationDefaultTimeout handler:nil];
}

@end

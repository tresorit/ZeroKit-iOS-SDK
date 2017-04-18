# ZeroKit SDK for iOS

[![Build Status](https://api.travis-ci.org/tresorit/ZeroKit-iOS-SDK.svg?branch=master)](https://travis-ci.org/tresorit/ZeroKit-iOS-SDK)

[ZeroKit](https://tresorit.com/zerokit/) is a simple, breach-proof user authentication and end-to-end encryption library.

The ZeroKit SDK for iOS is currently under development and is accessible as a preview. We continuously improve the SDK and fix bugs.

You can [sign up for ZeroKit here.](https://tresorit.com/zerokit/)

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Identity Provider](#identity-provider)
- [Administrative API](#administrative-api)
- [Example Application](#example-application)
- [Migration Guides](#migration-guides)
- [Known Issues and Limitations](#known-issues-and-limitations)
- [Contact](#contact)
- [License](#license)

## Requirements
* Xcode 8.1+
* iOS 8.0+ (iOS 9.0+ to run the example app)
* Swift 3.0
* Objective-C compatible

## Installation
### Manually
After cloning the git repository or downloading the source code follow these steps:

1. Drag and drop the `ZeroKit.xcodeproj` into your Xcode project.
2. Add the `ZeroKit.xcodeproj/Products/ZeroKit.framework` to your application's Embedded Binaries.
3. Build your app.

### Carthage
[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

To integrate ZeroKit into your Xcode project using Carthage, specify it in your Cartfile:

```
github "ZeroKit/ZeroKit"
```

Run `carthage update` to build the framework and drag the built ZeroKit.framework into your Xcode project.

### CocoaPods
[CocoaPods](https://cocoapods.org) is a dependency manager for Swift and Objective-C Cocoa projects.

To integrate ZeroKit into your Xcode project using CocoaPods, specify it in your Podfile:

```ruby
target '<Your Target>' do
  use_frameworks!
  pod 'ZeroKit', '~> 4.1'
end
```

Then, install it with the following command:

```
$ pod install
```

## Usage

### Initalizing ZeroKit
To initalize the SDK you will need your service URL. You can find your service URL in your [management portal](https://manage.tresorit.io).

*Swift*
```swift
import ZeroKit

let zeroKitConfig = ZeroKitConfig(apiBaseUrl: URL(string: "https://{TenantId}.api.tresorit.io")!)
let zeroKit = try! ZeroKit(config: zeroKitConfig)
```

*Objective-C*
```objc
#import <ZeroKit/ZeroKit-Swift.h>

NSURL *apiURL = [NSURL URLWithString:@"https://{TenantId}.api.tresorit.io"];
ZeroKitConfig *config = [[ZeroKitConfig alloc] initWithApiBaseUrl:apiURL];
NSError *error = nil;
ZeroKit *zeroKit = [[ZeroKit alloc] initWithConfig:config error:&error];
```

*Note: ZeroKit SDK for iOS wraps our javascript SDK. For this to run properly a web view is required to provide the runtime environment. As the user of the SDK you need not to interact with this web view and should not cause any trouble in most cases.*

### Password handling
A core concept of ZeroKit is that your application should not access and pass around the users' passwords. All password handling should be done by ZeroKit. For this we provide a `ZeroKitPasswordField` UI component you that you should present to users to enter their passwords. Some tips for using `ZeroKitPasswordField`:

- You can instantiate it in code or in Interface Builder. 
- It is marked as @IBDesignable so you can preview it in Interface Builder and also set some custom properties.
- In Interface Builder simply add a UIView to your layout and set its class to `ZeroKitPasswordField`. Also make sure the Module is set to `ZeroKit`.
- When you need the user to type their password twice for confirmation (eg. during registration) you create two password fields and set the `matchingField` property on them. Use the `passwordsMatch` property to check if they match.
- You can customize its appearance similarly to a `UITextField`.

To get the strength of a password use the `passwordStrength(passwordField:, completion:)` method of a `ZeroKit` object.

### Making a call

*Swift*
```swift
zeroKit.encrypt(plainText: "apple", inTresor: tresorId) { cipherText, error in
    guard error == nil else {
        print("Encrypting failed: \(error!)")
        return
    }

    print("Encrypted text: \(cipherText!)")
}
```

*Objective-C*
```objc
[self.zeroKit encryptWithPlainText:"apple" inTresor:tresorId completion:^(NSString * _Nullable cipherText, NSError * _Nullable error) {
    if (error) {
        NSLog(@"Encrypting failed: %@", error);
    } else {
        NSLog(@"Encrypted text: %@", cipherText);
    }
}];
```

## Identity Provider

ZeroKit comes with OpenID Connect provider implementation that you can use in your app. Use the `getIdentityTokens(clientId:, completion:)` method of a `ZeroKit` object to get authorization code and identity token for the current ZeroKit user. A user must be logged in when calling this method. The ZeroKit Open ID client used in mobile apps should have the following settings:

- Redirect URL should have the following format: `https://{Client ID}.{Tenant ID}.api.tresorit.io/`
- Flow should be set to `Hybrid`
- You can optionally turn on `Requires proof key (DHCE)`

You can add new clients and edit settings on the management portal.

## Administrative API

Most of the cryptographic operations (including invites and sharing) must be done client side by the SDK library. To provide control over these operations, and to prevent possible abuse by tampering the client, we introduced the admin API. All client initiated changes which has a permanent effect on the server has to be approved through the Admin API (typically by the server backend of the integrated app). For more information see the ZeroKit [documentation](https://tresorit.com/files/zerokit_encryption-sdk-documentation.pdf).

**IMPORTANT:** You must **never include your Admin key in your client application**. We provide a sample backend to handle the administrative calls for our sample app. The admin key must be kept secret and not included in any client applications that you distribute.

## Example Application

An example appliction is included with ZeroKit to demonstrate its usage. Open the `ZeroKit.xcworkspace` workspace which contains a `ZeroKitExample` project. It demonstrates the following features:

- Registration
- Login and logout
- Tresor creation
- Tresor sharing
- Encryption
- Decryption

### Configuring the Example

#### Step 1 - Set up the backend

The example app requires a backend to function. We created a sample backend that you can use for the mobile and web ZeroKit sample apps. You can find the backend and setup instructions [here](https://github.com/tresorit/ZeroKit-NodeJs-backend-sample).

#### Step 2 - Configure the iOS example app

To use the example app you first have to set it up with your ZeroKit configuration. In the `ZeroKitExample/Config.plist` file set the values for `ZeroKitAPIBaseURL`, `ZeroKitClientId` and `ZeroKitAppBackend` keys. If this file does not exist then copy the sample `Config.sample.plist` file in the same directory to create one:

```xml
<key>ZeroKitAPIBaseURL</key>
<string>{TenantBaseUrl}</string>
<key>ZeroKitClientId</key>
<string>{ClientId}</string>
<key>ZeroKitAppBackend</key>
<string>{AppBackendUrl}</string>
```

- `ZeroKitAPIBaseURL`: This is your tenant's service URL. You can find this URL on the management portal.
- `ZeroKitClientId`: This is the client ID for your OpenID Connect client that you wish to use with your mobile.
- `ZeroKitAppBackend`: This is the URL of the sample application backend. You can find the sample backend and setup instructions [here](https://github.com/tresorit/ZeroKit-NodeJs-backend-sample).

Now you are ready to **Build and Run** (**⌘R**) the example in Xcode.

### Registering Test Users

Register test users following the `'test-user-{XYZ}'` username format. These users will be automatically validated by the sample backend so you can log in right after registration.

### Unit Tests

You can also take a look at the unit tests in this project to see further examples. To run the tests you must have the example app configured as described in [Configuring the Example](#configuring-the-example).

## Migration Guides

### Migration to 4.1.0

#### Initialization

Since version 4.1.0 initializing ZeroKit with the API URL has been deprecated. You should initialize it with your API base URL (or your service URL) that you can find on your [management portal](https://manage.tresorit.io).

```swift
// Since 4.1.0
let zeroKitConfig = ZeroKitConfig(apiBaseUrl: URL(string: "https://{TenantId}.api.tresorit.io")!)

// Previously in 4.0.x
let zeroKitConfig = ZeroKitConfig(apiUrl: URL(string: "https://host-{HostId}.api.tresorit.io/tenant-{TenantId}/static/v4/api.html")!)
```

*Note: `ZeroKitConfig(apiUrl:)` is still available for backwards compatibilty but will be removed in a future version.*

#### Notifications

In version 4.1.0 you no longer have to subscribe to `ZeroKit.DidLoadNotification` or `ZeroKit.DidFailLoadingNotification` notifications. You can start making ZeroKit calls right after initialization. The SDK will load the API internally and only after that will it handle your calls. This means you can just remove your observers for these notifications.

You will receive an error with `apiLoadingError` code in your callbacks if the API could not be loaded. In these cases the SDK will retry loading the API during subsequent calls.

*Note: The notifications are still available for backwards compatibilty but will be removed in a future version.*

## Known Issues and Limitations

Currently the SDK does not support app extensions.

## Contact

Contact us at [zerokit@tresorit.com](mailto:zerokit@tresorit.com).

## License

See the LICENSE file.

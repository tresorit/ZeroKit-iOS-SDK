# ZeroKit SDK for iOS

[![Build Status](https://api.travis-ci.org/tresorit/ZeroKit-iOS-SDK.svg?branch=master)](https://travis-ci.org/tresorit/ZeroKit-iOS-SDK)

[ZeroKit](https://tresorit.com/zerokit/) is a simple, breach-proof user authentication and end-to-end encryption library.

The ZeroKit SDK for iOS is currently under development and is accessible as a preview. We continuously improve the SDK and fix bugs.

You can [sign up for ZeroKit here.](https://tresorit.com/zerokit/)

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
  pod 'ZeroKit', '~> 4.0'
end
```

Then, install it with the following command:

```
$ pod install
```

## Usage

### Initalizing ZeroKit
To initalize the SDK you will need your API URL:

*Swift*
```swift
import ZeroKit

let zeroKitConfig = ZeroKitConfig(apiUrl: URL(string: "https://host-{hostid}.api.tresorit.io/tenant-{tenantid}/static/v4/api.html")!)
let zeroKit = try! ZeroKit(config: zeroKitConfig)
```

*Objective-C*
```objc
#import <ZeroKit/ZeroKit-Swift.h>

NSURL *apiURL = [NSURL URLWithString:@"https://host-{hostid}.api.tresorit.io/tenant-{tenantid}/static/v4/api.html"];
ZeroKitConfig *config = [[ZeroKitConfig alloc] initWithApiUrl:apiURL];
NSError *error = nil;
ZeroKit *zeroKit = [[ZeroKit alloc] initWithConfig:config error:&error];
```

*Note: ZeroKit SDK for iOS wraps our javascript SDK. For this to run properly a web view is required to provide the runtime environment. As the user of the SDK you need not to interact with this web view and should not cause any trouble in most cases.*

### Loading the SDK
Before you can make any calls to ZeroKit it must be loaded. Loading automatically starts after initialization. Once it completes you get a `ZeroKit.DidLoadNotification` or a `ZeroKit.DidFailLoadingNotification` notification. `zeroKit.isLoaded` is also set to `true` if loading is successful.

### Password handling
A core concept of ZeroKit is that your application should not access and pass around the users' passwords. All password handling should be done by ZeroKit. For this we provide a `ZeroKitPasswordField` UI component you that you should present to users to enter their passwords. Some tips for using `ZeroKitPasswordField`:

- You can instantiate it in code or in Interface Builder. 
- It is marked as @IBDesignable so you can preview it in Interface Builder and also set some custom properties.
- In Interface Builder simply add a UIView to your layout and set its class to `ZeroKitPasswordField`. Also make sure the Module is set to `ZeroKit`.
- When you need the user to type their password twice for confirmation (eg. during registration) you create two password fields and set the `matchingField` property on them. Use the `passwordsMatch` property to check if they match.
- You can customize its appearance similarly to a `UITextField`.

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

## Example Application

An example appliction is included with ZeroKit to demonstrate its usage. Open the `ZeroKit.xcworkspace` workspace which contains a `ZeroKitExample` project. It demonstrates the following features:

- Registration
- Login and logout
- Tresor creation
- Tresor sharing
- Encryption
- Decryption

### Configuring the Example

To use the example app you first have to set it up with your ZeroKit configuration. If you downloaded it from the management portal then it is already configure for you.

In the `ZeroKitExample/Info.plist` file set the value of the `ZeroKitAPIURL` to your API URL (your tenant URL). If this file does not exist then copy the sample `Info.sample.plist` file in the same directory to create one:

```xml
<key>ZeroKitAPIURL</key>
<string>{TenantBaseUrl}/static/v4/api.html</string>
``` 

In the `ZeroKitExample/ExampleAppMock/ExampleAppMock.plist` set the values for `AdminUserId`, `AdminKey` and `ApiRoot` (tenant URL). If this file does not exist then copy the sample `ExampleAppMock.sample.plist` file in the same directory to create one:

```xml
<key>AdminUserId</key>
<string>admin@{TenantId}.tresorit.io</string>
<key>AdminKey</key>
<string>{AdminKey}</string>
<key>ApiRoot</key>
<string>{TenantBaseUrl}</string>
```

**!!! IMPORTANT NOTE:** You must **never include your Admin key in your application**. All Admin key calls must be done by your backend. We implemented a mock application in this example so you can run it without setting up a server. The admin key must be kept secret and not included in any client applications that you distribute.

Now you are ready to **Build and Run** (**⌘R**) the example in Xcode.

### Unit tests

You can also take a look at the unit tests in this project to see further examples. To run the tests you must first configure the API URL in the `ZeroKitExampleTests/Info.plist`. If this file does not exist then copy the sample `Info.sample.plist` file in the same directory:

```xml
<key>ZeroKitAPIURL</key>
<string>{TenantBaseUrl}/static/v4/api.html</string>
``` 

## Known Issues and Limitations

Currently the SDK does not support app extensions.

## Contact

Contact us at [zerokit@tresorit.com](mailto:zerokit@tresorit.com).

## License

See the LICENSE file.

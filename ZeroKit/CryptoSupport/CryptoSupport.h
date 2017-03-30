/*
 Support for CommonCrypto as it cannot be imported to Swift framework as module.
 */

@import Foundation;

NSData * _Nullable ZeroKitSha256(NSData * _Nonnull input);
NSString * _Nonnull ZeroKitUrlSafeBase64Encode(NSData * _Nonnull input);

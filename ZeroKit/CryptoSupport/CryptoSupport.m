#import <CommonCrypto/CommonCrypto.h>
#import "CryptoSupport.h"

NSData * _Nullable ZeroKitSha256(NSData * _Nonnull input) {
    uint8_t hash[CC_SHA256_DIGEST_LENGTH];
    if (CC_SHA256(input.bytes, (CC_LONG)input.length, hash)) {
        NSData *data = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
        return data;
    }
    return nil;
}

NSString * _Nonnull ZeroKitUrlSafeBase64Encode(NSData * _Nonnull input) {
    NSString *ret = [input base64EncodedStringWithOptions:0];
    ret = [ret stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
    ret = [ret stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    ret = [ret stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return ret;
}

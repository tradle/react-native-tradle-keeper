
#import "RNTradleKeeper.h"
#import <CommonCrypto/CommonDigest.h>

@implementation RNTradleKeeper

static NSString* const RNTradleKeeperErrorDomain = @"tradle.keeper.error";

enum RNTradleKeeperError
{
  RNTradleKeeperNoError = 0,           // Never used
  RNTradleKeeperNoSuchAlgorithm,       // Invalid hash algorithm
};

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(put:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString* key = [options objectForKey:@"key"];
  NSString* value = [options objectForKey:@"value"];
  NSString* algorithm = [options objectForKey:@"algorithm"];
  NSString* encryptionKey = [options objectForKey:@"encryptionKey"];
  NSStringEncoding encoding = [self getSpecifiedEncoding:options];
  NSData *data = [value dataUsingEncoding:encoding];

  NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
  if ([options objectForKey:@"NSFileProtectionKey"]) {
    [attributes setValue:[options objectForKey:@"NSFileProtectionKey"] forKey:@"NSFileProtectionKey"];
  }

  BOOL success = [[NSFileManager defaultManager] createFileAtPath:filepath contents:data attributes:attributes];

  if (!success) {
    return reject(@"ENOENT", [NSString stringWithFormat:@"ENOENT: no such file or directory, open '%@'", filepath], nil);
  }

  return resolve(nil);
}

- (NSData*)encryptData:(NSData*) data withKey:(NSString* encryptionKey) {

}

- (NSStringEncoding) getSpecifiedEncoding:(NSDictionary *)options {
  // TODO: parse from options.encoding
  return NSUTF8StringEncoding;
//  if ([options objectForKey:@"encoding"] == nil || [[options objectForKey:@"encoding"] isEqualToString:@"utf8"]) {
//    return NSUTF8StringEncoding;
//  }
}

//RCT_EXPORT_METHOD(hash:(NSDictionary *)options
//                  resolver:(RCTPromiseResolveBlock)resolve
//                  rejecter:(RCTPromiseRejectBlock)reject)
//{}

- (NSString*) hashData:(NSData *)content
                  algorithm:(NSString *)algorithm
                  error:(NSError**) error
{
  NSArray *algorithms = [NSArray arrayWithObjects:@"md5", @"sha1", @"sha224", @"sha256", @"sha384", @"sha512", nil];
  NSArray *digestLengths = [NSArray arrayWithObjects:
                            @CC_MD5_DIGEST_LENGTH,
                            @CC_SHA1_DIGEST_LENGTH,
                            @CC_SHA224_DIGEST_LENGTH,
                            @CC_SHA256_DIGEST_LENGTH,
                            @CC_SHA384_DIGEST_LENGTH,
                            @CC_SHA512_DIGEST_LENGTH,
                            nil];

  NSDictionary *keysToDigestLengths = [NSDictionary dictionaryWithObjects:digestLengths forKeys:algorithms];
  int digestLength = [[keysToDigestLengths objectForKey:algorithm] intValue];

  unsigned char buffer[digestLength];
  if ([algorithm isEqualToString:@"md5"]) {
    CC_MD5(content.bytes, (CC_LONG)content.length, buffer);
  } else if ([algorithm isEqualToString:@"sha1"]) {
    CC_SHA1(content.bytes, (CC_LONG)content.length, buffer);
  } else if ([algorithm isEqualToString:@"sha224"]) {
    CC_SHA224(content.bytes, (CC_LONG)content.length, buffer);
  } else if ([algorithm isEqualToString:@"sha256"]) {
    CC_SHA256(content.bytes, (CC_LONG)content.length, buffer);
  } else if ([algorithm isEqualToString:@"sha384"]) {
    CC_SHA384(content.bytes, (CC_LONG)content.length, buffer);
  } else if ([algorithm isEqualToString:@"sha512"]) {
    CC_SHA512(content.bytes, (CC_LONG)content.length, buffer);
  } else {
    error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperNoSuchAlgorithm userInfo:nil];
    return nil;
  }

  NSMutableString *output = [NSMutableString stringWithCapacity:digestLength * 2];
  for(int i = 0; i < digestLength; i++)
    [output appendFormat:@"%02x",buffer[i]];

  return output;
}

@end


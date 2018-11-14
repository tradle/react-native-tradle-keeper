
#import "RNTradleKeeper.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
//#import "EncryptionMateral.h"
#import <CommonCrypto/CommonDigest.h>

//@interface EncryptionMaterial:NSObject {
//  NSData* encryptionKey;
//  NSData* hmacKey;
//}
//
//@property(nonatomic, readwrite) NSData* encryptionKey;
//@property(nonatomic, readwrite) NSData* hmacKey;
//
//@end
//
//@implementation EncryptionMaterial
//
//@synthesize encryptionKey;
//@synthesize hmacKey;
//
//@end

@implementation RNTradleKeeper

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

//static NSMutableDictionary<NSString*, EncryptionMaterial*> *encCache;
static NSString* const RNTradleKeeperErrorDomain = @"tradle.keeper.error";

enum RNTradleKeeperError
{
  RNTradleKeeperNoError = 0,           // Never used
  RNTradleKeeperInvalidEncoding,
  RNTradleKeeperInvalidTarget,
  RNTradleKeeperInvalidDataProtection,
  RNTradleKeeperInvalidAlgorithm,
  RNTradleKeeperUnknownMimeType,
  RNTradleKeeperWriteFailed,
};

//+ (void) initialize {
//  encCache = [NSMutableDictionary new];
//}

//- (dispatch_queue_t)methodQueue
//{
//    return dispatch_get_main_queue();
//}

//@synthesize bridge = _bridge;

//static NSDictionary* const DATA_PROTECTION = [
//  @"completeFileProtection": Data.WritingOptions.completeFileProtection,
//  @"completeFileProtectionUnlessOpen": Data.WritingOptions.completeFileProtectionUnlessOpen,
//  @"completeFileProtectionUntilFirstUserAuthentication": Data.WritingOptions.completeFileProtectionUntilFirstUserAuthentication
//];

+(NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

RCT_EXPORT_METHOD(put:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![self validateOptions:options reject:reject]) {
    return;
  }

  if ([options objectForKey:@"key"] == nil) {
    reject(@"invalid_option", @"missing option key", nil);
    return;
  }

  if ([options objectForKey:@"value"] == nil) {
    reject(@"invalid_option", @"missing option value", nil);
    return;
  }

  if (!([RNTradleKeeper shouldAddToImageCache:options] || [RNTradleKeeper shouldReturnBase64:options])) {
    reject(@"invalid_option", @"expected addToImageCache or returnBaes64 or both", nil);
    return;
  }

  NSData *data = [self parseValueData:options];
//  NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
//  if ([options objectForKey:@"NSFileProtectionKey"]) {
//    [attributes setValue:[options objectForKey:@"NSFileProtectionKey"] forKey:@"NSFileProtectionKey"];
//  }

  NSError* error;
  [self encryptToFS:data options:options error:&error];
  if (error != nil) {
    reject(@"encryption_error", [error localizedDescription], error);
    return;
  }
  
  if ([RNTradleKeeper shouldAddToImageCache:options]) {
    RCTImageStoreManager *manager = [self getImageStore];
    [manager storeImageData:data withBlock:^(NSString *imageTag) {
      resolve(@{
        @"imageTag": imageTag,
      });
    }];

    return;
  }

  resolve(nil);
}

- (NSString*) encryptToFS:(NSData*) data
               options:(NSDictionary*) options
                 error:(NSError**) error {
  NSString* key;
  if ([options objectForKey:@"key"] == nil) {
    key = [self hashData:data options:options error:error];
  } else {
    key = [options objectForKey:@"key"];
  }

  NSError* encryptionError;
  NSData *encrypted = [self encrypt:data
                            options:options
                              error:&encryptionError];

  if (encryptionError != nil) {
    *error = encryptionError;
    return nil;
  }

  NSURL *base = [RNTradleKeeper applicationDocumentsDirectory];
  NSURL *filePath = [base URLByAppendingPathComponent:key];
  BOOL success = [encrypted writeToURL:filePath atomically:true];
  if (success) {
    *error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperWriteFailed userInfo:nil];
    return key;
  }

  return nil;
}
//
//RCT_EXPORT_METHOD(test)
//{
//  NSError* error;
//  [self testError1:&error];
//  if (error == nil) {
//    NSLog(@"blah1");
//  } else {
//    NSLog(@"blah2");
//  }
//
//  [self testError2:&error];
//  if (error == nil) {
//    NSLog(@"blah1");
//  } else {
//    NSLog(@"blah2");
//  }
//}
//
//- (void) testError1:(NSError**)error {
//  return [self testError2:error];
//}
//
//- (void) testError2:(NSError**)error {
//  *error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperUnknownMimeType userInfo:nil];
//}

RCT_EXPORT_METHOD(get:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![self validateOptions:options reject:reject]) {
    return;
  }

  if ([options objectForKey:@"key"] == nil) {
    reject(@"invalid_option", @"missing option key", nil);
    return;
  }

  NSString* key = [options objectForKey:@"key"];
//  NSString* encryptionPassword = [options objectForKey:@"encryptionPassword"];

  NSURL *base = [RNTradleKeeper applicationDocumentsDirectory];
  NSURL *filePath = [base URLByAppendingPathComponent:key];
  NSData *encrypted = [NSData dataWithContentsOfURL:filePath];
  NSError* error;
  NSData *data = [self decrypt:encrypted options:options error:&error];
  if (error != nil) {
    reject(@"decryption_error", [error localizedDescription], error);
    return;
  }

  NSMutableDictionary* result = [NSMutableDictionary new];
  if ([RNTradleKeeper shouldAddToImageCache:options]) {
    RCTImageStoreManager *manager = [self getImageStore];
    [manager storeImageData:data withBlock:^(NSString *imageTag) {
      [result setObject:imageTag forKey:@"imageTag"];
      resolve(result);
    }];

    return;
  }

  if ([RNTradleKeeper shouldReturnBase64:options]) {
    [result setObject:[data base64EncodedDataWithOptions:0] forKey:@"base64"];
  }

  return resolve(result);
}

RCT_EXPORT_METHOD(importFromImageStore:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![self validateOptions:options reject:reject]) {
    return;
  }

  if ([options objectForKey:@"encryptionPassword"] == nil) {
    reject(@"invalid_option", @"missing option encryptionPassword", nil);
    return;
  }

  if ([options objectForKey:@"imageTag"] == nil) {
    reject(@"invalid_option", @"missing option imageTag", nil);
    return;
  }

  NSString* imageTag = [options objectForKey:@"imageTag"];
  RCTImageStoreManager *manager = [self getImageStore];
  [manager getImageDataForTag:imageTag withBlock:^(NSData *data) {
    if (data == nil) {
      reject(@"image_not_found", imageTag, nil);
      return;
    }

    NSString* algorithm = [self getSpecifiedAlgorithm:options];
    NSError* error;
    NSString* key = [self encryptToFS:data options:options error:&error];
    if (error != nil) {
      reject(@"encryption_error", [error localizedDescription], error);
      return;
    }

    resolve(@{
      @"key": key,
      @"algorithm": algorithm,
      @"mimeType": [RNTradleKeeper mimeTypeForData:data],
    });
  }];
}

// https://stackoverflow.com/questions/21789770/determine-mime-type-from-nsdata#32765708
+ (NSString *)mimeTypeForData:(NSData *)data {
  uint8_t c;
  [data getBytes:&c length:1];

  switch (c) {
    case 0xFF:
      return @"image/jpeg";
      break;
    case 0x89:
      return @"image/png";
      break;
    case 0x47:
      return @"image/gif";
      break;
    case 0x49:
    case 0x4D:
      return @"image/tiff";
      break;
    case 0x25:
      return @"application/pdf";
      break;
    case 0xD0:
      return @"application/vnd";
      break;
    case 0x46:
      return @"text/plain";
      break;
    default:
      return @"application/octet-stream";
  }
  return nil;
}

+ (NSString*)getDataUrl:(NSData*) data error:(NSError**) error {
  NSString* mimeType = [RNTradleKeeper mimeTypeForData:data];
  if ([mimeType isEqualToString:@"application/octet-stream"]) {
    *error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperUnknownMimeType userInfo:nil];
    return nil;
  }

  NSString* base64 = [data base64EncodedStringWithOptions:0];
  NSString* dataUrl = [NSString stringWithFormat:@"data:%@;base64,%@",mimeType,base64];
  return dataUrl;
}

- (RCTImageStoreManager*) getImageStore {
  return self->_bridge.imageStoreManager;
//  return [self.bridge moduleForClass:[RCTImageStoreManager class]];
}

+ (RNCryptorSettings) getEncryptionSettings {
  return kRNCryptorAES256Settings;
}

+ (NSData*) getHexOptionAsData:(NSDictionary*) options key:(NSString*) {
  NSString* hex = [options objectForKey:key];
  return [NSData datawi]
}

- (NSData*) encrypt:(NSData*)data options:(NSDictionary*) options error:(NSError**) error {
  return [self encrypt:data
     withEncryptionKey:[RNTradleKeeper getHexOptionAsData:options key:@"encryptionKey"]
          withHMACKey:[options objectForKey:@"hmacKey"]
                 error:error];
}

- (NSData*) decrypt:(NSData*)data options:(NSDictionary*) options error:(NSError**) error {
  return [self decrypt:data
     withEncryptionKey:[options objectForKey:@"encryptionKey"]
           withHMACKey:[options objectForKey:@"hmacKey"]
                 error:error];
}

- (NSData*) encrypt:(NSData*) data
  withEncryptionKey:(NSData*) encryptionKey
        withHMACKey:(NSData*) hmacKey
              error:(NSError**) error {
  RNCryptorSettings settings = [RNTradleKeeper getEncryptionSettings];
  return [RNEncryptor encryptData:data
                     withSettings:settings
                    encryptionKey:encryptionKey
                          HMACKey:hmacKey
                            error:error];
}

- (NSData*) decrypt:(NSData*) data
  withEncryptionKey:(NSData*) encryptionKey
        withHMACKey:(NSData*) hmacKey
              error:(NSError**) error {
  return [RNDecryptor decryptData:data
                withEncryptionKey:encryptionKey
                          HMACKey:hmacKey
                            error:error];
}

//- (NSData*) encrypt:(NSData*) data withPassword:(NSString*) password error:(NSError**) error {
//  RNCryptorSettings settings = [RNTradleKeeper getEncryptionSettings];
//  EncryptionMaterial *material = [self getEncryptionMaterial:password];
//  return [RNEncryptor encryptData:data
//                     withSettings:settings
//                    encryptionKey:material.encryptionKey
//                          HMACKey:material.hmacKey
//                            error:error];
//}
//
//- (NSData*) decrypt:(NSData*) data withPassword:(NSString*) password error:(NSError**) error {
//  EncryptionMaterial *material = [self getEncryptionMaterial:password];
//  return [RNDecryptor decryptData:data
//                withEncryptionKey:material.encryptionKey
//                          HMACKey:material.hmacKey
//                            error:error];
//}

//- (EncryptionMaterial*) getEncryptionMaterial:(NSString*) password {
//  if ([encCache objectForKey:password] == nil) {
//    RNCryptorSettings settings = [RNTradleKeeper getEncryptionSettings];
//    EncryptionMaterial *material = [EncryptionMaterial alloc];
//    NSData* encryptionSalt = [RNCryptor randomDataOfLength:settings.keySettings.saltSize];
//    NSData* HMACSalt = [RNCryptor randomDataOfLength:settings.HMACKeySettings.saltSize];
//    material.encryptionKey = [RNCryptor keyForPassword:password salt:encryptionSalt settings:settings.keySettings];
//    material.hmacKey = [RNCryptor keyForPassword:password salt:HMACSalt settings:settings.HMACKeySettings];
//    [encCache setObject:material forKey:password];
//  }
//
//  return [encCache objectForKey:password];
//}

- (BOOL) validateOptions:(NSDictionary* )options reject: (RCTPromiseRejectBlock)reject {
  if ([options objectForKey:@"encoding"] != nil &&
      ![@"utf8" isEqualToString:[options objectForKey:@"encoding"]] &&
      ![@"base64" isEqualToString:[options objectForKey:@"encoding"]]) {
    reject(@"invalid_encoding", @"only utf8, base64 supported at the moment", nil);
    return false;
  }

//  if ([options objectForKey:@"dataProtection"] != nil &&
//      [options["dataProtection"]!] == nil {
//    NSError* error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperInvalidDataProtection userInfo:nil];
//    reject("invalid_data_protection", "see Data.WritingOptions", RNTradleKeeperError.invalidEncoding);
//    return false;
//  }

  if ([options objectForKey: @"target"] != nil &&
      ![@"base64" isEqualToString:[options objectForKey: @"target"]] &&
      ![@"imageCache" isEqualToString:[options objectForKey: @"target"]]) {
//    NSError* error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperInvalidTarget userInfo:nil];
    reject(@"invalid_target", @"expected 'base64' or 'imageCache'", nil);
    return false;
  }

  return true;
}

//- (NSString*) importFromImageStore:(NSDictionary*) options  {
//
//}

- (NSData*) parseValueData:(NSDictionary*) options {
  NSString* value = [options objectForKey:@"value"];
  NSString* encoding = [self getSpecifiedEncoding:options];
  if ([encoding isEqualToString:@"utf8"]) {
    return [value dataUsingEncoding:NSUTF8StringEncoding];
  }

  return [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

- (NSString*) getSpecifiedEncoding:(NSDictionary *)options {
  // TODO: parse from options.encoding
  if ([options objectForKey:@"encoding"] == nil) {
    return @"base64";
  }

  return [options objectForKey:@"encoding"];
}

- (NSString*) getSpecifiedAlgorithm:(NSDictionary*) options {
  if ([options objectForKey:@"algorithm"]) {
    return @"sha256";
  }

  return [options objectForKey:@"algorithm"];
}

+ (BOOL) shouldAddToImageCache:(NSDictionary*) options {
  return [RNTradleKeeper getBoolOption:options option:@"addToImageCache"];
}

+ (BOOL) shouldReturnBase64:(NSDictionary*) options {
  return [RNTradleKeeper getBoolOption:options option:@"returnBase64"];
}

+ (BOOL) getBoolOption:(NSDictionary*) options option:(NSString*) option {
  return [options objectForKey:option] == nil ? false : [[options objectForKey:option] boolValue];
}

+ (BOOL) getBoolOption:(NSDictionary*) options option:(NSString*) option defaultValue:(BOOL)defaultValue {
  return [options objectForKey:option] == nil ? defaultValue : [[options objectForKey:option] boolValue];
}

//RCT_EXPORT_METHOD(hash:(NSDictionary *)options
//                  resolver:(RCTPromiseResolveBlock)resolve
//                  rejecter:(RCTPromiseRejectBlock)reject)
//{}

- (NSString*) hashData:(NSData *)content
                  options:(NSDictionary *)options
                  error:(NSError**) error
{
  NSString* algorithm = [self getSpecifiedAlgorithm:options];
  if ([options objectForKey:@"hashDataUrl"] != nil && [[options objectForKey:@"hashDataUrl"] boolValue]) {
    NSString* dataUrl = [RNTradleKeeper getDataUrl:content error:error];
    content = [dataUrl dataUsingEncoding:NSUTF8StringEncoding];
  }

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
    *error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperInvalidAlgorithm userInfo:nil];
    return nil;
  }

  NSMutableString *output = [NSMutableString stringWithCapacity:digestLength * 2];
  for(int i = 0; i < digestLength; i++)
    [output appendFormat:@"%02x",buffer[i]];

  return output;
}

@end

@implementation RCTBridge (RNTradleKeeper)

- (RNTradleKeeper *)tradleKeeper
{
  return [self moduleForClass:[RNTradleKeeper class]];
}

@end

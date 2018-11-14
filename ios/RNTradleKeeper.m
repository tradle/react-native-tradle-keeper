
#import "RNTradleKeeper.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
//#import "EncryptionMateral.h"
#import <CommonCrypto/CommonDigest.h>

@interface EncryptionMaterial:NSObject {
  NSData* encryptionKey;
  NSData* hmacKey;
}

@property(nonatomic, readwrite) NSData* encryptionKey;
@property(nonatomic, readwrite) NSData* hmacKey;

@end

@implementation EncryptionMaterial

@synthesize encryptionKey;
@synthesize hmacKey;

@end

@implementation RNTradleKeeper
{
  NSMutableDictionary<NSString*, EncryptionMaterial*> *encCache;
}

static NSString* const RNTradleKeeperErrorDomain = @"tradle.keeper.error";

enum RNTradleKeeperError
{
  RNTradleKeeperNoError = 0,           // Never used
  RNTradleKeeperInvalidEncoding,
  RNTradleKeeperInvalidTarget,
  RNTradleKeeperInvalidDataProtection,
  RNTradleKeeperInvalidAlgorithm,
  RNTradleKeeperUnknownMimeType,
};

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

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

  NSString* key = [options objectForKey:@"key"];
  NSString* value = [options objectForKey:@"value"];
  NSString* encryptionPassword = [options objectForKey:@"encryptionPassword"];
  NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
  if ([options objectForKey:@"NSFileProtectionKey"]) {
    [attributes setValue:[options objectForKey:@"NSFileProtectionKey"] forKey:@"NSFileProtectionKey"];
  }

  NSError* error;
  [self encryptToFS:data password:encryptionPassword fileName:key error:&error];
  if (error != nil) {
    reject(@"encryption_error", [error localizedDescription], error);
    return;
  }

  if ([options objectForKey:@"cache"] != nil && [[options objectForKey:@"cache"] boolValue] == YES) {
    RCTImageStoreManager *manager = [self.bridge imageStoreManager];
    [manager storeImageData:data withBlock:^(NSString *imageTag) {
      resolve(@{
        @"imageTag": imageTag,
      });
    }];

    return;
  }

  resolve(nil);
}

- (NSURL*) encryptToFS:(NSData*) data
              password:(NSString*) password
              fileName:(NSString*) fileName
                 error:(NSError**) error {
  NSData *encrypted = [self encrypt:data withPassword:password error:error];
  if (error != nil) {
    return nil;
  }

  NSURL *base = [RNTradleKeeper applicationDocumentsDirectory];
  NSURL *filePath = [base URLByAppendingPathComponent:fileName];
  BOOL success = [encrypted writeToURL:filePath atomically:true];
  if (success) {
    return filePath;
  }

  return nil;
}

RCT_EXPORT_METHOD(get:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![self validateOptions:options reject:reject]) {
    return;
  }

  NSString* key = [options objectForKey:@"key"];
  NSString* encryptionPassword = [options objectForKey:@"encryptionPassword"];

  NSURL *base = [RNTradleKeeper applicationDocumentsDirectory];
  NSURL *filePath = [base URLByAppendingPathComponent:key];
  NSData *encrypted = [NSData dataWithContentsOfURL:filePath];
  NSError* error;
  NSData *data = [self decrypt:encrypted withPassword:encryptionPassword error:&error];
  if (error != nil) {
    reject(@"decryption_error", [error localizedDescription], error);
    return;
  }

  if ([options objectForKey:@"target"] != nil && [[options objectForKey:@"target"] isEqualToString:@"cache"]) {
    RCTImageStoreManager *manager = [self.bridge imageStoreManager];
    [manager storeImageData:data withBlock:^(NSString *imageTag) {
      resolve(@{
        @"imageTag": imageTag,
      });
    }];

    return;
  }

  return resolve([data base64EncodedDataWithOptions:0]);
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

  NSString* password = [options objectForKey:@"encryptionPassword"];
  NSString* imageTag = [options objectForKey:@"imageTag"];
  RCTImageStoreManager *manager = [self.bridge imageStoreManager];
  [manager getImageDataForTag:imageTag withBlock:^(NSData *data) {
    if (data == nil) {
      reject(@"image_not_found", imageTag, nil);
      return;
    }

    NSString* algorithm = [self getSpecifiedAlgorithm:options];
    NSError* error;
    NSString* key = [self hashData:data options:options error:&error];
    if (error != nil) {
      reject(@"hash_error", [error localizedDescription], error);
      return;
    }

    [self encryptToFS:data password:password fileName:key error:&error];
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

//- (RCTImageStoreManager*) getImageStore {
//  return [self.bridge imageStoreManager]
//}

+ (RNCryptorSettings) getEncryptionSettings {
  return kRNCryptorAES256Settings;
}

- (NSData*) encrypt:(NSData*) data withPassword:(NSString*) password error:(NSError**) error {
  RNCryptorSettings settings = [RNTradleKeeper getEncryptionSettings];
  EncryptionMaterial *material = [self getEncryptionMaterial:password];
  return [RNEncryptor encryptData:data
                     withSettings:settings
                    encryptionKey:material.encryptionKey
                          HMACKey:material.hmacKey
                            error:error];
}

- (NSData*) decrypt:(NSData*) data withPassword:(NSString*) password error:(NSError**) error {
  EncryptionMaterial *material = [self getEncryptionMaterial:password];
  return [RNDecryptor decryptData:data
                withEncryptionKey:material.encryptionKey
                          HMACKey:material.hmacKey
                            error:error];
}

- (EncryptionMaterial*) getEncryptionMaterial:(NSString*) password {
  if ([encCache objectForKey:password] == nil) {
    RNCryptorSettings settings = [RNTradleKeeper getEncryptionSettings];
    EncryptionMaterial *material = [EncryptionMaterial alloc];
    NSData* encryptionSalt = [RNCryptor randomDataOfLength:settings.keySettings.saltSize];
    NSData* HMACSalt = [RNCryptor randomDataOfLength:settings.HMACKeySettings.saltSize];
    material.encryptionKey = [RNCryptor keyForPassword:password salt:encryptionSalt settings:settings.keySettings];
    material.hmacKey = [[self class] keyForPassword:password salt:HMACSalt settings:settings.HMACKeySettings];
    [encCache setObject:material forKey:password];
  }

  return [encCache objectForKey:password];
}

- (BOOL) validateOptions:(NSDictionary* )options reject: (RCTPromiseRejectBlock)reject {
  if ([options objectForKey:@"encoding"] != nil && ![@"utf8" isEqualToString:[options objectForKey:@"encoding"]]) {
    reject(@"invalid_encoding", @"only utf8 supported at the moment", nil);
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
      ![@"cache" isEqualToString:[options objectForKey: @"target"]]) {
//    NSError* error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperInvalidTarget userInfo:nil];
    reject(@"invalid_target", @"expected 'base64' or 'cache'", nil);
    return false;
  }

  return true;
}

//- (NSString*) importFromImageStore:(NSDictionary*) options  {
//
//}

//- (NSStringEncoding) getSpecifiedEncoding:(NSDictionary *)options {
//  // TODO: parse from options.encoding
//  return NSUTF8StringEncoding;
////  if ([options objectForKey:@"encoding"] == nil || [[options objectForKey:@"encoding"] isEqualToString:@"utf8"]) {
////    return NSUTF8StringEncoding;
////  }
//}

- (NSString*) getSpecifiedAlgorithm:(NSDictionary*) options {
  if ([options objectForKey:@"algorithm"]) {
    return @"sha256";
  }

  return [options objectForKey:@"algorithm"];
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

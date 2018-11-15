
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

static NSString* const RNTradleKeeperErrorDomain = @"tradle.keeper.error";
static NSString* const RNTradleKeeperOptDigestAlgorithm = @"digestAlgorithm";
static NSString* const RNTradleKeeperOptKey = @"key";
static NSString* const RNTradleKeeperOptValue = @"value";
static NSString* const RNTradleKeeperOptEncoding = @"encoding";
static NSString* const RNTradleKeeperOptEncryptionKey = @"encryptionKey";
static NSString* const RNTradleKeeperOptHMACKey = @"hmacKey";
static NSString* const RNTradleKeeperOptImageTag = @"imageTag";
static NSString* const RNTradleKeeperOptHashDataUrl = @"hashDataUrl";
static NSString* const RNTradleKeeperEncodingUTF8 = @"utf8";
static NSString* const RNTradleKeeperEncodingBase64 = @"base64";

enum RNTradleKeeperError
{
  RNTradleKeeperNoError = 0,           // Never used
  RNTradleKeeperInvalidAlgorithm,
  RNTradleKeeperUnknownMimeType,
  RNTradleKeeperWriteFailed,
};

//static NSMutableDictionary<NSString*, EncryptionMaterial*> *encCache;

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
  if ([options objectForKey:RNTradleKeeperOptKey] == nil) {
    key = [self hashData:data options:options error:error];
  } else {
    key = [options objectForKey:RNTradleKeeperOptKey];
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
    return key;
  }

  *error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperWriteFailed userInfo:nil];
  return nil;
}

//RCT_EXPORT_METHOD(test)
//{
//  NSString* input = @"321771419b82d51bde71f4bffe27e5235455c49641442d36093b4ee80bbe54a9";
//  NSData* data = [RNTradleKeeper hexToBytes:input];
//  NSLog(@"length %d", (int)[data length]);
//  NSString *recovered = [RNTradleKeeper bytesToHex:data];
//  NSLog(@"recovered %@", recovered);
//  BOOL equal = [recovered isEqualToString:input];
//  NSLog(@"yay? %o", equal);

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
  NSString* key = [options objectForKey:RNTradleKeeperOptKey];
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
  if ([RNTradleKeeper shouldReturnBase64:options]) {
    [result setObject:[data base64EncodedDataWithOptions:0] forKey:@"base64"];
  }

  if ([RNTradleKeeper shouldAddToImageCache:options]) {
    RCTImageStoreManager *manager = [self getImageStore];
    [manager storeImageData:data withBlock:^(NSString *imageTag) {
      [result setObject:imageTag forKey:RNTradleKeeperOptImageTag];
      resolve(result);
    }];

    return;
  }

  return resolve([NSDictionary dictionaryWithDictionary:result]);
}

RCT_EXPORT_METHOD(importFromImageStore:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString* imageTag = [options objectForKey:RNTradleKeeperOptImageTag];
  RCTImageStoreManager *manager = [self getImageStore];
  [manager getImageDataForTag:imageTag withBlock:^(NSData *data) {
    if (data == nil) {
      reject(@"image_not_found", imageTag, nil);
      return;
    }

    NSError* error;
    NSString* key = [self encryptToFS:data options:options error:&error];
    if (error != nil) {
      reject(@"encryption_error", [error localizedDescription], error);
      return;
    }

    resolve(@{
      @"key": key,
      @"mimeType": [RNTradleKeeper mimeTypeForData:data],
    });
  }];
}

RCT_EXPORT_METHOD(removeFromImageStore:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString* imageTag = [options objectForKey:RNTradleKeeperOptImageTag];
  RCTImageStoreManager *manager = [self getImageStore];
  [manager removeImageForTag:imageTag withBlock:^(void) {
    resolve(nil);
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

+ (NSData*) getHexOptionAsData:(NSDictionary*) options key:(NSString*)key {
  NSString* hex = [options objectForKey:key];
  return [RNTradleKeeper hexToBytes:hex];
}

+ (NSData *)hexToBytes:(NSString*)hex {
  const char *chars = [hex UTF8String];
  int i = 0, len = (int)[hex length];

  NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
  char byteChars[3] = {'\0','\0','\0'};
  unsigned long wholeByte;

  while (i < len) {
    byteChars[0] = chars[i++];
    byteChars[1] = chars[i++];
    wholeByte = strtoul(byteChars, NULL, 16);
    [data appendBytes:&wholeByte length:1];
  }

  return data;
}

// https://stackoverflow.com/questions/1305225/best-way-to-serialize-an-nsdata-into-a-hexadeximal-string
+ (NSString *)bytesToHex:(NSData*)data {
  NSUInteger dataLength = [data length];
  const unsigned char *dataBuffer = [data bytes];
  if (!dataBuffer)
    return [NSString string];

  NSMutableString *hex = [NSMutableString stringWithCapacity:(dataLength * 2)];
  for (int i = 0; i < dataLength; ++i)
    [hex appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];

  return [NSString stringWithString:hex];
}

- (NSData*) encrypt:(NSData*)data options:(NSDictionary*) options error:(NSError**) error {
  return [self encrypt:data
     withEncryptionKey:[RNTradleKeeper getHexOptionAsData:options key:RNTradleKeeperOptEncryptionKey]
          withHMACKey:[RNTradleKeeper getHexOptionAsData:options key:RNTradleKeeperOptHMACKey]
                 error:error];
}

- (NSData*) decrypt:(NSData*)data options:(NSDictionary*) options error:(NSError**) error {
  return [self decrypt:data
     withEncryptionKey:[RNTradleKeeper getHexOptionAsData:options key:RNTradleKeeperOptEncryptionKey]
           withHMACKey:[RNTradleKeeper getHexOptionAsData:options key:RNTradleKeeperOptHMACKey]
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

//- (BOOL) requireOption:(NSDictionary* )options key:(NSString*)key reject: (RCTPromiseRejectBlock)reject {
//  if ([options objectForKey:key] == nil) {
//    reject(@"invalid_option", [NSString stringWithFormat:@"missing option %@",key], nil);
//    return false;
//  }
//
//  return true;
//}
//
//- (BOOL) requireOptions:(NSDictionary* )options required:(NSArray*)required reject: (RCTPromiseRejectBlock)reject {
//  for (NSString* key in required) {
//    if (![self requireOption:options key:key reject:reject]) {
//      return false;
//    }
//  }
//
//  return true;
//}
//
//- (BOOL) requireEncryptionOptions:(NSDictionary* )options reject: (RCTPromiseRejectBlock)reject {
//  return [self requireOptions:options required:@[@"encryptionKey", @"hmacKey"] reject:reject];
//}

//- (NSString*) importFromImageStore:(NSDictionary*) options  {
//
//}

- (NSData*) parseValueData:(NSDictionary*) options {
  NSString* value = [options objectForKey:RNTradleKeeperOptValue];
  NSString* encoding = [options objectForKey:RNTradleKeeperOptEncoding];
  if ([encoding isEqualToString:RNTradleKeeperEncodingUTF8]) {
    return [value dataUsingEncoding:NSUTF8StringEncoding];
  }

  return [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters];
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
  NSString* algorithm = [options objectForKey:RNTradleKeeperOptDigestAlgorithm];
  if ([RNTradleKeeper getBoolOption:options option:RNTradleKeeperOptHashDataUrl]) {
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


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
static NSString* const RNTradleKeeperOptHashInput = @"hashInput";
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

  if ([RNTradleKeeper shouldAddToImageStore:options]) {
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
  NSString *key;
  NSError *opError;
  if ([options objectForKey:RNTradleKeeperOptKey] == nil) {
    key = [self hashData:data options:options error:&opError];
    if (opError != nil) {
      *error = opError;
      return nil;
    }
  } else {
    key = [options objectForKey:RNTradleKeeperOptKey];
  }

  NSData *encrypted = [self encrypt:data
                            options:options
                              error:&opError];

  if (opError != nil) {
    *error = opError;
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
  if (encrypted == nil) {
    reject(@"not_found", [NSString stringWithFormat:@"value not found for key %@", key], nil);
    return;
  }

  NSError* error;
  NSData *data = [self decrypt:encrypted options:options error:&error];
  if (error != nil) {
    reject(@"decryption_error", [error localizedDescription], error);
    return;
  }

  NSMutableDictionary* result = [NSMutableDictionary new];
  if ([RNTradleKeeper shouldReturnValue:options]) {
    [result setObject:[RNTradleKeeper encodeToString:data options:options] forKey:@"value"];
  }

  if ([RNTradleKeeper shouldAddToImageStore:options]) {
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
      @"length": @([data length]),
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
    case 0x89:
      return @"image/png";
    case 0x47:
      return @"image/gif";
    case 0x49:
    case 0x4D:
      return @"image/tiff";
    case 0x25:
      return @"application/pdf";
    case 0xD0:
      return @"application/vnd";
    case 0x46:
      return @"text/plain";
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

+ (NSString*) encodeToString:(NSData*) data options:(NSDictionary*) options {
  NSString* encoding = [options objectForKey:RNTradleKeeperOptEncoding];
  if ([encoding isEqualToString:RNTradleKeeperEncodingUTF8]) {
    // assumes data is not null-terminated
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  }

  return [data base64EncodedStringWithOptions:0];
}

+ (NSDictionary*) encodeData:(NSData*)data options:(NSDictionary*) options {
  return @{
    @"value": [RNTradleKeeper encodeToString:data options:options],
    @"encoding": [options objectForKey:RNTradleKeeperOptEncoding],
  };
}

+ (BOOL) shouldAddToImageStore:(NSDictionary*) options {
  return [RNTradleKeeper getBoolOption:options option:@"addToImageStore"];
}

+ (BOOL) shouldReturnValue:(NSDictionary*) options {
  return [RNTradleKeeper getBoolOption:options option:@"returnValue"];
}

+ (BOOL) getBoolOption:(NSDictionary*) options option:(NSString*) option {
  return [options objectForKey:option] == nil ? false : [[options objectForKey:option] boolValue];
}

+ (BOOL) getBoolOption:(NSDictionary*) options option:(NSString*) option defaultValue:(BOOL)defaultValue {
  return [options objectForKey:option] == nil ? defaultValue : [[options objectForKey:option] boolValue];
}

- (NSString*) hashData:(NSData *)data
                  options:(NSDictionary *)options
                  error:(NSError**) error
{
  NSString* algorithm = [options objectForKey:RNTradleKeeperOptDigestAlgorithm];
  NSError* getHashInputError;
  data = [self getHashInputData:data options:options error:&getHashInputError];
  if (getHashInputError != nil) {
    *error = getHashInputError;
    return nil;
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
  const void *bytes = data.bytes;
  CC_LONG dataLength = (CC_LONG)data.length;
  if ([algorithm isEqualToString:@"md5"]) {
    CC_MD5(bytes, dataLength, buffer);
  } else if ([algorithm isEqualToString:@"sha1"]) {
    CC_SHA1(bytes, dataLength, buffer);
  } else if ([algorithm isEqualToString:@"sha224"]) {
    CC_SHA224(bytes, dataLength, buffer);
  } else if ([algorithm isEqualToString:@"sha256"]) {
    CC_SHA256(bytes, dataLength, buffer);
  } else if ([algorithm isEqualToString:@"sha384"]) {
    CC_SHA384(bytes, dataLength, buffer);
  } else if ([algorithm isEqualToString:@"sha512"]) {
    CC_SHA512(bytes, dataLength, buffer);
  } else {
    *error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperInvalidAlgorithm userInfo:nil];
    return nil;
  }

  NSMutableString *output = [NSMutableString stringWithCapacity:digestLength * 2];
  for(int i = 0; i < digestLength; i++)
    [output appendFormat:@"%02x",buffer[i]];

  return output;
}

- (NSData*) getHashInputData:(NSData*) rawInput options:(NSDictionary*)options error:(NSError**) error {
  NSString* hashInputType = [options objectForKey:RNTradleKeeperOptHashInput];
  if (hashInputType != nil && [hashInputType isEqualToString:@"dataUrlForValue"]) {
    NSString* dataUrl = [RNTradleKeeper getDataUrl:rawInput error:error];
    return [dataUrl dataUsingEncoding:NSUTF8StringEncoding];
  }

  return rawInput;
}

@end

@implementation RCTBridge (RNTradleKeeper)

- (RNTradleKeeper *)tradleKeeper
{
  return [self moduleForClass:[RNTradleKeeper class]];
}

@end

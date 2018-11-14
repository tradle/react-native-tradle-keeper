//
//  RNTradleKeeperCrypto.m
//  RNTradleKeeper
//
//  Created by Mark Vayngrib on 11/13/18.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RNTradleKeeperCrypto.h"

@implementation RNTradleKeeperCrypto

#pragma mark - Private constants

static NSString* const RNTradleKeeperCryptoErrorDomain = @"tradle.keeper.crypto.error";

enum RNTradleKeeperCryptoError
{
  RNTradleKeeperCryptoNoError = 0,           // Never used
  RNTradleKeeperCryptoNoSuchCipher,          // Invalid hash algorithm
};

#pragma mark - Public methods

//+ (NSData*) encryptWithCipher:(NSString *)cipherName
//                  data:(NSString *) base64Plaintext
//                  key:(NSString *)base64Key
//                error:(NSError**) error
//{
//  if ([cipherName caseInsensitiveCompare:@"aes-256-cbc"] != NSOrderedSame) {
//    *error = [NSError errorWithDomain:RNTradleKeeperErrorDomain code:RNTradleKeeperCryptoNoSuchCipher userInfo:nil];
//    return;
//  }
//
//  NSData *data = [[NSData alloc] initWithBase64EncodedString:base64Plaintext options:0];
//  NSData *key = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
//  NSData *iv = nil;
//  NSData* cipherData = [RNAES encryptData:data key:key iv:&iv error:&error];
//  if (error) {
//    return;
//  }
//
//  return @{
//    @"iv": iv,
//    @"ciphertext": cipherData
//  }
//}
//
+ (NSData*) encodeEncryptionResult:(NSData*)ciphertext iv:(NSData*) iv {
  NSArray *pieces = [NSArray arrayWithObjects:ciphertext, iv, nil];
  return [RNTradleKeeperCrypto lengthEncode:pieces];
}

+ (NSArray*) decodeDecryptionResult:(NSData*) data {
  return [RNTradleKeeperCrypto lengthDecode:data];
}

+ (NSData*) lengthEncode:(NSArray*)pieces
{
  NSInteger size = 0;
  for (NSData *data in pieces) {
    size += [data length];
  }

  NSMutableData *encoded = [NSMutableData dataWithLength:size];
  for (NSData *data in pieces) {
    NSUInteger len = data.length;
    NSData *lenBytes = [RNTradleKeeperCrypto dataFromInt:(int)len];
    [encoded appendData:lenBytes];
    [encoded appendData:data];
  }

  return [NSData dataWithData:encoded];
}

+ (NSArray*) lengthDecode:(NSData*)encoded {
  NSMutableArray *decoded = [NSArray init];
  NSUInteger offset = 0;
  NSUInteger len = [encoded length];
  while (offset < len) {
    NSData *pieceLenBytes = [NSData dataWithBytesNoCopy:(char *)[encoded bytes] + offset
                                                 length:4
                                           freeWhenDone:YES];
    offset += 4;
    int pieceLen = [RNTradleKeeperCrypto intFromData:pieceLenBytes];
    NSData *piece = [NSData dataWithBytesNoCopy:(char *)[encoded bytes] + offset
                                                 length:pieceLen
                                           freeWhenDone:YES];

    [decoded addObject:piece];
    offset += pieceLen;
  }

  return [NSArray arrayWithArray:decoded];
}

+ (NSData *) dataFromInt:(int)num {
  return [NSData dataWithBytes: &num length: 4];
}

+ (int) intFromData:(NSData *)data
{
  int i;
  [data getBytes: &i length: 4];
  return i;
}

//RCT_EXPORT_METHOD(decryptWithCipher:(NSString *)cipherName
//                  data: base64Str
//                  key:(NSString *)base64Key
//                  iv:(NSString *)base64IV
//                  callback:(RCTResponseSenderBlock)callback)
//{
//  if ([cipherName caseInsensitiveCompare:@"aes-256-cbc"] != NSOrderedSame) {
//    NSString* errMsg = [NSString stringWithFormat:@"cipher %@ not supported", cipherName];
//    callback(@[errMsg]);
//    return;
//  }
//
//  NSData *data = [[NSData alloc] initWithBase64EncodedString:base64Str options:0];
//  NSData *iv = [[NSData alloc] initWithBase64EncodedString:base64IV options:0];
//  NSData *key = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
//  NSError *error = nil;
//  NSData* plaintext = [RNAES decryptData:data key:key iv:iv error:&error];
//  if (error) {
//    NSString* msg = [[error userInfo] valueForKey:@"NSLocalizedFailureReason"];
//    callback(@[msg]);
//  } else {
//    NSString * base64Plaintext = [plaintext base64EncodedStringWithOptions:0];
//    callback(@[[NSNull null], base64Plaintext]);
//  }
//}
//
//+ (NSData *)encryptData:(NSData *)data
//key:(NSData *)key
//iv:(NSData **)iv
//error:(NSError **)error {
//  NSAssert(iv, @"IV must not be NULL");
//
//  *iv = [self randomDataOfLength:kAlgorithmIVSize];
//
//  size_t outLength;
//  NSMutableData *
//  cipherData = [NSMutableData dataWithLength:data.length +
//                kAlgorithmBlockSize];
//
//  CCCryptorStatus
//  result = CCCrypt(kCCEncrypt, // operation
//                   kAlgorithm, // Algorithm
//                   kCCOptionPKCS7Padding, // options
//                   key.bytes, // key
//                   key.length, // keylength
//                   (*iv).bytes,// iv
//                   data.bytes, // dataIn
//                   data.length, // dataInLength,
//                   cipherData.mutableBytes, // dataOut
//                   cipherData.length, // dataOutAvailable
//                   &outLength); // dataOutMoved
//
//  if (result == kCCSuccess) {
//    cipherData.length = outLength;
//  }
//  else {
//    if (error) {
//      *error = [NSError errorWithDomain:kRNAESErrorDomain
//                                   code:result
//                               userInfo:nil];
//    }
//    return nil;
//  }
//
//  return cipherData;
//}
//
//+ (NSData *)decryptData:(NSData *)data
//key:(NSData *)key
//iv:(NSData *)iv
//error:(NSError **)error {
//  NSAssert(iv, @"IV must not be NULL");
//
//  size_t outLength;
//  NSMutableData *plaintext = [NSMutableData dataWithLength:data.length + kAlgorithmBlockSize];
//
//  CCCryptorStatus
//  result = CCCrypt(kCCDecrypt, // operation
//                   kAlgorithm, // Algorithm
//                   kCCOptionPKCS7Padding, // options
//                   key.bytes, // key
//                   key.length, // keylength
//                   iv.bytes,// iv
//                   data.bytes, // dataIn
//                   data.length, // dataInLength,
//                   plaintext.mutableBytes, // dataOut
//                   plaintext.length, // dataOutAvailable
//                   &outLength); // dataOutMoved
//
//  if (result == kCCSuccess) {
//    plaintext.length = outLength;
//  }
//  else {
//    if (error) {
//      *error = [NSError errorWithDomain:kRNAESErrorDomain
//                                   code:result
//                               userInfo:nil];
//    }
//    return nil;
//  }
//
//  return plaintext;
//}
//
//// ===================
//
//+ (NSData *)randomDataOfLength:(size_t)length {
//  NSMutableData *data = [NSMutableData dataWithLength:length];
//
//  int result = SecRandomCopyBytes(kSecRandomDefault,
//                                  length,
//                                  data.mutableBytes);
//  NSAssert(result == 0, @"Unable to generate random bytes: %d",
//           errno);
//
//  return data;
//}


@end

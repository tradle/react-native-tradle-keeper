
#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#else
#import "RCTBridgeModule.h"
#endif

#if __has_include(<React/RCTImageStoreManager.h>)
#import <React/RCTImageStoreManager.h>
#else
#import RCTImageStoreManager.h
#endif

@interface RNTradleKeeper : NSObject <RCTBridgeModule>

@end
  

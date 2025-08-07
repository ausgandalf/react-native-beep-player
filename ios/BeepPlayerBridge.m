#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(BeepPlayer, NSObject)

RCT_EXTERN_METHOD(start:(nonnull NSNumber *)bpm beepFile:(NSString *)beepFile)
RCT_EXTERN_METHOD(stop)
RCT_EXTERN_METHOD(mute:(BOOL)value)

@end

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeTuningProcessorBridge : NSObject

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                        windowSize:(NSInteger)windowSize
                           hopSize:(NSInteger)hopSize NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)updateConfigurationWithPresetId:(NSString *)presetId
                             presetName:(NSString *)presetName
                             instrument:(NSString *)instrument
                                  notes:(NSArray<NSString *> *)notes
                                   mode:(NSString *)mode
                      manualStringIndex:(nullable NSNumber *)manualStringIndex
                           a4ReferenceHz:(double)a4ReferenceHz
                    tuningToleranceCents:(double)tuningToleranceCents
                              sensitivity:(NSString *)sensitivity
                                  error:(NSError * _Nullable * _Nullable)error;

- (NSArray<NSDictionary<NSString *, id> *> *)processSamples:(const float *)samples
                                                      count:(NSInteger)count;

- (void)reset;

@end

NS_ASSUME_NONNULL_END

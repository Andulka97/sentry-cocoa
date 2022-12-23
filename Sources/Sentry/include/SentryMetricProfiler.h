#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryNSProcessInfoWrapper;
@class SentryNSTimerWrapper;
@class SentrySystemWrapper;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryPressure;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyPowerState;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyThermalState;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyCPUUsageFormat;

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitBytes;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitBoolean;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitMemoryPressureEnum;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitThermalStateEnum;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitPercentage;

/**
 * A profiler that gathers various time-series and event-based metrics on the app process, such as
 * CPU and memory usage timeseries and thermal and memory pressure warning notifications.
 */
@interface SentryMetricProfiler : NSObject

- (instancetype)initWithProfileStartTime:(uint64_t)profileStartTime
                      processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
                           systemWrapper:(SentrySystemWrapper *)systemWrapper
                            timerWrapper:(SentryNSTimerWrapper *)timerWrapper;
- (void)start;
- (void)stop;

/**
 * Return a serialized dictionary of the collected metrics.
 *
 * The dictionary will have the following structure:
 * @code
 * @"<metric-name>": @{
 *      @"unit": @"<unit-name>",
 *      @"values": @[
 *          @"elapsed_since_start_ns": @"<64-bit-unsigned-timestamp>",
 *          @"value": @"<numeric-value>"
 *      ]
 * }
 * @endcode
 */
- (NSMutableDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

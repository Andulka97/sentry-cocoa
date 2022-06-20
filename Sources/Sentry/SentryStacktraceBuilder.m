#import "SentryStacktraceBuilder.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_MachineContext.h"
#import "SentryCrashStackCursor_SelfThread.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryFrameRemover.h"
#import "SentryStacktrace.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryStacktraceBuilder ()

@property (nonatomic, strong) SentryCrashStackEntryMapper *crashStackEntryMapper;

@end

@implementation SentryStacktraceBuilder

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper
{
    if (self = [super init]) {
        self.crashStackEntryMapper = crashStackEntryMapper;
    }
    return self;
}

- (SentryStacktrace *)retrieveStacktraceFromCursor:(SentryCrashStackCursor)stackCursor
{
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray new];
    SentryFrame *frame = nil;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (stackCursor.symbolicate(&stackCursor)) {
            if (stackCursor.stackEntry.address == SentryCrashSC_ASYNC_MARKER) {
                if (frame != nil) {
                    frame.stackStart = @(YES);
                }
                // skip the marker frame
                continue;
            }
            frame = [self.crashStackEntryMapper mapStackEntryWithCursor:stackCursor];
            [frames addObject:frame];
        }
    }
    sentrycrash_async_backtrace_decref(stackCursor.async_caller);

    NSArray<SentryFrame *> *framesCleared = [SentryFrameRemover removeNonSdkFrames:frames];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[framesCleared reverseObjectEnumerator] allObjects];

    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:framesReversed
                                                                  registers:@{}];

    return stacktrace;
}

- (SentryStacktrace *)buildStacktraceForThread:(SentryCrashThread)thread
{
    SentryCrashMC_NEW_CONTEXT(machineContext);
    sentrycrashmc_getContextForThread(thread, machineContext, false);
    SentryCrashStackCursor stackCursor;
    sentrycrashsc_initWithMachineContext(&stackCursor, 100, machineContext);

    return [self retrieveStacktraceFromCursor:stackCursor];
}

- (SentryStacktrace *)buildStacktraceForCurrentThread
{
    SentryCrashStackCursor stackCursor;
    // We don't need to skip any frames, because we filter out non sentry frames below.
    NSInteger framesToSkip = 0;
    sentrycrashsc_initSelfThread(&stackCursor, (int)framesToSkip);

    return [self retrieveStacktraceFromCursor:stackCursor];
}

@end

NS_ASSUME_NONNULL_END

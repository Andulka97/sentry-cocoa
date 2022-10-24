#import "SentryProcessInfo.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

static const int kSentryBenchmarkIterations = 5;

// TODO: add @"Render image", @"Scroll UITableView", @"Network download", @"Network upload",
// @"Network stream up", @"Network stream down", @"Network stream mixed", @"WebKit render",
// @"Load empty DB", @"Load DB with entities", @"Create entity", @"Fetch entity", @"Update
// entity", @"Delete entity", @"Data encrypt" after implementing them in
// BenchmarkingViewController
@interface SentrySDKPerformanceBenchmarkTests : XCTestCase

@end

@implementation SentrySDKPerformanceBenchmarkTests

- (void)testFileWrite
{
    [self performSelectedBenchmark:@"File write"];
}

- (void)testFileRead
{
    [self performSelectedBenchmark:@"File read"];
}

- (void)testFileCopy
{
    [self performSelectedBenchmark:@"File copy"];
}

- (void)testFileDelete
{
    [self performSelectedBenchmark:@"File delete"];
}

- (void)testCPUWork
{
    [self performSelectedBenchmark:@"CPU work"];
}

- (void)testCPUIdle
{
    [self performSelectedBenchmark:@"CPU idle"];
}

- (void)testDataCompression
{
    [self performSelectedBenchmark:@"Data compression"];
}

- (void)testDataSHA1Sum
{
    [self performSelectedBenchmark:@"Data SHA1 sum"];
}

- (void)testJSONEncode
{
    [self performSelectedBenchmark:@"JSON Encode"];
}

- (void)testJSONDecode
{
    [self performSelectedBenchmark:@"JSON Decode"];
}

#pragma mark - Private

- (void)performSelectedBenchmark:(NSString *)benchmark
{
    //    XCTSkipIf(isSimulator() && !isDebugging());

    XCUIApplication *app = [[XCUIApplication alloc] init];
    app.launchArguments =
        [app.launchArguments arrayByAddingObject:@"--io.sentry.test.benchmarking"];
    [app launch];
    [app.buttons[@"Benchmarks"] tap];

    NSMutableArray *results = [NSMutableArray array];
    for (NSUInteger j = 0; j < kSentryBenchmarkIterations; j++) {
        const auto cpuWorkRow = app.staticTexts[benchmark];
        if (![cpuWorkRow waitForExistenceWithTimeout:5.0]) {
            XCTFail(@"Couldn't select scenario.");
        }
        [cpuWorkRow tap];

        // After navigating to the test, the test app will do some work. Meanwhile the profiler does
        // its thing, and the benchmarking observation in the test app records how much CPU time is
        // used on the profiler thread as well as the rest of the app.

        XCUIElement *textField = app.textFields[@"io.sentry.benchmark.value-marshaling-text-field"];
        if (![textField waitForExistenceWithTimeout:5.0]) {
            XCTFail(@"Couldn't find benchmark value marshaling text field.");
        }

        NSString *benchmarkValueString = textField.value;
        // SentryBenchmarking.retrieveBenchmarks returns nil if there aren't at least 2 samples to
        // use for calculating deltas
        XCTAssertFalse([benchmarkValueString isEqualToString:@"nil"],
            @"Failure to record enough CPU samples to calculate benchmark.");
        if (benchmarkValueString == nil) {
            XCTFail(@"No benchmark value received from the app.");
        }

        NSArray *values = [benchmarkValueString componentsSeparatedByString:@","];

        NSInteger profilerSystemTime = [values[0] integerValue];
        NSInteger profilerUserTime = [values[1] integerValue];
        NSInteger appSystemTime = [values[2] integerValue];
        NSInteger appUserTime = [values[3] integerValue];

        NSLog(@"[Sentry Benchmark] [%@] %ld,%ld,%ld,%ld", benchmark, (long)profilerSystemTime,
            (long)profilerUserTime, (long)appSystemTime, (long)appUserTime);

        double usagePercentage
            = 100.0 * (profilerUserTime + profilerSystemTime) / (appUserTime + appSystemTime);

        XCTAssertNotEqual(usagePercentage, 0, @"Overhead percentage should be > 0%%");

        [results addObject:@(usagePercentage)];

        const auto okButton = app.buttons[@"OK"];
        if (![okButton waitForExistenceWithTimeout:5.0]) {
            XCTFail(@"Couldn't find OK button to dismiss results dialog.");
        }
        [okButton tap];
    }
}

@end

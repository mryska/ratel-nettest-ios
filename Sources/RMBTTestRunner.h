/*********************************************************************************
* Copyright 2013 appscape gmbh
* Copyright 2014-2015 SPECURE GmbH
* 
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
* 
*   http://www.apache.org/licenses/LICENSE-2.0
* 
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*********************************************************************************/

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "RMBTConnectivity.h"

@class RMBTHistoryResult;

typedef NS_ENUM(NSInteger, RMBTTestRunnerPhase) {
    RMBTTestRunnerPhaseNone = 0,
    RMBTTestRunnerPhaseFetchingTestParams,
    RMBTTestRunnerPhaseWait,
    RMBTTestRunnerPhaseInit,
    RMBTTestRunnerPhaseLatency,
    RMBTTestRunnerPhaseDown,
    RMBTTestRunnerPhaseInitUp,
    RMBTTestRunnerPhaseUp,
    RMBTTestRunnerPhaseSubmittingTestResult
};

typedef NS_ENUM(NSInteger, RMBTTestRunnerCancelReason) {
    RMBTTestRunnerCancelReasonUserRequested,
    RMBTTestRunnerCancelReasonNoConnection,
    RMBTTestRunnerCancelReasonMixedConnectivity,
    RMBTTestRunnerCancelReasonErrorFetchingTestingParams,
    RMBTTestRunnerCancelReasonErrorSubmittingTestResult,
    RMBTTestRunnerCancelReasonAppBackgrounded
};

@protocol RMBTTestRunnerDelegate <NSObject>
- (void)testRunnerDidStartPhase:(RMBTTestRunnerPhase)phase;
- (void)testRunnerDidFinishPhase:(RMBTTestRunnerPhase)phase;

- (void)testRunnerDidUpdateProgress:(float)progress inPhase:(RMBTTestRunnerPhase)phase;
- (void)testRunnerDidMeasureThroughputs:(NSArray*)throughputs inPhase:(RMBTTestRunnerPhase)phase;

// These delegate methods will be called even before the test starts
- (void)testRunnerDidDetectConnectivity:(RMBTConnectivity*)connectivity;
- (void)testRunnerDidDetectLocation:(CLLocation*)location;

- (void)testRunnerDidCompleteWithResult:(RMBTHistoryResult*)result;
- (void)testRunnerDidCancelTestWithReason:(RMBTTestRunnerCancelReason)cancelReason;

@optional

- (void)testRunnerDidFinishInit:(uint64_t)time;

@end

@class RMBTTestParams;
@class RMBTTestResult;

@interface RMBTTestRunner : NSObject

@property(nonatomic, readonly) RMBTTestParams *testParams;
@property(nonatomic, readonly) RMBTTestResult *testResult;

- (id)initWithDelegate:(id<RMBTTestRunnerDelegate>)delegate;
- (void)start;
- (void)cancel;
@end
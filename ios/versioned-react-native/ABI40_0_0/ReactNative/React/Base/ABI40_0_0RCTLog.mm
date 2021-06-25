/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI40_0_0RCTLog.h"

#include <cxxabi.h>

#import <objc/message.h>
#import <os/log.h>

#import "ABI40_0_0RCTAssert.h"
#import "ABI40_0_0RCTBridge+Private.h"
#import "ABI40_0_0RCTBridge.h"
#import "ABI40_0_0RCTDefines.h"
#import "ABI40_0_0RCTRedBoxSetEnabled.h"
#import "ABI40_0_0RCTUtils.h"

static NSString *const ABI40_0_0RCTLogFunctionStack = @"ABI40_0_0RCTLogFunctionStack";

const char *ABI40_0_0RCTLogLevels[] = {
    "trace",
    "info",
    "warn",
    "error",
    "fatal",
};

/* os log will discard debug and info messages if they are not needed */
static const ABI40_0_0RCTLogLevel ABI40_0_0RCTDefaultLogThreshold = (ABI40_0_0RCTLogLevel)(ABI40_0_0RCTLogLevelInfo - 1);

static ABI40_0_0RCTLogFunction ABI40_0_0RCTCurrentLogFunction;
static ABI40_0_0RCTLogLevel ABI40_0_0RCTCurrentLogThreshold = ABI40_0_0RCTDefaultLogThreshold;

ABI40_0_0RCTLogLevel ABI40_0_0RCTGetLogThreshold()
{
  return ABI40_0_0RCTCurrentLogThreshold;
}

void ABI40_0_0RCTSetLogThreshold(ABI40_0_0RCTLogLevel threshold)
{
  ABI40_0_0RCTCurrentLogThreshold = threshold;
}

static os_log_type_t ABI40_0_0RCTLogTypeForLogLevel(ABI40_0_0RCTLogLevel logLevel)
{
  if (logLevel < ABI40_0_0RCTLogLevelInfo) {
    return OS_LOG_TYPE_DEBUG;
  } else if (logLevel <= ABI40_0_0RCTLogLevelWarning) {
    return OS_LOG_TYPE_INFO;
  } else {
    return OS_LOG_TYPE_ERROR;
  }
}

static os_log_t ABI40_0_0RCTLogForLogSource(ABI40_0_0RCTLogSource source)
{
  switch (source) {
    case ABI40_0_0RCTLogSourceNative: {
      static os_log_t nativeLog;
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        nativeLog = os_log_create("com.facebook.ABI40_0_0React.log", "native");
      });
      return nativeLog;
    }
    case ABI40_0_0RCTLogSourceJavaScript: {
      static os_log_t javaScriptLog;
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        javaScriptLog = os_log_create("com.facebook.ABI40_0_0React.log", "javascript");
      });
      return javaScriptLog;
    }
  }
}

ABI40_0_0RCTLogFunction ABI40_0_0RCTDefaultLogFunction =
    ^(ABI40_0_0RCTLogLevel level,
      ABI40_0_0RCTLogSource source,
      __unused NSString *fileName,
      __unused NSNumber *lineNumber,
      NSString *message) {
      os_log_with_type(ABI40_0_0RCTLogForLogSource(source), ABI40_0_0RCTLogTypeForLogLevel(level), "%{public}s", message.UTF8String);
    };

void ABI40_0_0RCTSetLogFunction(ABI40_0_0RCTLogFunction logFunction)
{
  ABI40_0_0RCTCurrentLogFunction = logFunction;
}

ABI40_0_0RCTLogFunction ABI40_0_0RCTGetLogFunction()
{
  if (!ABI40_0_0RCTCurrentLogFunction) {
    ABI40_0_0RCTCurrentLogFunction = ABI40_0_0RCTDefaultLogFunction;
  }
  return ABI40_0_0RCTCurrentLogFunction;
}

void ABI40_0_0RCTAddLogFunction(ABI40_0_0RCTLogFunction logFunction)
{
  ABI40_0_0RCTLogFunction existing = ABI40_0_0RCTGetLogFunction();
  if (existing) {
    ABI40_0_0RCTSetLogFunction(
        ^(ABI40_0_0RCTLogLevel level, ABI40_0_0RCTLogSource source, NSString *fileName, NSNumber *lineNumber, NSString *message) {
          existing(level, source, fileName, lineNumber, message);
          logFunction(level, source, fileName, lineNumber, message);
        });
  } else {
    ABI40_0_0RCTSetLogFunction(logFunction);
  }
}

/**
 * returns the topmost stacked log function for the current thread, which
 * may not be the same as the current value of ABI40_0_0RCTCurrentLogFunction.
 */
static ABI40_0_0RCTLogFunction ABI40_0_0RCTGetLocalLogFunction()
{
  NSMutableDictionary *threadDictionary = [NSThread currentThread].threadDictionary;
  NSArray<ABI40_0_0RCTLogFunction> *functionStack = threadDictionary[ABI40_0_0RCTLogFunctionStack];
  ABI40_0_0RCTLogFunction logFunction = functionStack.lastObject;
  if (logFunction) {
    return logFunction;
  }
  return ABI40_0_0RCTGetLogFunction();
}

void ABI40_0_0RCTPerformBlockWithLogFunction(void (^block)(void), ABI40_0_0RCTLogFunction logFunction)
{
  NSMutableDictionary *threadDictionary = [NSThread currentThread].threadDictionary;
  NSMutableArray<ABI40_0_0RCTLogFunction> *functionStack = threadDictionary[ABI40_0_0RCTLogFunctionStack];
  if (!functionStack) {
    functionStack = [NSMutableArray new];
    threadDictionary[ABI40_0_0RCTLogFunctionStack] = functionStack;
  }
  [functionStack addObject:logFunction];
  block();
  [functionStack removeLastObject];
}

void ABI40_0_0RCTPerformBlockWithLogPrefix(void (^block)(void), NSString *prefix)
{
  ABI40_0_0RCTLogFunction logFunction = ABI40_0_0RCTGetLocalLogFunction();
  if (logFunction) {
    ABI40_0_0RCTPerformBlockWithLogFunction(
        block, ^(ABI40_0_0RCTLogLevel level, ABI40_0_0RCTLogSource source, NSString *fileName, NSNumber *lineNumber, NSString *message) {
          logFunction(level, source, fileName, lineNumber, [prefix stringByAppendingString:message]);
        });
  }
}

NSString *
ABI40_0_0RCTFormatLog(NSDate *timestamp, ABI40_0_0RCTLogLevel level, NSString *fileName, NSNumber *lineNumber, NSString *message)
{
  NSMutableString *log = [NSMutableString new];
  if (timestamp) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      formatter = [NSDateFormatter new];
      formatter.dateFormat = formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS ";
    });
    [log appendString:[formatter stringFromDate:timestamp]];
  }
  if (level) {
    [log appendFormat:@"[%s]", ABI40_0_0RCTLogLevels[level]];
  }

  [log appendFormat:@"[tid:%@]", ABI40_0_0RCTCurrentThreadName()];

  if (fileName) {
    fileName = fileName.lastPathComponent;
    if (lineNumber) {
      [log appendFormat:@"[%@:%@]", fileName, lineNumber];
    } else {
      [log appendFormat:@"[%@]", fileName];
    }
  }
  if (message) {
    [log appendString:@" "];
    [log appendString:message];
  }
  return log;
}

NSString *ABI40_0_0RCTFormatLogLevel(ABI40_0_0RCTLogLevel level)
{
  NSDictionary *levelsToString = @{
    @(ABI40_0_0RCTLogLevelTrace) : @"trace",
    @(ABI40_0_0RCTLogLevelInfo) : @"info",
    @(ABI40_0_0RCTLogLevelWarning) : @"warning",
    @(ABI40_0_0RCTLogLevelFatal) : @"fatal",
    @(ABI40_0_0RCTLogLevelError) : @"error"
  };

  return levelsToString[@(level)];
}

NSString *ABI40_0_0RCTFormatLogSource(ABI40_0_0RCTLogSource source)
{
  NSDictionary *sourcesToString = @{@(ABI40_0_0RCTLogSourceNative) : @"native", @(ABI40_0_0RCTLogSourceJavaScript) : @"js"};

  return sourcesToString[@(source)];
}

static NSRegularExpression *nativeStackFrameRegex()
{
  static dispatch_once_t onceToken;
  static NSRegularExpression *_regex;
  dispatch_once(&onceToken, ^{
    NSError *regexError;
    _regex = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+ (.*) \\+ (\\d+)$"
                                                       options:0
                                                         error:&regexError];
    if (regexError) {
      ABI40_0_0RCTLogError(@"Failed to build regex: %@", [regexError localizedDescription]);
    }
  });
  return _regex;
}

void _ABI40_0_0RCTLogNativeInternal(ABI40_0_0RCTLogLevel level, const char *fileName, int lineNumber, NSString *format, ...)
{
  ABI40_0_0RCTLogFunction logFunction = ABI40_0_0RCTGetLocalLogFunction();
  BOOL log = ABI40_0_0RCT_DEBUG || (logFunction != nil);
  if (log && level >= ABI40_0_0RCTGetLogThreshold()) {
    // Get message
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // Call log function
    if (logFunction) {
      logFunction(
          level, ABI40_0_0RCTLogSourceNative, fileName ? @(fileName) : nil, lineNumber > 0 ? @(lineNumber) : nil, message);
    }

    // Log to red box if one is configured.
    if (ABI40_0_0RCTSharedApplication() && ABI40_0_0RCTRedBoxGetEnabled() && level >= ABI40_0_0RCTLOG_REDBOX_LEVEL) {
      NSArray<NSString *> *stackSymbols = [NSThread callStackSymbols];
      NSMutableArray<NSDictionary *> *stack = [NSMutableArray arrayWithCapacity:(stackSymbols.count - 1)];
      [stackSymbols enumerateObjectsUsingBlock:^(NSString *frameSymbols, NSUInteger idx, __unused BOOL *stop) {
        if (idx == 0) {
          // don't include the current frame
          return;
        }

        NSRange range = NSMakeRange(0, frameSymbols.length);
        NSTextCheckingResult *match = [nativeStackFrameRegex() firstMatchInString:frameSymbols options:0 range:range];
        if (!match) {
          return;
        }

        NSString *methodName = [frameSymbols substringWithRange:[match rangeAtIndex:1]];
        char *demangledName = abi::__cxa_demangle([methodName UTF8String], NULL, NULL, NULL);
        if (demangledName) {
          methodName = @(demangledName);
          free(demangledName);
        }

        if (idx == 1 && fileName) {
          NSString *file = [@(fileName) componentsSeparatedByString:@"/"].lastObject;
          [stack addObject:@{@"methodName" : methodName, @"file" : file, @"lineNumber" : @(lineNumber)}];
        } else {
          [stack addObject:@{@"methodName" : methodName}];
        }
      }];

      dispatch_async(dispatch_get_main_queue(), ^{
        // red box is thread safe, but by deferring to main queue we avoid a startup
        // race condition that causes the module to be accessed before it has loaded
        id redbox = [[ABI40_0_0RCTBridge currentBridge] moduleForName:@"RedBox" lazilyLoadIfNecessary:YES];
        if (redbox) {
          void (*showErrorMessage)(id, SEL, NSString *, NSMutableArray<NSDictionary *> *) =
              (__typeof__(showErrorMessage))objc_msgSend;
          SEL showErrorMessageSEL = NSSelectorFromString(@"showErrorMessage:withStack:");

          if ([redbox respondsToSelector:showErrorMessageSEL]) {
            showErrorMessage(redbox, showErrorMessageSEL, message, stack);
          }
        }
      });
    }

#if ABI40_0_0RCT_DEV
    if (!ABI40_0_0RCTRunningInTestEnvironment()) {
      // Log to JS executor
      [[ABI40_0_0RCTBridge currentBridge] logMessage:message level:level ? @(ABI40_0_0RCTLogLevels[level]) : @"info"];
    }
#endif
  }
}

void _ABI40_0_0RCTLogJavaScriptInternal(ABI40_0_0RCTLogLevel level, NSString *message)
{
  ABI40_0_0RCTLogFunction logFunction = ABI40_0_0RCTGetLocalLogFunction();
  BOOL log = ABI40_0_0RCT_DEBUG || (logFunction != nil);
  if (log && level >= ABI40_0_0RCTGetLogThreshold()) {
    if (logFunction) {
      logFunction(level, ABI40_0_0RCTLogSourceJavaScript, nil, nil, message);
    }
  }
}

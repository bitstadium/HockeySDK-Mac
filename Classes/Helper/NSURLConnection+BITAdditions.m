/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

// Based on Plausible Labs NSURLConnection+PLFoundation.m from https://opensource.plausible.coop/src/projects/PLF/repos/plfoundation-objc/browse/PLFoundation/NSURLConnection%2BPLFoundation.m

#import "NSURLConnection+BITAdditions.h"

@interface BITNSURLAsyncRequestHandler : NSObject <NSURLConnectionDataDelegate>
- (id) initWithRequest: (NSURLRequest *) request
 maximumResourceLength: (NSUInteger) maximumResourceLength
                 queue: (NSOperationQueue *) queue
     completionHandler: (void (^)(NSURLResponse *response, NSData *data, NSError *error)) handler;
@end


@implementation NSURLConnection (BITAdditions)


/**
 * A cancellable asynchronous replacement for +[NSURLConnection sendAsynchronousRequest:queue:cancelTicket:completionHandler:].
 *
 * @param request The URL request.
 * @parma queue The queue on which @a completionHandler should be dispatched.
 * @param handler The completion handler to execute. If the request completes successfully, the data parameter of the
 * handler block contains the resource data, and the error parameter is nil. If the request fails, the
 * data parameter will be nil, and the error parameter contain information about the failure.
 */
+ (void) bit_sendAsynchronousRequest: (NSURLRequest *)request
                               queue: (NSOperationQueue *)queue
                   completionHandler: (void (^)(NSURLResponse *response, NSData *data, NSError *error)) handler
{
  /* The instance handles scheduling and dispatch independently */
  [[BITNSURLAsyncRequestHandler alloc] initWithRequest: request
                                maximumResourceLength: NSUIntegerMax /* Maximum size of an NSData instance */
                                                queue: queue
                                    completionHandler: handler];
}

/**
 * A cancellable asynchronous replacement for +[NSURLConnection sendAsynchronousRequest:queue:cancelTicket:completionHandler:].
 *
 * @param request The URL request.
 * @param maximumResourceLength The maximum permitted length of the requested resource. If the resource exceeds this size, an error
 * will be returned to the completion handler.
 * @parma queue The queue on which @a completionHandler should be dispatched.
 * @param handler The completion handler to execute. If the request completes successfully, the data parameter of the
 * handler block contains the resource data, and the error parameter is nil. If the request fails, the
 * data parameter will be nil, and the error parameter contain information about the failure.
 */
+ (void) bit_sendAsynchronousRequest: (NSURLRequest *)request
               maximumResourceLength: (NSUInteger) maximumResourceLength
                               queue: (NSOperationQueue *) queue
                   completionHandler: (void (^)(NSURLResponse *response, NSData *data, NSError *error)) handler
{
  /* The instance handles scheduling and dispatch independently */
  [[BITNSURLAsyncRequestHandler alloc] initWithRequest: request
                                 maximumResourceLength: maximumResourceLength
                                                 queue: queue
                                     completionHandler: handler];
}


@end

/**
 * @internal
 * Manages NSURLConnection on background thread
 */
@implementation BITNSURLAsyncRequestHandler {
@private
  /** Target queue. */
  NSOperationQueue *_queue;

  /** Maximum number of bytes to download, or 0 if no limit. */
  NSUInteger _maximumResourceLength;
  
  /** Completion handler. */
  void (^_handler)(NSURLResponse *response, NSData *data, NSError *error);
  
  /** Received data. */
  NSMutableData *_dataBuffer;
  
  /** Received response. */
  NSURLResponse *_response;
}

/**
 * Initialize a new instance.
 *
 * @param request The URL request.
 * @param maximumResourceLength The maximum permitted length of the requested resource. If the resource exceeds this size, an error
 * will be returned to the completion handler.
 * @parma queue The queue on which @a completionHandler should be dispatched.
 * @param handler The completion handler to execute. If the request completes successfully, the data parameter of the
 * handler block contains the resource data, and the error parameter is nil. If the request fails, the
 * data parameter will be nil, and the error parameter contain information about the failure.
 */
- (id) initWithRequest: (NSURLRequest *) request
 maximumResourceLength: (NSUInteger) maximumResourceLength
                 queue: (NSOperationQueue *) queue
     completionHandler: (void (^)(NSURLResponse *response, NSData *data, NSError *error)) handler
{
  if ((self = [super init]) == nil) {
    return nil;
  }
  
  _maximumResourceLength = maximumResourceLength;
  _queue = queue;
  _handler = [handler copy];
  _dataBuffer = [NSMutableData data];
  
  /* Create and start the request; NSURLConnection will retain our instance for the duration
   * of the request. */
  NSURLConnection *c = [NSURLConnection connectionWithRequest: request delegate: self];
  [c start];
  
  return self;
}

// from NSURLConnectionDataDelegate protocol
- (void) connection: (NSURLConnection *) connection didReceiveResponse: (NSURLResponse *) response {
  _response = response;
}

// from NSURLConnectionDataDelegate protocol
- (void) connection: (NSURLConnection *) connection didReceiveData: (NSData *) data {
  [_dataBuffer appendData: data];
  if ([_dataBuffer length] > _maximumResourceLength) {
    [connection cancel];
    
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorDataLengthExceedsMaximum
                                     userInfo:nil];
    
    [self connection: connection didFailWithError: error];
  }
}

// from NSURLConnectionDelegate protocol
- (void)connection: (NSURLConnection *) connection didFailWithError: (NSError *) error {
  [_queue addOperation: [NSBlockOperation blockOperationWithBlock: ^{
    _handler(_response, nil, error);
  }]];
}

// from NSURLConnectionDataDelegate protocol
- (void) connectionDidFinishLoading: (NSURLConnection *) connection {
  [_queue addOperation: [NSBlockOperation blockOperationWithBlock: ^{
    _handler(_response, _dataBuffer, nil);
  }]];
}

@end

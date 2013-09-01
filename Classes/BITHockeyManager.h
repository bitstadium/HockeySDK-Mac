// 
//  Author: Andreas Linde <mail@andreaslinde.de>
// 
//  Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH. All rights reserved.
//  See LICENSE.txt for author information.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

@protocol BITCrashReportManagerDelegate;

/**
 * The HockeySDK manager. Responsible for setup and management of all components
 *
 * This is the principal SDK class. It represents the entry point for the HockeySDK. The main promises of the class are initializing the SDK 
 * modules, providing access to global properties and to all modules. Initialization is divided into several distinct phases:
 *
 * 1. Setup the [HockeyApp](http://hockeyapp.net/) app identifier and the optional delegate: This is the least required information on setting up the SDK and using it. It does some simple validation of the app identifier.
 * 2. Provides access to the SDK module `BITCrashManager`. This way all modules can be further configured to personal needs, if the defaults don't fit the requirements.
 * 3. Configure each module.
 * 4. Start up all modules.
 *
 * The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on startup can also be caught and each module executes other code with a delay some seconds. This ensures that applicationDidFinishLaunching will process as fast as possible and the SDK will not block the startup sequence resulting in a possible kill by the watchdog process.
 *
 * All modules do **NOT** show any user interface if the module is not activated or not integrated.
 * `BITCrashManager`: Shows an alert on startup asking the user if he/she agrees on sending the crash report, if `[BITCrashManager crashManagerStatus]` is set to `BITCrashManagerStatusAlwaysAsk` (default)
 *
 * @warning The SDK is **NOT** thread safe and has to be set up on the main thread!
 *
 * @warning You should **NOT** change any module configuration after calling `startManager`!
 *
 * Example:
 *    [[BITHockeyManager sharedHockeyManager]
 *      configureWithIdentifier:@"<AppIdentifierFromHockeyApp>"
 *      companyName:@"<YourCompanyName>"
 *      crashReportManagerDelegate:self];
 *    [[BITHockeyManager sharedHockeyManager] startManager];
 *
 */
@interface BITHockeyManager : NSObject {
@private
  NSString *_appIdentifier;
  NSString *_companyName;
  
  BOOL _loggingEnabled;
  BOOL _askUserDetails;
  
  NSTimeInterval _maxTimeIntervalOfCrashForReturnMainApplicationDelay;
}

#pragma mark - Public Properties

@property (nonatomic, readonly) NSString *appIdentifier;

/**
 *  Enable debug logging
 *
 *  This is intented for debugging purposes only if you want to check the data being
 *  send and received from HockeySDK and check if the SDK is giving any additional
 *  hints in case of problems.
 *
 *  Default: _NO_
 */
@property (nonatomic, assign, getter=isLoggingEnabled) BOOL loggingEnabled;


/**
 *  Defines if the user interface should ask for name and email
 *
 *  Default: _YES_
 */
@property (nonatomic, assign) BOOL askUserDetails;

/**
 *  Time between startup and a crash within which sending a crash will be send synchronously
 *
 *  By default crash reports are being send asynchronously, since otherwise it may block the
 *  app from startup, e.g. while the network is down and the crash report can not be send until
 *  the timeout occurs.
 *
 *  But especially crashes during app startup could be frequent to the affected user and if the app
 *  would continue to startup normally it might crash right away again, resulting in the crash reports
 *  never to arrive.
 *
 *  This property allows to specify the time between app start and crash within which the crash report
 *  should be send synchronously instead to improve the probability of the crash report being send successfully.
 *
 *  Default: _5_
 */
@property (nonatomic, readwrite) NSTimeInterval maxTimeIntervalOfCrashForReturnMainApplicationDelay;

#pragma mark - Public Methods

/**
 *  Returns the shared manager object
 *
 *  @return A singleton BITHockeyManager instance ready use
 */
+ (BITHockeyManager *)sharedHockeyManager;

/**
 * Initializes the manager with a particular app identifier, company name and delegate
 *
 * Initialize the manager with a HockeyApp app identifier and assign the class that
 * implements the required protocol `BITCrashReportManagerDelegate`.
 *
 * @see BITCrashReportManagerDelegate
 * @see startManager
 * @param newAppIdentifier The app identifier that should be used.
 * @param newCompanyName the company that should be shown in the UI
 * @param crashReportManagerDelegate `nil` or the class implementing the option protocols
 */
- (void)configureWithIdentifier:(NSString *)newAppIdentifier companyName:(NSString *)newCompanyName crashReportManagerDelegate:(id <BITCrashReportManagerDelegate>) crashReportManagerDelegate;

/**
 * Starts the manager and runs all modules
 *
 * Call this after configuring the manager and setting up all modules.
 *
 * @see configureWithIdentifier:companyName:crashReportManagerDelegate:
 */
- (void)startManager;

@end

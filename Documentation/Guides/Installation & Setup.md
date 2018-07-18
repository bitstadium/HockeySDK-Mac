[![Build Status](https://www.bitrise.io/app/0b9891c6c8a2c030/status.svg?token=CoxYoBkW4sTCga7LG5xe4w&branch=develop)](https://www.bitrise.io/app/0b9891c6c8a2c030)[![Version](https://img.shields.io/cocoapods/v/HockeySDK-Mac.svg)](http://cocoadocs.org/docsets/HockeySDK-Mac)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Slack Status](https://slack.hockeyapp.net/badge.svg)](https://slack.hockeyapp.net)

## Version 5.1.0

- [Changelog](http://www.hockeyapp.net/help/sdk/mac/5.1.0/docs/docs/Changelog.html)

**NOTE:** With the release of HockeySDK 4.0.0-alpha.1 a bug was introduced which lead to the exclusion of the Application Support folder from iCloud and iTunes backups.

If you have been using one of the affected versions (4.0.0-alpha.2, Version 4.0.0-beta.1, 4.0.0, 4.1.0-alpha.1, 4.1.0-alpha.2, or Version 4.1.0-beta.1), please make sure to update to a newer version of our SDK as soon as you can.

## Introduction

HockeySDK-Mac implements support for using HockeyApp in your Mac applications.

The following feature is currently supported:

1. **Collect crash reports:** If you app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store!

2. **User Metrics:** Understand user behavior to improve your app. Track usage through daily and monthly active users, monitor crash impacted users, as well as customer engagement through session count. You can now track Custom Events in your app, understand user actions and see the aggregates on the HockeyApp portal.

3. **Feedback:** Collect feedback from your users from within your app and communicate directly with them using the HockeyApp backend.

4. **Add analytics to Sparkle:** If you are using Sparkle to provide app-updates (HockeyApp also supports Sparkle feeds for beta distribution) the SDK contains helpers to add some analytics data to each Sparkle request. 

This document contains the following sections:

1. [Requirements](#requirements)
2. [Setup](#setup)
3. [Advanced Setup](#advancedsetup) 	
	1. [Setup with CocoaPods](#cocoapods)
	2. [Crash Reporting](#crashreporting)
	3. [User Metrics](#user-metrics)
	4. [Feedback](#feedback)
	5. [Sparkle](#sparkle)
	6. [Debug information](#debug)
4. [Documentation](#documentation)
5. [Troubleshooting](#troubleshooting)
6. [Contributing](#contributing)
	1. [Code of Coduct](#codeofconduct)
	2. [Contributor License](#contributorlicense)
7. [Contact](#contact)

<a id="requirements"></a> 
## 1. Requirements

1. We assume that you already have a project in Xcode and that this project is opened in Xcode 8 or later.
2. The SDK supports OS X 10.9 and later.

<a id="setup"></a>
## 2. Setup

We recommend integration of our binary into your Xcode project to setup HockeySDK for your OS X app. You can also use our interactive SDK integration wizard in <a href="http://hockeyapp.net/mac/">HockeyApp for Mac</a> which covers all the steps from below. For other ways to setup the SDK, see [Advanced Setup](#advancedsetup).

### 2.1 Obtain an App Identifier

Please see the "[How to create a new app](http://support.hockeyapp.net/kb/about-general-faq/how-to-create-a-new-app)" tutorial. This will provide you with an HockeyApp specific App Identifier to be used to initialize the SDK.

### 2.2 Download the SDK

1. Download the latest [HockeySDK-Mac](http://www.hockeyapp.net/releases/) framework which is provided as a zip-File.
2. Unzip the file and you will see a folder called `HockeySDK-Mac`. (Make sure not to use 3rd party unzip tools!)

### 2.3 Copy the SDK into your projects directory in Finder

From our experience, 3rd-party libraries usually reside inside a subdirectory (let's call our subdirectory `Vendor`), so if you don't have your project organized with a subdirectory for libraries, now would be a great start for it. To continue our example,  create a folder called `Vendor` inside your project directory and move the unzipped `HockeySDK-Mac`-folder into it. 

<a id="setupxcode"></a>
### 2.4 Set up the SDK in Xcode

1. We recommend to use Xcode's group-feature to create a group for 3rd-party-libraries similar to the structure of our files on disk. For example,  similar to the file structure in 2.3 above, our projects have a group called `Vendor`.
2. Make sure the `Project Navigator` is visible (⌘+1)
3. Drag & drop `HockeySDK.framework` from your window in the `Finder` into your project in Xcode and move it to the desired location in the `Project Navigator` (e.g. into the group called `Vendor`)
4. A popup will appear. Select `Create groups for any added folders` and set the checkmark for your target. Then click `Finish`.
5. Now we’ll make sure the framework is copied into your app bundle:
	- Click on your project in the `Project Navigator` (⌘+1).
	- Click your target in the project editor.
	- Click on the `Build Phases` tab.
	- Click the `Add Build Phase` button at the bottom and choose `Add Copy Files`.
	- Click the disclosure triangle next to the new build phase.
	- Choose `Frameworks` from the Destination list.
	- Drag `HockeySDK-Mac` from the Project Navigator left sidebar to the list in the new Copy Files phase.

6. Make sure to sign the app, since the SDK will store user related input in the keychain for privacy reasons

<a id="modifycode"></a>
### 2.5 Modify Code 

**Objective-C**

1. Open your `AppDelegate.m` file.
2. Add the following line at the top of the file below your own `import` statements:

```objc
@import HockeySDK;
```

3. Search for the method `applicationDidFinishLaunching:`
4. Add the following lines to setup and start the Application Insights SDK:

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
// Do some additional configuration if needed here
[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

1. Open your `AppDelegate.swift` file.
2. Add the following line at the top of the file below your own import statements:

```swift
import HockeySDK
```

3. Search for the method `applicationWillFinishLaunching`
4. Add the following lines to setup and start the Application Insights SDK:

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
// Do some additional configuration if needed here
BITHockeyManager.shared().start()
```

*Note:* In case of document based apps, invoke `startManager` at the end of `applicationDidFinishLaunching`, since otherwise you may lose the Apple events to restore, open untitled document etc.

If any crash report has been saved from the last time your application ran, `startManager` will present a dialog to allow the user to submit it. Once done, or if there are no crash logs, it will then call back to your `appDelegate` with `showMainApplicationWindowForCrashManager:` (if implemented, see [Improved startup crashes handling](#improvedstartup)).

**Congratulation, now you're all set to use HockeySDK!**

<a id="advancedsetup"></a> 
## 3. Advanced Setup

<a id="cocoapods"></a>
### 3.1 Setup with CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like HockeySDK in your projects. To learn how to setup CocoaPods for your project, visit the [official CocoaPods website](http://cocoapods.org/).

**Podfile**

```
platform :osx, '10.9'
pod "HockeySDK-Mac"
```

<a name="crashreporting"></a>
### 3.2 Crash Reporting

The following options only show some of possibilities to interact and fine-tune the crash reporting feature. For more please check the full documentation of the `BITCrashManager` class in our [documentation](#documentation).

#### 3.2.1 Disable Crash Reporting
The HockeySDK enables crash reporting **per default**. Crashes will be immediately sent to the server the next time the app is launched.

To provide you with the best crash reporting, we are using [PLCrashReporter]("https://github.com/plausiblelabs/plcrashreporter") in [Version 1.2 / Commit 356901d7f3ca3d46fbc8640f469304e2b755e461]("https://github.com/plausiblelabs/plcrashreporter/commit/356901d7f3ca3d46fbc8640f469304e2b755e461").

This feature can be disabled as follows:

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDisableCrashManager: YES]; //disable crash reporting

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")

BITHockeyManager.shared().isCrashManagerDisabled = true

BITHockeyManager.shared().start()
```

#### 3.2.2 Auto send crash reports

Crashes are send the next time the app starts. If `crashManagerStatus` is set to `BITCrashManagerStatusAutoSend`, crashes will be send without any user interaction, otherwise an alert will appear allowing the users to decide whether they want to send the report or not.

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager].crashManager setAutoSubmitCrashReport: YES];

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")

BITHockeyManager.shared().crashManager.isAutoSubmitCrashReport = true

BITHockeyManager.shared().start()
```

The SDK is not sending the reports right when the crash happens deliberately, because it is not safe to implement such a mechanism, while being async-safe (any Objective-C code is _NOT_ async-safe!) and not causing more danger, like a deadlock of the device. We found that users do start the app again because most don't know what happened, and you will get by far most of the reports.

Sending the reports on startup is done asynchronously (non-blocking). This is the only safe way to ensure that the app won't be possibly killed by the iOS watchdog process, because startup could take too long and the app could not react to any user input when network conditions are bad or connectivity might be very slow.

<a id="exceptions"></a>
#### 3.2.3 Catch additional exceptions

On Mac OS X there are three types of crashes that are not reported to a registered `NSUncaughtExceptionHandler`:

1. Custom `NSUncaughtExceptionHandler` don't start working until after `NSApplication` has finished calling all of its delegate methods!
Example:

```objc
- (void)applicationDidFinishLaunching:(NSNotification *)note {
...
[NSException raise:@"ExceptionAtStartup" format:@"This will not be recognized!"];
...
}
```

2. The default `NSUncaughtExceptionHandler` in `NSApplication` only logs exceptions to the console and ends their processing. Resulting in exceptions that occur in the `NSApplication` "scope" not occurring in a registered custom `NSUncaughtExceptionHandler`. 
Example:

```objc
- (void)applicationDidFinishLaunching:(NSNotification *)note {
...
[self performSelector:@selector(delayedException) withObject:nil afterDelay:5];
...
}

- (void)delayedException {
NSArray *array = [NSArray array];
[array objectAtIndex:23];
}
```

3. Any exceptions occurring in IBAction or other GUI does not even reach the NSApplication default UncaughtExceptionHandler.
Example:

```objc
- (IBAction)doExceptionCrash:(id)sender {
NSArray *array = [NSArray array];
[array objectAtIndex:23];
}
```

In general there are two solutions. The first one is to use an `NSExceptionHandler` class instead of an `NSUncaughtExceptionHandler`. But this has a few drawbacks which are detailed in `BITCrashReportExceptionApplication.h`.

Instead we provide the optional `NSApplication` subclass `BITCrashExceptionApplication` which handles cases 2 and 3.

**Installation:**

* Open the applications `Info.plist`
* Search for the field `Principal class`
* Replace `NSApplication` with `BITCrashExceptionApplication`

Alternatively, if you have your own NSApplication subclass, change it to be a subclass of `BITCrashExceptionApplication` instead.

#### 3.2.4 Attach additional data

The `BITHockeyManagerDelegate` protocol provides methods to add additional data to a crash report:

1. UserID:

**Objective-C**

`- (NSString *)userIDForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

**Swift**

`optional public func userID(for hockeyManager: BITHockeyManager!, componentManager: BITHockeyBaseManager!) -> String!`

2. UserName:

**Objective-C**

`- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

**Swift**

`optional public func userName(for hockeyManager: BITHockeyManager!, componentManager: BITHockeyBaseManager!) -> String!`

3. UserEmail:

**Objective-C**

`- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

**Swift**

`optional public func userEmail(for hockeyManager: BITHockeyManager!, componentManager: BITHockeyBaseManager!) -> String!`

The `BITCrashManagerDelegate` protocol (which is automatically included in `BITHockeyManagerDelegate`) provides methods to add more crash specific data to a crash report:

1. Text attachments: 

**Objective-C**

`-(NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager`

**Swift**

`optional public func applicationLog(for crashManager: BITCrashManager!) -> String!`

Check the following tutorial for an example on how to add CocoaLumberjack log data: [How to Add Application Specific Log Data on iOS or OS X](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-add-application-specific-log-data-on-ios-or-os-x)

2. Binary attachments: 

**Objective-C**

`-(BITHockeyAttachment *)attachmentForCrashManager:(BITCrashManager *)crashManager`

**Swift**

`optional public func attachment(for crashManager: BITCrashManager!) -> BITHockeyAttachment!`

Make sure to implement the protocol

**Objective-C**

```objc
@interface YourAppDelegate () <BITHockeyManagerDelegate> {}

@end
```

**Swift**

```swift
class YourAppDelegate: NSObject, BITHockeyManagerDelegate {

}
```

and set the delegate:

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDelegate: self];

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")

BITHockeyManager.shared().delegate = self

BITHockeyManager.shared().start()
```

<a name="user-metrics"></a>
### 3.3 User Metrics

HockeyApp automatically provides you with nice, intelligible, and informative metrics about how your app is used and by whom. 

- **Sessions**: A new session is tracked by the SDK whenever the containing app is restarted (this refers to a 'cold start', i.e. when the app has not already been in memory prior to being launched) or whenever it becomes active again after having been in the background for 20 seconds or more.
- **Users**: The SDK anonymously tracks the users of your app by creating a random UUID that is then securely stored in the iOS keychain. Because this anonymous ID is stored in the keychain it persists across reinstallations.
- **Custom Events**: You can now track Custom Events in your app, understand user actions and see the aggregates on the HockeyApp portal.

Just in case you want to opt-out of the automatic collection of anonymous users and sessions statistics, there is a way to turn this functionality off at any time:

**Objective-C**

```objc
[BITHockeyManager sharedHockeyManager].disableMetricsManager = YES;
```

**Swift**

```swift
BITHockeyManager.shared().isMetricsManagerDisabled = true
```

#### 3.3.1 Custom Events

By tracking custom events, you can now get insight into how your customers use your app, understand their behavior and answer important business or user experience questions while improving your app.

- Before starting to track events, ask yourself the questions that you want to get answers to. For instance, you might be interested in business, performance/quality or user experience aspects.
- Name your events in a meaningful way and keep in mind that you will use these names when searching for events in the HockeyApp web portal. It is your reponsibility to not collect personal information as part of the events tracking.

**Objective-C**

```objc
BITMetricsManager *metricsManager = [BITHockeyManager sharedHockeyManager].metricsManager;

[metricsManager trackEventWithName:eventName]
```

**Swift**

```swift
let metricsManager = BITHockeyManager.shared().metricsManager

metricsManager.trackEvent(withName: eventName)
```

**Limitations**

- Accepted characters for tracking events are: [a-zA-Z0-9_. -]. If you use other than the accepted characters, your events will not show up in the HockeyApp web portal.
- There is currently a limit of 300 unique event names per app per week.
- There is _no_ limit on the number of times an event can happen.

#### 3.3.2 Attaching custom properties and measurements to a custom event

It's possible to attach porperties and/or measurements to a custom event.

- Properties have to be a string.
- Measurements have to be of a numeric type.

**Objective-C**

```objc
BITMetricsManager *metricsManager = [BITHockeyManager sharedHockeyManager].metricsManager;

NSDictionary *myProperties = @{@"Property 1" : @"Something",
@"Property 2" : @"Other thing",
@"Property 3" : @"Totally different thing"};
NSDictionary *myMeasurements = @{@"Measurement 1" : @1,
@"Measurement 2" : @2.34,
@"Measurement 3" : @2000000};

[metricsManager trackEventWithName:eventName properties:myProperties measurements:myMeasurements]
```

**Swift**

```swift
let myProperties = ["Property 1": "Something", "Property 2": "Other thing", "Property 3" : "Totally different thing."]
let myMeasurements = ["Measurement 1": 1, "Measurement 2": 2.3, "Measurement 3" : 30000]

let metricsManager = BITHockeyManager.shared().metricsManager
metricsManager.trackEvent(withName: eventName, properties: myProperties, measurements: myMeasurements)
```

<a name="feedback"></a>
### 3.4 Feedback

`BITFeedbackManager` lets your users communicate directly with you via the app and an integrated user interface. It provides a single threaded discussion with a user running your app. This feature is only enabled, if you integrate the actual view controllers into your app.

You should never create your own instance of `BITFeedbackManager` but use the one provided by the `[BITHockeyManager sharedHockeyManager]`:

**Objective-C**

```objc
[BITHockeyManager sharedHockeyManager].feedbackManager
```

**Swift**

```swift
BITHockeyManager.shared().feedbackManager
```

Please check the [documentation](#documentation) of the `BITFeedbackManager` class on more information on how to leverage this feature.

<a name="sparkle"></a>
### 3.5 Sparkle

<a name="sparklesetup"></a>
#### 3.5.1 Setup for beta distribution

1. Install the Sparkle SDK: [http://sparkle-project.org](http://sparkle-project.org)
As of today (01/2016), Sparkle doesn't support Mac sandboxes. If you require this, check out the following discussion https://github.com/sparkle-project/Sparkle/issues/363

2. Set `SUFeedURL` to `https://rink.hockeyapp.net/api/2/apps/<APP_IDENTIFIER>` and replace `<APP_IDENTIFIER>` with the same value used to initialize the HockeySDK

3. Create a `.zip` file of your app bundle and upload that to HockeyApp.

<a name="betaanalytics"></a>
#### 3.5.2 Add analytics data to Sparkle setup

1. Set the following additional Sparkle property:

```
sparkleUpdater.sendsSystemProfile = YES;
```

2. Add the following Sparkle delegate method (don't forget to bind `SUUpdater` to your appDelegate!):

```objc
- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater
sendingSystemProfile:(BOOL)sendingProfile {
return [[BITSystemProfile sharedSystemProfile] systemUsageData];
}
```

3. Initialize usage tracking depending on your needs.

One example scenario is when the app is started or comes to foreground and when it goes to background or is terminated:

```objc
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
…      
NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
BITSystemProfile *bsp = [BITSystemProfile sharedSystemProfile];
[dnc addObserver:bsp selector:@selector(startUsage) name:NSApplicationDidBecomeActiveNotification object:nil];
[dnc addObserver:bsp selector:@selector(stopUsage) name:NSApplicationWillTerminateNotification object:nil];
[dnc addObserver:bsp selector:@selector(stopUsage) name:NSApplicationWillResignActiveNotification object:nil];
…
};
```

<a id="debug"></a>
### 3.6 Debug information

To check if data is send properly to HockeyApp and also see some additional SDK debug log data in the console, add the following line before `startManager`:

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[BITHockeyManager sharedHockeyManager].logLevel = BITLogLevelDebug;

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
BITHockeyManager.shared().logLevel = BITLogLevel.debug
BITHockeyManager.shared().start()
```

<a id="documentation"></a>
## 4. Documentation

Our documentation can be found on [HockeyApp](https://www.hockeyapp.net/help/sdk/mac/5.1.0/index.html).

<a id="troubleshooting"></a>
## 5.Troubleshooting

1. dlyb crash on startup

Make sure that the apps build setting has `LD_RUNPATH_SEARCH_PATHS` set to `@executable_path/../Frameworks`

2. Crash on startup with Xcode debugger running

Make sure there is no `All Exceptions` breakpoint active or limit it to `Objective-C` only and exclude `C++`.

3. Features are not working as expected

Enable debug output to the console to see additional information from the SDK initializing the modules,  sending and receiving network requests and more by adding the following code before calling `startManager`:

[BITHockeyManager sharedHockeyManager].logLevel = BITLogLevelDebug;

<a id="contributing"></a>
## 6. Contributing

We're looking forward to your contributions via pull requests.

**Development environment**

* A Mac running the latest version of macOS
* Get the latest Xcode from the Mac App Store
* [AppleDoc](https://github.com/tomaz/appledoc) 
* [Cocoapods](https://cocoapods.org/)

<a id="codeofconduct"></a>
## 6.1 Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

<a id="contributorlicense"></a>
## 6.2 Contributor License

You must sign a [Contributor License Agreement](https://cla.microsoft.com/) before submitting your pull request. To complete the Contributor License Agreement (CLA), you will need to submit a request via the [form](https://cla.microsoft.com/) and then electronically sign the CLA when you receive the email containing the link to the document. You need to sign the CLA only once to cover submission to any Microsoft OSS project. 

<a id="contact"></a>
## 7. Contact

If you have further questions or are running into trouble that cannot be resolved by any of the steps here, feel free to open a Github issue here or contact us at [support@hockeyapp.net](mailto:support@hockeyapp.net)

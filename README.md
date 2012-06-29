his document describes how to integrate the HockeySDK-Mac into your app. The SDK has one main feature:

**Collect crash reports:** If your app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp.

## Release Notes

Version 0.9.0 (RC 1):

- Fixed memory leak
- Added option to intercept exceptions thrown within the main NSRunLoop before they reach Apple's exception handler
- Send crash report synchronously, so crashes that appear on startup are also safely submitted
- Make sure crash reports are anonymous and don't contain user's home directory name
- Send app binaries UUIDs to the server for server side symbolication improvements

Version 0.6.0:

- System calls in Last Exception Backtrace are now symbolicated
- Fixed invalid stacktrace and some cases
- Fixed 0x0 appearances in stack traces
- Fixed memory leak

Version 0.5.1:

- Added Mac Sandbox support:
  - Supports 32 and 64 bit Intel X86 architecture
  - Uses brand new PLCrashReporter version instead of crash logs from Libary directories
- Fixed sending crash reports to the HockeyApp servers

## Prerequisites

1. Before you integrate HockeySDK-Mac into your own app, you should add the app to HockeyApp if you haven't already. Read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-create-a-new-app) on how to do it.

2. We also assume that you already have a project in Xcode and that this project is opened in Xcode 4.

## Versioning

We suggest to handle beta and release versions in two separate *apps* on HockeyApp with their own bundle identifier (e.g. by adding "beta" to the bundle identifier), so

* both apps can run on the same device or computer at the same time without interfering,

* release versions do not appear on the beta download pages, and

* easier analysis of crash reports and user feedback.

We propose the following method to set version numbers in your beta versions:

* Use both "Bundle Version" and "Bundle Version String, short" in your Info.plist.

* "Bundle Version" should contain a sequential build number, e.g. 1, 2, 3.

* "Bundle Version String, short" should contain the target official version number, e.g. 1.0.

## Integrate using the framework binary

1. Download the latest framework.

2. Unzip the file. A HockeySDK.framework package is extracted

3. Link the HockeySDK-Mac framework to your target:
   - Drag HockeySDK.framework into the Frameworks folder of your Xcode project.
   - Be sure to check the “copy items into the destination group’s folder” box in the sheet that appears.
   - Make sure the box is checked for your app’s target in the sheet’s Add to targets list.
4. Now we’ll make sure the framework is copied into your app bundle:
   - Click on your project in the Project Navigator.
   - Click your target in the project editor.
   - Click on the Build Phases tab.
   - Click the Add Build Phase button at the bottom and choose Add Copy Files.
   - Click the disclosure triangle next to the new build phase.
   - Choose Frameworks from the Destination list.
   - Drag HockeySDK-Mac from the Project Navigator left sidebar to the list in the new Copy Files phase.

5. Continue with the chapter "Setup HockeySDK-Mac framework".

## Setup HockeySDK-Mac

1. Open your `AppDelegate.h` file.

2. Add the following line at the top of the file below your own #import statements:<pre><code>#import <HockeySDK/CNSHockeyManagerDelegate.h></code></pre>

3. Add the following protocol to your AppDelegate: <pre><code>CNSHockeyManagerDelegate</code></pre>

4. Open your `AppDelegate.m` file.

5. Add the following line at the top of the file below your own #import statements:<pre><code>#import <HockeySDK/CNSHockeyManager.h></code></pre>

6. In your `appDelegate` change the invocation of the main window to the following structure

        // this delegate method is required
        - (void) showMainApplicationWindow
        {
            // launch the main app window
            // remember not to automatically show the main window if using NIBs
            [window makeFirstResponder: nil];
            [window makeKeyAndOrderFront:nil];
        }
This allows the SDK to present a crash dialog on the next startup before the main window gets initialized and possibly crash right away again.
        
6. Search for the method `application:didFinishLaunchingWithOptions:`

7. Add the following line:

        [[CNSHockeyManager sharedHockeyManager] configureWithIdentifier:@"<APP_IDENTIFIER>" companyName:@"My company" delegate:self];
If you want the SDK to intercept exceptions thrown within the main NSRunLoop before they reach Apple's exception handler, use the following line:

        [[CNSHockeyManager sharedHockeyManager] configureWithIdentifier:@"<APP_IDENTIFIER>" companyName:@"My company" exceptionInterceptionEnabled:YES delegate:self];
They will be treated with the default behavior given to uncaught exceptions. Use with caution if the client overrides `-[NSApplication sendEvent:]`!

    Alternatively you can also subclass `NSWindow` or `NSApplication` to catch the exceptions like this:
    
        @implementation MyWindow
 
        - (void)sendEvent:(NSEvent *)theEvent
        {
            // Catch all exceptions and forward them to the crash reporter
            @try {
                [super sendEvent: theEvent];
            }
            @catch (NSException *exception) {
                (NSGetUncaughtExceptionHandler())(exception);
            }
        }
         
        @end
    
8. Replace `APP_IDENTIFIER` with the app identifier of your app. If you don't know what the app identifier is or how to find it, please read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-find-the-app-identifier). 

9. Implement delegate methods as mentioned below if you want to add custom data.

10. Done.

## Optional Delegate Methods

Besides the crash log, HockeyApp can show you fields with information about the user and an optional description. You can fill out these fields by implementing the following methods:

* `crashReportUserID` should be a user ID or email, e.g. if your app requires to sign in into your server, you could specify the login here. The string should be no longer than 255 chars. 

* `crashReportContact` should be the user's name or similar. The string should be no longer than 255 chars.

* `crashReportApplicationLog` can be as long as you want it to be and contain additional information about the crash. For example, you can return a custom log or the last XML or JSON response from your server here.

If you implement these delegate methods and keep them in your live app too, please consider the privacy implications.

## Upload the .dSYM File

Once you have your app ready for beta testing or even to submit it to the App Store, you need to upload the .dSYM bundle to HockeyApp to enable symbolication. If you have built your app with Xcode4, menu Product > Archive, you can find the .dSYM as follows:

1. Chose Window > Organizer in Xcode.

2. Select the tab Archives.

3. Select your app in the left sidebar.

4. Right-click on the latest archive and select Show in Finder.

5. Right-click the .xcarchive in Finder and select Show Package Contents. 

6. You should see a folder named dSYMs which contains your dSYM bundle. If you use Safari, just drag this file from Finder and drop it on to the corresponding drop zone in HockeyApp. If you use another browser, copy the file to a different location, then right-click it and choose Compress "YourApp.dSYM". The file will be compressed as a .zip file. Drag & drop this file to HockeyApp. 

As an easier alternative for step 5 and 6, you can use our [HockeyMac](https://github.com/codenauts/HockeyMac) app to upload the complete archive in one step.

## Checklist if Crashes Do Not Appear in HockeyApp

1. Check if the `APP_IDENTIFIER` matches the App ID in HockeyApp.

2. Check if CFBundleIdentifier in your Info.plist matches the Bundle Identifier of the app in HockeyApp. HockeyApp accepts crashes only if both the App ID and the Bundle Identifier equal their corresponding values in your plist and source code.

3. If it still does not work, please [contact us](http://support.hockeyapp.net/discussion/new).

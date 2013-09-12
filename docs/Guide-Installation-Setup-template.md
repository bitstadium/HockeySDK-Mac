This how-to describes how to integrate the HockeySDK-Mac client into your Mac app. The client allows testers to send crash reports after the application has crashed. It will ask the tester on the next startup if he wants to send the crash report and then submit the crash report to HockeyApp. If you have uploaded the .dSYM file, HockeyApp will automatically symbolicate the crash report so that you can analyze the stack trace including class, method and line number at which the crash happened.

HockeySDK-Mac can be integrated in apps for both beta distribution and the App Store.

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

5. Check the `Runpath Search Paths` in the app targets build settings to contain `@loader_path/../Frameworks`
6. Continue with the chapter "Setup HockeySDK-Mac".
7. If Xcode requires to sign all frameworks, add `--deep` to the `OTHER_CODE_SIGN_FLAGS` build settings of your app target

## Setup HockeySDK-Mac

1. Open your `AppDelegate.h` file.

2. Add the following line at the top of the file below your own #import statements:<pre><code>#import &lt;HockeySDK/HockeySDK.h&gt;</code></pre>

3. Add the following protocol to your AppDelegate: `BITHockeyManagerDelegate`:<pre><code>@interface AppDelegate() &lt;BITHockeyManagerDelegate&gt; {}
@end</code></pre>

4. Switch to your `AppDelegate.m` file and add the following line at the top of the file below your own #import statements:<pre><code>#import &lt;HockeySDK/BITHockeyManager.h&gt;</code></pre>

5. Search for the method `applicationDidFinishLaunching:(NSNotification *)aNotification`, or find where your application normally presents and activates its main/first window. (Note: If you are using NIBs, make sure to change the main window to NOT automatically show when the NIB is loaded!)

   Replace whatever usually opens the main window with the following lines:

        [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<APP_IDENTIFIER>" companyName:@"My company" crashReportManagerDelegate:self];
        [[BITHockeyManager sharedHockeyManager] startManager];

    In case of document based apps, invoke `startManager` at the end of `applicationDidFinishLaunching`, since otherwise you may lose the Apple events to restore, open untitled document etc.
    
	If any crash report has been saved from the last time your application ran, `startManager` will present a dialog to allow the user to submit it. Once done, or if there are no crash logs, it will then call back to your `appDelegate` with `showMainApplicationWindowForCrashManager:` (see step 7 below) to continue the process of getting your main window displayed.

    This allows the SDK to present a crash dialog on the next startup before your main window gets initialized and possibly crashes right away again.

6. Replace `APP_IDENTIFIER` in `configureWithIdentifier:` with the app identifier of your app. If you don't know what the app identifier is or how to find it, please read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-find-the-app-identifier). 

7. Your `appDelegate` is now a `BITCrashManagerDelegate`, so you must implement the required `showMainApplicationWindowForCrashManager:` method like this:

        // this delegate method is required
        - (void) showMainApplicationWindowForCrashManager:(id)crashManager
        {
            // launch the main app window
            [myWindow makeFirstResponder: nil];
            [myWindow makeKeyAndOrderFront: nil];
        }

    In case of NSDocument-based applications, leave the implementation empty.
        
8. Set additional options and/or implement optional delegate methods as mentioned below if you want to add custom data to the crash reports.

9. If this app is sandboxed, make sure to add the entitlements for network access.

10. Done.

## Additional Options

### Catch additional exceptions

On Mac OS X there are three types of crashes that are not reported to a registered `NSUncaughtExceptionHandler`:

1. Custom `NSUncaughtExceptionHandler` don't start working until after `NSApplication` has finished calling all of its delegate methods!

   Example:
       
       - (void)applicationDidFinishLaunching:(NSNotification *)note {
         ...
         [NSException raise:@"ExceptionAtStartup" format:@"This will not be recognized!"];
         ...
       }


2. The default `NSUncaughtExceptionHandler` in `NSApplication` only logs exceptions to the console and ends their processing. Resulting in exceptions that occur in the `NSApplication` "scope" not occurring in a registered custom `NSUncaughtExceptionHandler`.

   Example:
   
       - (void)applicationDidFinishLaunching:(NSNotification *)note {
         ...
         [self performSelector:@selector(delayedException) withObject:nil afterDelay:5];
        ...
      }

      - (void)delayedException {
        NSArray *array = [NSArray array];
        [array objectAtIndex:23];
      }

3. Any exceptions occurring in IBAction or other GUI does not even reach the NSApplication default UncaughtExceptionHandler.

   Example:
       
       - (IBAction)doExceptionCrash:(id)sender {
         NSArray *array = [NSArray array];
         [array objectAtIndex:23];
       }

In general there are two solutions. The first one is to use an `NSExceptionHandler` class instead of an `NSUncaughtExceptionHandler`. But this has a few drawbacks which are detailed in `BITCrashReportExceptionApplication.h`.

Instead we provide the optional `NSApplication` subclass `BITCrashExceptionApplication` which handles cases 2 and 3.

**Installation:**

* Open the applications `Info.plist`
* Search for the field `Principal class`
* Replace `NSApplication` with `BITCrashExceptionApplication`

Alternatively, if you have your own NSApplication subclass, change it to be a subclass of `BITCrashExceptionApplication` instead.


### Automatic sending of crash reports

If you want to send all crash reports automatically, configure the SDK with the following code:

    [[BITHockeyManager sharedHockeyManager].crashManager setAutoSubmitCrashReport: YES];

### Improved startup crashes handling

Crash reports are normally sent to our server asynchronously. If your application is crashing near startup, BITHockeyManager will send crash reports synchronously to make sure they are being received. For adjusting the default 5 seconds maximum time interval between app start and crash being considered to send crashes synchronously, use the following line:

    [[BITHockeyManager sharedHockeyManager] setMaxTimeIntervalOfCrashForReturnMainApplicationDelay:<NewTimeInterval>];

### Sparkle setup for beta distribution

* Install the Sparkle SDK: http://sparkle.andymatuschak.org/
  
  As of today (03/2013), Sparkle doesn't support Mac sandboxes. If you require this, check out the following fork [https://github.com/tumult/Sparkle](https://github.com/tumult/Sparkle) and this discussion [https://github.com/andymatuschak/Sparkle/pull/165](https://github.com/andymatuschak/Sparkle/pull/165)
  
* Set `SUFeedURL` to `https://rink.hockeyapp.net/api/2/apps/<APP_IDENTIFIER>` and replace `<APP_IDENTIFIER>` with the same value used to initialize the HockeySDK

* Create a `.zip` file of your app bundle and upload that to HockeyApp.

### Add analytics data to Sparkle setup

1. Set the following additional Sparkle property:

        sparkleUpdater.sendsSystemProfile = YES;

2. Add the following Sparkle delegate method (don't forget to bind `SUUpdater` to your appDelegate!):

        - (NSArray *)feedParametersForUpdater:(SUUpdater *)updater
                        sendingSystemProfile:(BOOL)sendingProfile {
            return [[BITSystemProfile sharedSystemProfile] systemUsageData];
        }

3. Initialize usage tracking depending on your needs.

    On example scenario is when the app is started or comes to foreground and when it goes to background or is terminated:

        - (void)applicationWillFinishLaunching:(NSNotification *)aNotification
            …      
            NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
            BITSystemProfile *bsp = [BITSystemProfile sharedSystemProfile];
            [dnc addObserver:bsp selector:@selector(startUsage) name:NSApplicationDidBecomeActiveNotification object:nil];
            [dnc addObserver:bsp selector:@selector(stopUsage) name:NSApplicationWillTerminateNotification object:nil];
            [dnc addObserver:bsp selector:@selector(stopUsage) name:NSApplicationWillResignActiveNotification object:nil];
            …
        };

### Show debug log messages

In case you want to check some integrated logging data (this should probably be used only for debugging purposes), add the following line before `startManager`:

    [[BITHockeyManager sharedHockeyManager] setDebugLogEnabled];
 
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

As an easier alternative for step 5 and 6, you can use our [HockeyMac](https://github.com/BitStadium/HockeyMac) app to upload the complete archive in one step.

### Multiple dSYMs

If your app is using multiple frameworks that are not statically linked, you can upload all dSYM packages to HockeyApp by creating a single `.zip` file with all the dSYM packages included and make sure the zip file has the extension `.dSYM.zip`.


## Checklist if Crashes Do Not Appear in HockeyApp

1. Check if the `APP_IDENTIFIER` matches the App ID in HockeyApp.

2. Check if CFBundleIdentifier in your Info.plist matches the Bundle Identifier of the app in HockeyApp. HockeyApp accepts crashes only if both the App ID and the Bundle Identifier equal their corresponding values in your plist and source code.

3. If it still does not work, please [contact us](http://support.hockeyapp.net/discussion/new).

[![Build Status](https://travis-ci.org/bitstadium/HockeySDK-iOS.svg?branch=develop)](https://travis-ci.org/bitstadium/HockeySDK-Mac)
[![Version](https://img.shields.io/cocoapods/v/HockeySDK-Mac.svg)](http://cocoadocs.org/docsets/HockeySDK-Mac)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Slack Status](https://slack.hockeyapp.net/badge.svg)](https://slack.hockeyapp.net)


# Version 4.1.4

## Introduction

HockeySDK-Mac implements support for using HockeyApp in your Mac applications.

The following feature is currently supported:

1. **Collect crash reports:** If you app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e., those submitted to the App Store!

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


## 1. Setup

It is super easy to use HockeyApp in your iOS app. Have a look at our [documentation](https://www.hockeyapp.net/help/sdk/mac/4.1.4/docs/docs/Guide-Installation-Setup.html) and onboard your app within minutes.

## 2. Documentation

Please visit [our landing page](http://hockeyapp.net/help/sdk/mac/4.1.4/index.html) as a starting point for all of our documentation.

Please check out our [getting started documentation](https://www.hockeyapp.net/help/sdk/mac/4.1.4/docs/docs/Guide-Installation-Setup.html), [changelog](http://www.hockeyapp.net/help/sdk/mac/4.1.4/docs/docs/Changelog.html), [header docs](https://www.hockeyapp.net/help/sdk/mac/4.1.4/index.html) as well as our [troubleshooting section](https://www.hockeyapp.net/help/sdk/mac/4.1.4/docs/docs/Guide-Installation-Setup.html#troubleshooting).


## 3. Contributing

We're looking forward to your contributions via pull requests.

### 3.1 Development environment

* A Mac running the latest version of macOS
* The latest Xcode from the Mac App Store
* [AppleDoc](https://github.com/tomaz/appledoc) 
* [Cocoapods](https://cocoapods.org/)

### 3.2 Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

### 3.3 Contributor License

You must sign a [Contributor License Agreement](https://cla.microsoft.com/) before submitting your pull request. To complete the Contributor License Agreement (CLA), you will need to submit a request via the [form](https://cla.microsoft.com/) and then electronically sign the CLA when you receive the email containing the link to the document. You need to sign the CLA only once to cover submission to any Microsoft OSS project. 

## 4. Contact

If you have further questions or are running into trouble that cannot be resolved by any of the steps [in our troubleshooting section](https://www.hockeyapp.net/help/sdk/mac/4.1.4/docs/docs/Guide-Installation-Setup.html#troubleshooting), feel free to open an issue here, contact us at [support@hockeyapp.net](mailto:support@hockeyapp.net) or join our [Slack](https://slack.hockeyapp.net).

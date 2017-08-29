# IndoorAtlas SDK Examples for iOS (Swift)

[IndoorAtlas](https://www.indooratlas.com/) provides a unique Platform-as-a-Service (PaaS) solution that runs a disruptive geomagnetic positioning in its full-stack hybrid technology for accurately pinpointing a location inside a building. The IndoorAtlas SDK enables app developers to use high-accuracy indoor positioning in venues that have been fingerprinted.

This example app showcases the IndoorAtlas SDK features and acts as a reference implementation in Swift for many of the basic SDK features. Getting started requires you to set up a free developer account and fingerprint your indoor venue using the IndoorAtlas MapCreator tool.

There are also similar examples for [Objective-C](https://github.com/IndoorAtlas/ios-sdk-examples) and [Android](https://github.com/IndoorAtlas/android-sdk-examples).

* [Getting Started](#getting-started)
    * [Set up your account](#set-up-your-account)
    * [Get started by using CocoaPods](#get-started-by-using-cocoapods)
    * [Manual IndoorAtlas framework download](#manual-indooratlas-framework-download)
* [Features](#features)
* [Documentation](#documentation)
* [SDK Changelog](#sdk-changelog)
* [License](#license)


## Getting Started

### Set up your account

* Set up your [free developer account](https://app.indooratlas.com) in the IndoorAtlas developer portal. Help with getting started is available in the [Quick Start Guide](http://docs.indooratlas.com/quick-start-guide.html).
* To enable IndoorAtlas indoor positioning in a venue, the venue needs to be fingerprinted with the [IndoorAtlas MapCreator 2](https://play.google.com/store/apps/details?id=com.indooratlas.android.apps.jaywalker) tool.
* To start developing your own app, create an [API key](https://app.indooratlas.com/apps).

### Get started by using CocoaPods

Clone or download this git repository and install the project dependencies using CocoaPods (recommended):

```
cd ios-sdk-swift-examples/example
pod install
open ios-sdk-swift-examples.xcworkspace
```

Set your API keys in `ApiKeys.swift`. API keys can be generated at https://app.indooratlas.com/apps

### Manual IndoorAtlas framework download

If you are not using CocoaPods, the IndoorAtlas SDK framework can be downloaded and installed manually by following the steps on the IndoorAtlas web site: http://docs.indooratlas.com/ios/getting-started.html

## Features

These examples are included in the app:

* Apple Maps: Shows the IndoorAtlas blue dot location overlaid on Apple Maps.
* Apple Maps Overlay: Shows the location together with the associated floor plan bitmap overlay on the world map.
* Image View: Floor plan bitmap image view with the blue dot location.
* Console Prints: Shows console printout provided by the SDK.

## Documentation

The IndoorAtlas SDK API documentation is available in the documentation portal: http://docs.indooratlas.com/ios/

#### Known issues

* iOS automatic floor plan recognition is not always reliable. It can be improved by using ambient beacons, auxiliary information sources, or UI design choices. Otherwise, we  recommend to set floorplan id directly when possible.

## SDK Changelog

http://docs.indooratlas.com/ios/CHANGELOG.html

## License

Copyright 2015-2017 IndoorAtlas Ltd. The IndoorAtlas SDK Examples are released under the Apache License. See the [LICENSE.md](https://github.com/IndoorAtlas/ios-sdk-swift-examples/blob/master/LICENSE) file for details.

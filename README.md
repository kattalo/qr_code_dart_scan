[![pub package](https://img.shields.io/pub/v/qr_code_dart_scan.svg)](https://pub.dev/packages/qr_code_dart_scan)

# QRCodeDartScan

A QR code scanner that works on both iOS and Android using dart decoder.

## Features

- Camera scan preview in a widget
- Scan QRCode
- Scan QRCode inverted

## Installation

First, add `qr_code_dart_scan` as a [dependency in your pubspec.yaml file](https://flutter.dev/using-packages/).

### iOS

iOS 10.0 of higher is needed to use the camera plugin. If compiling for any version lower than 10.0 make sure to check the iOS version before using the camera plugin. For example, using the [device_info](https://pub.dev/packages/device_info) plugin.

Add two rows to the `ios/Runner/Info.plist`:

* one with the key `Privacy - Camera Usage Description` and a usage description.
* and one with the key `Privacy - Microphone Usage Description` and a usage description.

Or in text format add the key:

```xml
<key>NSCameraUsageDescription</key>
<string>Can I use the camera please?</string>
<key>NSMicrophoneUsageDescription</key>
<string>Can I use the mic please?</string>
```

### Android

Change the minimum Android sdk version to 21 (or higher) in your `android/app/build.gradle` file.

```
minSdkVersion 21
```

It's important to note that the `MediaRecorder` class is not working properly on emulators, as stated in the documentation: https://developer.android.com/reference/android/media/MediaRecorder. Specifically, when recording a video with sound enabled and trying to play it back, the duration won't be correct and you will only see the first frame.

## 7.1.3
Improvements:
* [Darwin] Correct package identity for IOS-DFU-Library dependency.

## [7.2.0](https://github.com/juliansteenbakker/nordic_dfu/compare/nordic_dfu-v7.1.3...nordic_dfu-v7.2.0) (2026-08-17)


### Features

* add address mapping logic ([eaac0c4](https://github.com/juliansteenbakker/nordic_dfu/commit/eaac0c4738c740c452d946be28df723878e01fb5))
* add address mapping logic document and link it in the readma page ([3119ef4](https://github.com/juliansteenbakker/nordic_dfu/commit/3119ef43d5d09ce9c051b7a9da83b53f01cbc619))
* add increment uuid support to example app ([aa021fd](https://github.com/juliansteenbakker/nordic_dfu/commit/aa021fd34d9b06c3e1c212d3b983985e133ddaea))
* add macos example ([1c04d7a](https://github.com/juliansteenbakker/nordic_dfu/commit/1c04d7a1bc44a696a85017e44fb78dfa19740eda))
* **android:** support for agp 9 ([f64f0d7](https://github.com/juliansteenbakker/nordic_dfu/commit/f64f0d770cf9251c70d1556f2340f71567dfb40b))
* **android:** support for agp 9 ([42628e2](https://github.com/juliansteenbakker/nordic_dfu/commit/42628e2780691eeca5f3dbd7d5aa6d2e31ee10b3))
* DFU Address Mapping Feature Implementation ([46a6a05](https://github.com/juliansteenbakker/nordic_dfu/commit/46a6a059bd98c49a42a175c232a1c238064a56f8))


### Bug Fixes

* address mapping patch ([f7c301e](https://github.com/juliansteenbakker/nordic_dfu/commit/f7c301ed5728cbe04cac3276d843c14ba219c237))
* **android:** add missing .zip extension to temp asset file path ([569c504](https://github.com/juliansteenbakker/nordic_dfu/commit/569c5042667cb8c6d80af7521523f7a9b9d9c65f))
* **android:** add missing .zip extension to temp asset file path ([bf27b43](https://github.com/juliansteenbakker/nordic_dfu/commit/bf27b43dd0b2b23a5fa4f07a3ca7c93de6440e48))
* **android:** remove obsolete jetifier & raise gradle heap ([725dfac](https://github.com/juliansteenbakker/nordic_dfu/commit/725dfacdd12b931d0434929b2aaf6aa7e7a39e68))
* **android:** resolve original device address for DFU callbacks ([#283](https://github.com/juliansteenbakker/nordic_dfu/issues/283)) ([e3ee1d1](https://github.com/juliansteenbakker/nordic_dfu/commit/e3ee1d150130269c111412556a64163887a45fd4))
* callbacks ([90df63b](https://github.com/juliansteenbakker/nordic_dfu/commit/90df63b772eef386f25d65a006874da7e5f9945c))
* deprecation warning ([8431c42](https://github.com/juliansteenbakker/nordic_dfu/commit/8431c4289b3b080d10a8617a9c5bbd8e0f198d83))
* **docs:** Fix broken README links ([4e09fab](https://github.com/juliansteenbakker/nordic_dfu/commit/4e09faba292ca772e1c5e300fb65a444c1ba9354))
* **docs:** Fix broken README links ([51ce2aa](https://github.com/juliansteenbakker/nordic_dfu/commit/51ce2aa823444dd4b14225002d9efbeadae4fe38))
* function not being awaited ([35c350b](https://github.com/juliansteenbakker/nordic_dfu/commit/35c350b5e480c4c23073e45339bb6316741a0ab4))
* onFirmwareUploading calling wrong event ([3659ea9](https://github.com/juliansteenbakker/nordic_dfu/commit/3659ea9118251fee53053a5f4bab93198f7fa29f))
* separate dfu logic from flutter logic ([8c54690](https://github.com/juliansteenbakker/nordic_dfu/commit/8c546902985b43678ee36481f13b57efb7359b70))
* **spm:** correct package identity for IOS-DFU-Library dependency ([462eeaf](https://github.com/juliansteenbakker/nordic_dfu/commit/462eeaf9282891a3bfe3372e2734e1118e87829b))
* **spm:** correct package identity for IOS-DFU-Library dependency ([39d360a](https://github.com/juliansteenbakker/nordic_dfu/commit/39d360a81f51160373dfa946894ff0ecfa7dbf5b))


### Reverts

* fix dfu not working on android ([27a59d2](https://github.com/juliansteenbakker/nordic_dfu/commit/27a59d2badc06b212506b5636dc3fc24ecc47e27))

## 7.1.2
Improvements:
* [Android] Updated Nordic DFU Library to version 2.11.0. 
  This update should fix onDeviceConnecting and onDeviceDisconnecting not being called.
* [Android] Updated Kotlin to version 2.3.10.

## 7.1.1
New features:
* Update address mapping so that it works with both the original address as the changed address.
* [Darwin] Support for Swift Package Manager.
* [Darwin] Adds PrivacyInfo.

## 7.1.0
New Features:
* Added address mapping logic to handle address changes during DFU process.
* Added increment UUID support to example app.
* [Android] Added mbrSize, scope and currentMtu parameters to callback.
* [Darwin] Callback can now be set in constructor.

Breaking Changes:
* [Darwin] Changed onFirmwareUploading to onDfuProcessStarted to match Android implementation.

Bug Fixes:
* Fixed deprecation warning.
* Fixed onFirmwareUploading calling wrong event.
* Fixed function not being awaited.
* [Android] Fixed missing .zip extension to temp asset file path.
* Separated DFU logic from Flutter logic.

Other Changes:
* Made dispose async, due to underlying events.cancel being async.
* [Android] Updated Nordic DFU Library to version 2.10.1.
* [Android] Updated Kotlin to version 2.2.21.
* [Android] Updated Gradle to version 8.13.1.
* [Android] Updated minSDK and compileSDK.
* [Darwin] Updated iOS files for latest Flutter version.
* Improved example app with DFU service selector, address mapping example, and event ordering.

## 7.0.0
New Features:
* Added parallel DFU support (thanks @Flasher-MS !)
* iOS and macOS implementation have been merged in one Darwin implementation, and now share the same functionality.

Other Changes:
* All callbacks in startDfu() have been moved to DfuEventHandler class.
* AndroidSpecialOption() and IosSpecialOption() have been deprecated in favor of AndroidOptions() and DarwinOptions().
* [Android] Updated Nordic DFU Library to version 2.8.0
* [Darwin] Updated Nordic DFU Library to version 4.16.0
* [Android] Updated compileSdk to 35.

## 6.2.0
* [Android] Updated Nordic DFU Library to version 2.5.0
* [iOS & macOS] Updated Nordic DFU Library to version 4.15.3

## 6.1.4+hotfix
* [Android] Updated Nordic DFU Library to version 2.4.2
* [iOS] Updated Nordic DFU Library to version 4.15.0
* [macOS] Updated Nordic DFU Library to version 4.15.0

## 6.1.4
* [Android] Updated Nordic DFU Library to version 2.4.2
* [iOS] Updated Nordic DFU Library to version 4.15.0

## 6.1.3
* [Android] Updated Nordic DFU Library to version 2.3.1
* [Android] Fix crash on Android 14

## 6.1.2
* [Android] Fixed an issue which caused DFU to not work.

## 6.1.1
* [Android] Fix rebootTime parameter to convert to Long from Int (thanks @rstewart22 !)
* [Android] Fix build for older AGP versions.

## 6.1.0
* [Android] Added rebootTime parameter.
* [Android] Upgraded to gradle 8.

## 6.0.1
[Android] Fixed an exception when starting DFU.

## 6.0.0
macOS is now supported! The configuration is the same as for iOS.

Other changes:
* [Android] Add dataDelay and numberOfRetries parameters to androidSpecialParameter.
* [iOS] packetReceiptNotificationParameter parameter is added. Set this to 1 if you get error 308.

## 5.2.1
[Android] revert kotlin 1.8.0 to 1.7.10 due to compatibility issues.

## 5.2.0
[Android] Updated Nordic DFU Library to version 2.3.0

## 5.1.2
* [Android] Updated Nordic DFU Library to version 2.2.2
* Updated example app dependencies.

## 5.1.1
* [iOS] Fixed build for iOS.

## 5.1.0
* [Android] Fixed an issue which caused the callback to fail.
* [Android] Upgraded Nordic DFU Library to version 2.2.0
* [iOS] Upgraded Nordic DFU POD to version 4.13.0

## 5.0.1
* [Android] Upgraded Nordic DFU Library to version 2.0.3
* Upgraded some dependencies

## 5.0.0
BREAKING CHANGES:
Callback is now handled through functions in the StartDfu() method. Please see the example app for an example.

Bugs fixed:
Fixed callback not being called on both Android and iOS.

## 4.0.0
BREAKING CHANGES:
NordiDfu now uses a Singelton! The notation changes from NordicDfu.startDfu() to NordicDfu().startDfu()

New Features:
* Upgraded Nordic-DFU-Library to 2.0.2
* Upgraded Android Bluetooth Permissions.
* Upgraded other minor dependencies.
* Upgraded flutter_lints to lint for stricter analyzer.

## 3.3.0
* Upgraded Android Dependency to 1.12.1-beta01
* Upgraded Android Gradle

## 3.2.0
* Upgraded iOS Pod to 4.11.1
* Upgraded Android Dependency to 1.12.0
* Applied flutter_lints suggestion
* Upgraded gradle

## 3.1.0
* Upgraded iOS Pod to 4.10.3
* Added api docs

## 3.0.0
* Upgraded to null-safety
* Upgraded to Android Embedding V2
* Update Android library to 1.11.1
* Migrated from java to kotlin
* Add pedantic and format accordingly
* Updated several other dependencies

# Changes from flutter_nordic_dfu
## 2.4.0
* Update Android library to 1.10.1

## 2.3.0
* Update iOS library to 4.5.1

## 2.2.1
* add android x depend

## 2.2.0
* Add example project
* Cancel notification when dfu complete

## 2.1.0
* Fix android 8+ notification error
* Add some android parameter to dfu lib
* Add forceDfu parameter to dfu lib

## 2.0.0
* Add asset file support

## 1.2.0
* Update iOS dependency to 4.4.2

## 1.1.0
* Convert android kotlin code to java

## 1.0.0
* Add DefaultDfuProgressListenerAdapter

## 0.5.0+2
* fix pod bug

## 0.5.0
* change dfu iOS dependency version
* this version has bug, do not use

## 0.4.0
* migrate to android x

## 0.3.0

* Down kotlin version to 1.2.71

## 0.2.1

* Update android kotlin version to 1.3.21
* Update com.android.tools.build:gradle to 3.3.1

## 0.2.0

* Finish iOS version

## 0.1.0

* Finish android version

## 0.0.1

* Init the package.

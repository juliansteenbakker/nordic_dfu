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




















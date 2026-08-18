# nordic_dfu
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![pub package](https://img.shields.io/pub/v/nordic_dfu.svg)](https://pub.dev/packages/nordic_dfu)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/juliansteenbakker)](https://github.com/sponsors/juliansteenbakker)

Fork from [flutter_nordic_dfu](https://pub.dev/packages/flutter_nordic_dfu) and updated with latest dependencies, now with macOS support from version 6.0.0.

This library allows you to do a Device Firmware Update (DFU) of your nrf51 or
nrf52 chip from Nordic Semiconductor. It works for Android, iOS, and MacOS.

This is the implementation of the reference "[react-native-nordic-dfu](https://github.com/Pilloxa/react-native-nordic-dfu)"

For more info about the DFU process, see: [Resources](#resources)

## Run example

1. Add your dfu zip file to `example/assets/file.zip`

2. Run example project

3. Scan device

4. Start dfu


## Usage

You can pass an absolute file path or asset file to `NordicDfu`

##### Use absolute file path

```dart
await NordicDfu().startDfu(
            'EB:75:AD:E3:CA:CF', '/file/to/zip/path/file.zip'
         );
// With callback
await NordicDfu().startDfu(
      'EB:75:AD:E3:CA:CF',
      'assets/file.zip',
      fileInAsset: true,
      dfuEventHandler: DfuEventHandler(
        onProgressChanged: (
          deviceAddress,
          percent,
          speed,
          avgSpeed,
          currentPart,
          partsTotal,
        ) {
          print('deviceAddress: $deviceAddress, percent: $percent');
        },
      ),
    );
```

##### Use asset file path

```dart
/// just set [fileInAsset] true
await NordicDfu().startDfu(
            'EB:75:AD:E3:CA:CF', 'assets/file.zip',
            fileInAsset: true,
         );
```

## Migrating to 8.0.0

Version 8.0.0 removes the API that was deprecated during 7.x. Nothing was replaced in this release,
every removal has had its replacement available since the version that deprecated it.

| Removed | Replacement |
| --- | --- |
| `startDfu(androidSpecialParameter: ...)` and the `AndroidSpecialParameter` class | `startDfu(androidParameters: AndroidParameters(...))` |
| `startDfu(iosSpecialParameter: ...)` and the `IosSpecialParameter` class | `startDfu(darwinParameters: DarwinParameters(...))` |
| The individual callback arguments on `startDfu` (`onDeviceConnected`, `onDfuCompleted`, `onProgressChanged`, and the rest) | `startDfu(dfuEventHandler: DfuEventHandler(...))` with the same callback names |
| `DfuEventHandler.onFirmwareUploading` | `DfuEventHandler.onDfuProcessStarted` |
| `setAddressMapping`, `getTranslatedAddress`, `removeAddressMapping`, `clearAddressMappings` | None needed, see [Address Mapping](#address-mapping) |

`AndroidParameters` and `DarwinParameters` take the same arguments as the classes they replace, so
migrating those is a rename.

## Firmware files

The firmware you pass to `startDfu` is a Distribution packet, the ZIP produced by `nrfutil`
containing a `manifest.json`. You can pass either an absolute path or an asset path with
`fileInAsset: true`, and assets work the same way on Android, iOS and macOS.

The file does not need a `.zip` extension. Firmware downloaded to a temporary file without one, as
`http` and `dio` typically produce, is accepted on every platform.

`startDfu` reports file problems with these error codes, before any connection is attempted:

| Code | Meaning |
| --- | --- |
| `FILE_NOT_FOUND` | The path or asset does not exist. The details field carries the path that was checked. |
| `INVALID_FIRMWARE` | The file exists but is not a valid Distribution packet. The details field carries the reason from the DFU library, for example a missing `manifest.json`. |
| `ABNORMAL_PARAMETER` | `address` or `filePath` was missing from the call. |
| `DFU_START_ERROR` | The DFU library refused to start, for example on a malformed device address. |

On Android, assets are copied into the app's cache directory before the update and the copy is
deleted once the DFU finishes, fails, or is aborted.

## Android permissions

From version 8.0.0 this plugin no longer declares Bluetooth permissions in its own
`AndroidManifest.xml`, so your app decides which ones end up in the merged manifest. Add what your
app actually needs to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Required to scan for devices on API 31+. Add usesPermissionFlags="neverForLocation" when
         you can strongly assert that your app never derives physical location from scan results;
         the location permissions below are then not needed at all on API 31+. -->
    <uses-permission
        android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation"
        tools:targetApi="s" />

    <!-- Only required if you scan on API 30 and below, where scanning implies location access. -->
    <uses-permission
        android:name="android.permission.ACCESS_FINE_LOCATION"
        android:maxSdkVersion="30" />
</manifest>
```

Two things are still contributed for you and need no action:

- `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_CONNECTED_DEVICE` come from this plugin, because the
  DFU services it declares run as a foreground service unless you pass
  `AndroidParameters(startAsForegroundService: false)`.
- `BLUETOOTH` and `BLUETOOTH_ADMIN` (both `maxSdkVersion="30"`) and `BLUETOOTH_CONNECT` come from
  the [Android-DFU-Library](https://github.com/NordicSemiconductor/Android-DFU-Library) itself.

To change or drop one of the permissions supplied by the DFU library, override it with
`tools:node="remove"` or `tools:node="replace"`:

```xml
<uses-permission
    android:name="android.permission.BLUETOOTH_ADMIN"
    tools:node="remove" />
```

### Upgrading from 7.x

Previously the plugin declared `BLUETOOTH_SCAN`, `ACCESS_FINE_LOCATION` and
`ACCESS_COARSE_LOCATION` (the last two via `uses-permission-sdk-23`, so on every API level from 23
up). If your app relies on those and does not declare them itself, add them as shown above, or
scanning stops working after upgrading. Apps that were fighting the old declarations with
`tools:maxSdkVersion` or `tools:node="remove"` can delete those workarounds.

## Parallel DFU

Available from version 7.0.0

### Concurrent DFU Processes
- DFU operations can run simultaneously on multiple devices.
- Callbacks are triggered correctly and independently for each device.

### Interface change
- Updated `abortDfu` method to include an optional `address` parameter:
    - **If an address is provided:** The DFU process for the specified device will be aborted. **(iOS only)**
    - **If no address is provided:** All active DFU processes will be aborted.
- Added error handling for `abortDfu`:
    - `FlutterError("INVALID_ADDRESS")` is thrown if the provided address does not match any active DFU process.
    - `FlutterError("NO_ACTIVE_DFU")` is thrown if no address is provided and there are no active DFU processes.

### iOS
- ✅ Devices update in parallel.
- ✅ Callbacks set in `startDfu` are called independently for each device.
- ✅ All active DFU processes can be aborted using the `abortDfu` method without an `address`.
- ✅ DFU processes can be individually aborted using the `abortDfu` method with an `address`.

### Android
- ✅ Devices update in parallel (set limit of 8).
- ✅ Callbacks set in `startDfu`  are called independently for each device.
- ✅ All active DFU processes can be aborted using the `abortDfu` method without an `address`.
- ❌ DFU processes cannot be individually aborted using the `abortDfu` method with an `address` due to current limitations in the underlying [Android-DFU-Library](https://github.com/NordicSemiconductor/Android-DFU-Library).
- ⚠️ Devices with adjacent addresses (`…:46` and `…:47`) should be updated one after another. A device in bootloader mode advertises with its address incremented by one, so the [Android-DFU-Library](https://github.com/NordicSemiconductor/Android-DFU-Library) cannot tell such a pair apart and may report their events against the wrong device. A warning is logged when this is detected.

## Address Mapping

A device performing a buttonless update reboots into its bootloader, which commonly advertises with a
different BLE address (usually the original one, last byte incremented). The plugin handles this: every
event is reported with the address you passed to `startDfu`, on every platform, for the whole update.

`setAddressMapping`, `getTranslatedAddress`, `removeAddressMapping` and `clearAddressMappings` were
deprecated in 7.2.0 and are removed in 8.0.0. Delete your calls to them, along with any bootloader
scanning that existed only to feed them, no replacement is needed.

## Resources

-   [DFU Introduction](https://docs.nordicsemi.com/bundle/ncs-latest/page/nrf/samples/dfu.html "BLE Bootloader/DFU")
-   [Secure DFU Introduction](https://docs.nordicsemi.com/bundle/ncs-latest/page/nrf/app_dev/bootloaders_dfu/mcuboot_nsib/bootloader.html "BLE Secure DFU Bootloader")
-   [How to create init packet](https://github.com/NordicSemiconductor/Android-nRF-Connect/tree/main/init%20packet%20handling "Init packet handling")
-   [nRF51 Development Kit (DK)](https://www.nordicsemi.com/eng/Products/nRF51-DK "nRF51 DK") (compatible with Arduino Uno Revision 3)
-   [nRF52 Development Kit (DK)](https://www.nordicsemi.com/eng/Products/Bluetooth-Smart-Bluetooth-low-energy/nRF52-DK "nRF52 DK") (compatible with Arduino Uno Revision 3)


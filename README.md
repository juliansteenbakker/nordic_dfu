# nordic_dfu
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![pub package](https://img.shields.io/pub/v/nordic_dfu.svg)](https://pub.dev/packages/nordic_dfu)
[![mobile_scanner](https://github.com/juliansteenbakker/nordic_dfu/actions/workflows/flutter_format.yml/badge.svg)](https://github.com/juliansteenbakker/nordic_dfu/actions/workflows/flutter_format.yml)
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

## Resources

-   [DFU Introduction](https://infocenter.nordicsemi.com/topic/com.nordic.infocenter.sdk5.v11.0.0/examples_ble_dfu.html?cp=6_0_0_4_3_1 "BLE Bootloader/DFU")
-   [Secure DFU Introduction](https://infocenter.nordicsemi.com/topic/com.nordic.infocenter.sdk5.v12.0.0/ble_sdk_app_dfu_bootloader.html?cp=4_0_0_4_3_1 "BLE Secure DFU Bootloader")
-   [How to create init packet](https://github.com/NordicSemiconductor/Android-nRF-Connect/tree/master/init%20packet%20handling "Init packet handling")
-   [nRF51 Development Kit (DK)](https://www.nordicsemi.com/eng/Products/nRF51-DK "nRF51 DK") (compatible with Arduino Uno Revision 3)
-   [nRF52 Development Kit (DK)](https://www.nordicsemi.com/eng/Products/Bluetooth-Smart-Bluetooth-low-energy/nRF52-DK "nRF52 DK") (compatible with Arduino Uno Revision 3)


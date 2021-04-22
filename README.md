# nordic-dfu [![pub package](https://img.shields.io/pub/v/nordic_dfu.svg)](https://pub.dev/packages/nordic_dfu)

Fork from [flutter_nordic_dfu](https://pub.dev/packages/flutter_nordic_dfu)
This library allows you to do a Device Firmware Update (DFU) of your nrf51 or
nrf52 chip from Nordic Semiconductor. It works for Android and iOS.

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
/// You can define your ProgressListenerListener
await NordicDfu.startDfu(
            'EB:75:AD:E3:CA:CF', '/file/to/zip/path/file.zip',
            progressListener: ProgressListenerListener(),
         );


class ProgressListenerListener extends DfuProgressListenerAdapter {
  @override
  void onProgressChanged(String deviceAddress, int percent, double speed,
      double avgSpeed, int currentPart, int partsTotal) {
    super.onProgressChanged(
        deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal);
    print('deviceAddress: $deviceAddress, percent: $percent');
  }
}

/// Or you can use DefaultDfuProgressListenerAdapter
await NordicDfu.startDfu(
      'EB:75:AD:E3:CA:CF',
      'assets/file.zip',
      fileInAsset: true,
      progressListener:
          DefaultDfuProgressListenerAdapter(onProgressChangedHandle: (
        deviceAddress,
        percent,
        speed,
        avgSpeed,
        currentPart,
        partsTotal,
      ) {
        print('deviceAddress: $deviceAddress, percent: $percent');
      }),
    );
```

##### Use asset file path

```dart
/// just set [fileInAsset] true
await NordicDfu.startDfu(
            'EB:75:AD:E3:CA:CF', 'assets/file.zip',
            progressListener: ProgressListenerListener(),
            fileInAsset: true,
         );

class ProgressListenerListener extends DfuProgressListenerAdapter {
  @override
  void onProgressChanged(String deviceAddress, int percent, double speed,
      double avgSpeed, int currentPart, int partsTotal) {
    super.onProgressChanged(
        deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal);
    print('deviceAddress: $deviceAddress, percent: $percent');
  }
}
```

## Resources

-   [DFU Introduction](http://infocenter.nordicsemi.com/topic/com.nordic.infocenter.sdk5.v11.0.0/examples_ble_dfu.html?cp=6_0_0_4_3_1 "BLE Bootloader/DFU")
-   [Secure DFU Introduction](http://infocenter.nordicsemi.com/topic/com.nordic.infocenter.sdk5.v12.0.0/ble_sdk_app_dfu_bootloader.html?cp=4_0_0_4_3_1 "BLE Secure DFU Bootloader")
-   [How to create init packet](https://github.com/NordicSemiconductor/Android-nRF-Connect/tree/master/init%20packet%20handling "Init packet handling")
-   [nRF51 Development Kit (DK)](http://www.nordicsemi.com/eng/Products/nRF51-DK "nRF51 DK") (compatible with Arduino Uno Revision 3)
-   [nRF52 Development Kit (DK)](http://www.nordicsemi.com/eng/Products/Bluetooth-Smart-Bluetooth-low-energy/nRF52-DK "nRF52 DK") (compatible with Arduino Uno Revision 3)


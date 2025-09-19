# Nordic DFU Address Mapping Feature

## Overview

This document explains the Address Mapping feature.

## What is Address Mapping?

During firmware updates for Bluetooth devices, the device's MAC address can change when it enters DFU mode. The Address Mapping feature provides a way to track and translate between a device's original address and its DFU mode address, ensuring that events and callbacks are correctly associated with the right device throughout the update process.

## Why Address Mapping is Important

When a Bluetooth device enters DFU mode, it often advertises itself with a different MAC address. For example, most devices implement the "plus 1" operation, where the DFU mode address is derived by incrementing the original MAC address by 1.

For example:
- Original device address: `C8:DF:84:12:34:56`
- DFU mode address: `C8:DF:84:12:34:57` (last byte incremented by 1)

Without address mapping, the application would lose track of the device during the critical firmware update process, as it would appear as a completely different device.

## Added Functionality


```dart
// Before starting DFU
void startFirmwareUpdate() {
// Get the original device address
String originalAddress = device.remoteId.str;

// When the device enters DFU mode and you detect the new address
String dfuModeAddress = dfuDevice.remoteId.str;

// Set the mapping in the Nordic DFU instance
NordicDfu().setAddressMapping(dfuModeAddress, originalAddress);

// Start the DFU process
NordicDfu().startDfu(originalAddress, firmwareFilePath, ...);
}
```

To make it dynamic, you can use like this:
```dart
// When enabling DFU mode for the device
onEnablingDfuMode: (deviceAddress) {
  widget._logger.info(
      "@onEnablingDfuMode[3]: ENABLING DFU MODE for $deviceAddress");
  if (deviceAddress == deviceId) {
    _startScanForDfuDevice();
  }
},

// In the scan function, when the DFU device is found (for example by name)
NordicDfu().setAddressMapping(dfuDevice.remoteId.str, deviceId);
```
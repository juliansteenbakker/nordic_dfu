// Ignore deprecation warnings for onFirmwareUploading to maintain backward compatibility
// while transitioning users to onDfuProcessStarted
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/foundation.dart';

/// Callback for when DFU status has changed.
/// [address] - The device's address associated with the event.
typedef DfuCallback = void Function(String address);

/// Callback for when a DFU error occurs.
/// [address] - The device's address associated with the error.
/// [error] - The error code.
/// [errorType] - The type of the error.
/// [message] - The error message.
typedef DfuErrorCallback = void Function(
  String address,
  int error,
  int errorType,
  String message,
);

/// Callback for DFU progress updates.
/// [address] - The device's address associated with the progress update.
/// [percent] - The percentage of the DFU process completed.
/// [speed] - The current speed of the DFU process.
/// [avgSpeed] - The average speed of the DFU process.
/// [currentPart] - The current firmware part being uploaded.
/// [totalParts] - The total number of firmware parts to be uploaded.
typedef DfuProgressCallback = void Function(
  String address,
  int percent,
  double speed,
  double avgSpeed,
  int currentPart,
  int totalParts,
);

/// A class representing event handlers for a Device Firmware Update (DFU) process.
///
/// This class provides a set of callback functions to handle various states and events
/// during the DFU process, including device connection, progress updates, errors, and more.
class DfuEventHandler {
  /// Creates an instance of [DfuEventHandler] with the required callback functions.
  ///
  /// All callbacks are optional, and only those relevant to your use case need to be provided.
  DfuEventHandler({
    this.onDeviceConnected,
    this.onDeviceConnecting,
    this.onDeviceDisconnected,
    this.onDeviceDisconnecting,
    this.onDfuAborted,
    this.onDfuCompleted,
    this.onDfuProcessStarted,
    this.onDfuProcessStarting,
    this.onEnablingDfuMode,
    this.onFirmwareValidating,
    @Deprecated('Use onDfuProcessStarted instead') this.onFirmwareUploading,
    this.onError,
    this.onProgressChanged,
  });

  /// Callback triggered when the device has successfully connected.
  ///
  /// Not available on iOS/Darwin
  DfuCallback? onDeviceConnected;

  /// Callback triggered when the connection process to the device is ongoing.
  DfuCallback? onDeviceConnecting;

  /// Callback triggered when the device has been disconnected.
  ///
  /// Not available on iOS/Darwin
  DfuCallback? onDeviceDisconnected;

  /// Callback triggered when the disconnection process from the device is ongoing.
  DfuCallback? onDeviceDisconnecting;

  /// Callback triggered when the DFU process is aborted.
  DfuCallback? onDfuAborted;

  /// Callback triggered when the DFU process is successfully completed.
  DfuCallback? onDfuCompleted;

  /// Callback triggered when the DFU process has started.
  DfuCallback? onDfuProcessStarted;

  /// Callback triggered when the DFU process is in the initial stage of starting.
  DfuCallback? onDfuProcessStarting;

  /// Callback triggered when enabling DFU mode on the device.
  ///
  /// Only called when device needs to switch to dfu mode.
  DfuCallback? onEnablingDfuMode;

  /// Callback triggered when the firmware validation step is in progress.
  ///
  /// Only called when firmware needs to be validated.
  DfuCallback? onFirmwareValidating;

  /// Callback triggered when the firmware validation step is in progress.
  ///
  /// Not available on Android
  @Deprecated('Use onDfuProcessStarted instead')
  DfuCallback? onFirmwareUploading;

  /// Callback triggered when an error occurs during the DFU process.
  ///
  /// Provides detailed error information.
  DfuErrorCallback? onError;

  /// Callback triggered to provide progress updates during the DFU process.
  ///
  /// Includes information such as percentage completed and current operation details.
  DfuProgressCallback? onProgressChanged;

  /// Dispatches the event based on the address, key and its value.
  void dispatchEvent(String key, Map<String, dynamic>? value, String address) {
    switch (key) {
      case 'onDeviceConnected':
        onDeviceConnected?.call(address);
      case 'onDeviceConnecting':
        onDeviceConnecting?.call(address);
      case 'onDeviceDisconnected':
        onDeviceDisconnected?.call(address);
      case 'onDeviceDisconnecting':
        onDeviceDisconnecting?.call(address);
      case 'onDfuAborted':
        onDfuAborted?.call(address);
      case 'onDfuCompleted':
        onDfuCompleted?.call(address);
      case 'onDfuProcessStarted':
        onDfuProcessStarted?.call(address);
        // Backward compatibility: call deprecated callback
        onFirmwareUploading?.call(address);
      case 'onDfuProcessStarting':
        onDfuProcessStarting?.call(address);
      case 'onEnablingDfuMode':
        onEnablingDfuMode?.call(address);
      case 'onFirmwareValidating':
        onFirmwareValidating?.call(address);
      case 'onError':
        onError?.call(
          address,
          value!['error'] as int,
          value['errorType'] as int,
          value['message'] as String,
        );
      case 'onProgressChanged':
        onProgressChanged?.call(
          address,
          value!['percent'] as int,
          value['speed'] as double,
          value['avgSpeed'] as double,
          value['currentPart'] as int,
          value['partsTotal'] as int,
        );
      default:
        debugPrint('Unknown event key: $key');
    }
  }
}

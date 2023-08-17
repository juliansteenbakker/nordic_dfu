import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nordic_dfu/src/android_special_paramter.dart';
import 'package:nordic_dfu/src/ios_special_parameter.dart';

/// Callback for when dfu status has changed
/// [address] Device with error
typedef DfuCallback = void Function(String address);

/// Callback for when dfu has error
/// [address] Device with error
/// [error] Error which occurs
/// [errorType] Error type which has occured
/// [message] Message that has been thrown with error
typedef DfuErrorCallback = void Function(
  String address,
  int error,
  int errorType,
  String message,
);

/// Callback for when the dfu progress has changed
/// [address] Device with dfu
/// [percent] Percentage dfu completed
/// [speed] Speed of the dfu proces
/// [avgSpeed] Average speed of the dfu process
/// [currentPart] Current part being uploaded
/// [partsTotal] All parts that need to be uploaded
typedef DfuProgressCallback = void Function(
  String address,
  int percent,
  double speed,
  double avgSpeed,
  int currentPart,
  int totalParts,
);

/// This singleton handles the DFU process.
class NordicDfu {
  static final NordicDfu _singleton = NordicDfu._internal();

  factory NordicDfu() {
    return _singleton;
  }

  NordicDfu._internal();

  static const String namespace = 'dev.steenbakker.nordic_dfu';
  static const MethodChannel _methodChannel =
      MethodChannel('$namespace/method');
  static const EventChannel _eventChannel = EventChannel('$namespace/event');
  StreamSubscription? events;

  /// Start the DFU Process.
  /// Required:
  /// [address] android: mac address iOS: device uuid
  /// [filePath] zip file path
  ///
  /// Optional:
  /// [name] The device name
  /// [fileInAsset] if [filePath] is a asset path like 'asset/file.zip', must set this value to true, else false
  /// [forceDfu] Legacy DFU only, see in nordic library, default is false
  /// [numberOfPackets] The number of packets of firmware data to be received by the DFU target before sending a new Packet Receipt Notification.
  /// [enableUnsafeExperimentalButtonlessServiceInSecureDfu] see in nordic library, default is false
  /// [androidSpecialParameter] this parameters is only used by android lib
  /// [iosSpecialParameter] this parameters is only used by ios lib
  ///
  /// Callbacks:
  /// [onDeviceConnected] Callback for when device is connected
  /// [onDeviceConnecting] Callback for when device is connecting
  /// [onDeviceDisconnected] Callback for when device is disconnected
  /// [onDeviceDisconnecting] Callback for when device is disconnecting
  /// [onDfuAborted] Callback for dfu is Aborted
  /// [onDfuCompleted] Callback for when dfu is completed
  /// [onDfuProcessStarted] Callback for when dfu has been started
  /// [onDfuProcessStarting] Callback for when dfu is starting
  /// [onEnablingDfuMode] Callback for when dfu mode is being enabled
  /// [onFirmwareValidating] Callback for when dfu is being verified
  /// [onError] Callback for when dfu has error
  /// [onProgressChanged] Callback for when the dfu progress has changed
  Future<String?> startDfu(
    String address,
    String filePath, {
    String? name,
    bool? fileInAsset,
    bool? forceDfu,
    int? numberOfPackets,
    bool? enableUnsafeExperimentalButtonlessServiceInSecureDfu,
    AndroidSpecialParameter androidSpecialParameter =
        const AndroidSpecialParameter(),
    IosSpecialParameter iosSpecialParameter = const IosSpecialParameter(),
    DfuCallback? onDeviceConnected,
    DfuCallback? onDeviceConnecting,
    DfuCallback? onDeviceDisconnected,
    DfuCallback? onDeviceDisconnecting,
    DfuCallback? onDfuAborted,
    DfuCallback? onDfuCompleted,
    DfuCallback? onDfuProcessStarted,
    DfuCallback? onDfuProcessStarting,
    DfuCallback? onEnablingDfuMode,
    DfuCallback? onFirmwareValidating,
    DfuErrorCallback? onError,
    DfuProgressCallback? onProgressChanged,
  }) async {
    events = _eventChannel.receiveBroadcastStream().listen((data) {
      data as Map;
      for (final key in data.keys) {
        switch (key) {
          case 'onDeviceConnected':
            onDeviceConnected?.call(data[key] as String);
            break;
          case 'onDeviceConnecting':
            onDeviceConnecting?.call(data[key] as String);
            break;
          case 'onDeviceDisconnected':
            onDeviceDisconnected?.call(data[key] as String);
            break;
          case 'onDeviceDisconnecting':
            onDeviceDisconnecting?.call(data[key] as String);
            break;
          case 'onDfuAborted':
            onDfuAborted?.call(data[key] as String);
            events?.cancel();
            break;
          case 'onDfuCompleted':
            onDfuCompleted?.call(data[key] as String);
            events?.cancel();
            break;
          case 'onDfuProcessStarted':
            onDfuProcessStarted?.call(data[key] as String);
            break;
          case 'onDfuProcessStarting':
            onDfuProcessStarting?.call(data[key] as String);
            break;
          case 'onEnablingDfuMode':
            onEnablingDfuMode?.call(data[key] as String);
            break;
          case 'onFirmwareValidating':
            onFirmwareValidating?.call(data[key] as String);
            break;
          case 'onError':
            final Map<String, dynamic> result =
                Map<String, dynamic>.from(data[key] as Map);
            onError?.call(
              result['deviceAddress'] as String,
              result['error'] as int,
              result['errorType'] as int,
              result['message'] as String,
            );
            events?.cancel();
            break;
          case 'onProgressChanged':
            final Map<String, dynamic> result =
                Map<String, dynamic>.from(data[key] as Map);
            onProgressChanged?.call(
              result['deviceAddress'] as String,
              result['percent'] as int,
              result['speed'] as double,
              result['avgSpeed'] as double,
              result['currentPart'] as int,
              result['partsTotal'] as int,
            );
            break;
        }
      }
    });

    return _methodChannel.invokeMethod('startDfu', <String, dynamic>{
      'address': address,
      'filePath': filePath,
      'name': name,
      'fileInAsset': fileInAsset,
      'forceDfu': forceDfu,
      'numberOfPackets': numberOfPackets,
      'enableUnsafeExperimentalButtonlessServiceInSecureDfu':
          enableUnsafeExperimentalButtonlessServiceInSecureDfu,
      ...androidSpecialParameter.toJson(),
      ...iosSpecialParameter.toJson(),
    });
  }

  Future<String?> abortDfu() async {
    return _methodChannel.invokeMethod('abortDfu');
  }
}

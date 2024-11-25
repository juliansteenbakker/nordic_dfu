import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
/// [totalParts] All parts that need to be uploaded
typedef DfuProgressCallback = void Function(
  String address,
  int percent,
  double speed,
  double avgSpeed,
  int currentPart,
  int totalParts,
);

class DfuEventHandler {
  DfuCallback? onDeviceConnected;
  DfuCallback? onDeviceConnecting;
  DfuCallback? onDeviceDisconnected;
  DfuCallback? onDeviceDisconnecting;
  DfuCallback? onDfuAborted;
  DfuCallback? onDfuCompleted;
  DfuCallback? onDfuProcessStarted;
  DfuCallback? onDfuProcessStarting;
  DfuCallback? onEnablingDfuMode;
  DfuCallback? onFirmwareValidating;
  DfuErrorCallback? onError;
  DfuProgressCallback? onProgressChanged;

  DfuEventHandler({
    required this.onDeviceConnected,
    required this.onDeviceConnecting,
    required this.onDeviceDisconnected,
    required this.onDeviceDisconnecting,
    required this.onDfuAborted,
    required this.onDfuCompleted,
    required this.onDfuProcessStarted,
    required this.onDfuProcessStarting,
    required this.onEnablingDfuMode,
    required this.onFirmwareValidating,
    required this.onError,
    required this.onProgressChanged,
  });
}

/// This singleton handles the DFU process.
class NordicDfu {
  /// Factory for initiating the Singleton
  factory NordicDfu() => _singleton;

  NordicDfu._internal();
  static final NordicDfu _singleton = NordicDfu._internal();

  static const _namespace = 'dev.steenbakker.nordic_dfu';
  static const MethodChannel _methodChannel =
      MethodChannel('$_namespace/method');
  static const EventChannel _eventChannel = EventChannel('$_namespace/event');

  StreamSubscription<void>? _events;
  Map<String, DfuEventHandler> _eventHandlerMap = {};

  void _ensureEventStreamSetup() {
    if (_events != null) return; // already setup

    _events = _eventChannel.receiveBroadcastStream().listen((data) {
      data as Map;
      for (final key in data.keys) {
        switch (key) {
          case 'onDeviceConnected':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDeviceConnected?.call(address);
            break;
          case 'onDeviceConnecting':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDeviceConnecting?.call(address);
            break;
          case 'onDeviceDisconnected':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDeviceDisconnected?.call(address);
            break;
          case 'onDeviceDisconnecting':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDeviceDisconnecting?.call(address);
            break;
          case 'onDfuAborted':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDfuAborted?.call(address);
            _eventHandlerMap.remove(address);
            break;
          case 'onDfuCompleted':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDfuCompleted?.call(address);
            _eventHandlerMap.remove(address);
            break;
          case 'onDfuProcessStarted':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDfuProcessStarted?.call(address);
            break;
          case 'onDfuProcessStarting':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onDfuProcessStarting?.call(address);
            break;
          case 'onEnablingDfuMode':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onEnablingDfuMode?.call(address);
            break;
          case 'onFirmwareValidating':
            final address = data[key] as String;
            _eventHandlerMap[address]?.onFirmwareValidating?.call(data[key] as String);
            break;
          case 'onError':
            final result = Map<String, dynamic>.from(data[key] as Map);
            final address = result['deviceAddress'] as String;
            _eventHandlerMap[address]?.onError?.call(
              address,
              result['error'] as int,
              result['errorType'] as int,
              result['message'] as String,
            );
            _eventHandlerMap.remove(address);
            break;
          case 'onProgressChanged':
            final result = Map<String, dynamic>.from(data[key] as Map);
            final address = result['deviceAddress'] as String;
            _eventHandlerMap[address]?.onProgressChanged?.call(
              address,
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
  }

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
    _eventHandlerMap[address] = DfuEventHandler(
      onDeviceConnected: onDeviceConnected,
      onDeviceConnecting: onDeviceConnecting,
      onDeviceDisconnected: onDeviceDisconnected,
      onDeviceDisconnecting: onDeviceDisconnecting,
      onDfuAborted: onDfuAborted,
      onDfuCompleted: onDfuCompleted,
      onDfuProcessStarted: onDfuProcessStarted,
      onDfuProcessStarting: onDfuProcessStarting,
      onEnablingDfuMode: onEnablingDfuMode,
      onFirmwareValidating: onFirmwareValidating,
      onError: onError,
      onProgressChanged: onProgressChanged,
    );

    _ensureEventStreamSetup();

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

  /// Abort DFU while in progress.
  /// 
  /// Optional:
  /// [address] specifies the device to abort. If no [address] is provided, 
  /// all running DFU processes will be aborted.
  /// 
  /// On Android, due to current limitations of the underlying Android-DFU-Library, 
  /// the abort command is not device-specific and will abort all active DFU processes, 
  /// even if a specific [address] is provided.
  Future<String?> abortDfu({
    String? address
  }) async {
    if (kDebugMode && address != null && Platform.isAndroid) {
      print("[NordicDfu:abortDfu] Warning: abortDfu will abort all DFU processes on Android");
    }

    return _methodChannel.invokeMethod('abortDfu',
      address != null ? <String, dynamic>{ 'address': address } : {}
    );
  }
}

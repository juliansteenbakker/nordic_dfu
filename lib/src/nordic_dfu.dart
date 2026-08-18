import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nordic_dfu/src/dfu_event_handler.dart';
import 'package:nordic_dfu/src/parameters/android_parameters.dart';
import 'package:nordic_dfu/src/parameters/darwin_parameters.dart';

/// A singleton class to handle the Nordic DFU process.
class NordicDfu {
  /// Factory for initiating the Singleton
  factory NordicDfu() => _singleton;

  NordicDfu._internal();

  static final NordicDfu _singleton = NordicDfu._internal();

  static const String _methodChannelName = 'dev.steenbakker.nordic_dfu/method';
  static const String _eventChannelName = 'dev.steenbakker.nordic_dfu/event';

  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  static const EventChannel _eventChannel = EventChannel(_eventChannelName);

  StreamSubscription<void>? _events;
  final Map<String, DfuEventHandler> _eventHandlerMap = {};

  void _ensureEventStreamSetup() {
    if (_events != null) return;

    _events = _eventChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onError,
        );
  }

  void _onEvent(dynamic data) {
    if (data is! Map) {
      debugPrint('Return value is not a map but ${data.runtimeType} $data');
      return;
    }

    final events = Map<String, dynamic>.from(data);
    for (final entry in events.entries) {
      _handleSingleEvent(entry.key, entry.value);
    }
  }

  void _onError(dynamic error) {
    debugPrint('Error in event stream: $error');
  }

  void _handleSingleEvent(String key, dynamic value) {
    if (value == null) {
      debugPrint('Value is null for key: $key');
      return;
    }

    final String address;
    final Map<String, dynamic>? values;

    if (value is Map) {
      address = value['deviceAddress'] as String;
      values = Map<String, dynamic>.from(value);
    } else {
      address = value as String;
      values = null;
    }

    final handler = _eventHandlerMap[address];
    handler?.dispatchEvent(key, values, address);
  }

  /// Starts the DFU process.
  Future<String?> startDfu(
    String address,
    String filePath, {
    String? name,
    bool fileInAsset = false,
    bool forceDfu = false,
    int? numberOfPackets,
    bool enableUnsafeExperimentalButtonlessServiceInSecureDfu = false,
    AndroidParameters androidParameters = const AndroidParameters(),
    DarwinParameters darwinParameters = const DarwinParameters(),
    DfuEventHandler? dfuEventHandler,
  }) async {
    _eventHandlerMap[address] = DfuEventHandler(
      onDeviceConnected: dfuEventHandler?.onDeviceConnected,
      onDeviceConnecting: dfuEventHandler?.onDeviceConnecting,
      onDeviceDisconnected: dfuEventHandler?.onDeviceDisconnected,
      onDeviceDisconnecting: dfuEventHandler?.onDeviceDisconnecting,
      onDfuAborted: dfuEventHandler?.onDfuAborted,
      onDfuCompleted: dfuEventHandler?.onDfuCompleted,
      onDfuProcessStarted: dfuEventHandler?.onDfuProcessStarted,
      onDfuProcessStarting: dfuEventHandler?.onDfuProcessStarting,
      onEnablingDfuMode: dfuEventHandler?.onEnablingDfuMode,
      onFirmwareValidating: dfuEventHandler?.onFirmwareValidating,
      onError: dfuEventHandler?.onError,
      onProgressChanged: dfuEventHandler?.onProgressChanged,
    );

    _ensureEventStreamSetup();

    return _methodChannel.invokeMethod('startDfu', {
      'address': address,
      'filePath': filePath,
      'name': name,
      'fileInAsset': fileInAsset,
      'forceDfu': forceDfu,
      'numberOfPackets': numberOfPackets,
      'enableUnsafeExperimentalButtonlessServiceInSecureDfu':
          enableUnsafeExperimentalButtonlessServiceInSecureDfu,
      ...androidParameters.toJson(),
      ...darwinParameters.toJson(),
    });
  }

  /// Aborts the DFU process.
  Future<String?> abortDfu({String? address}) async {
    if (address != null && Platform.isAndroid) {
      debugPrint(
        '[NordicDfu:abortDfu] Warning: aborting all DFU processes on Android',
      );
    }

    return _methodChannel.invokeMethod(
      'abortDfu',
      address != null ? {'address': address} : <String, dynamic>{},
    );
  }

  /// Disposes of the event stream subscription.
  Future<void> dispose() async {
    await _events?.cancel();
    _events = null;
  }
}

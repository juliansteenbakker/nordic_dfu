import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nordic_dfu/nordic_dfu.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class DfuEvent {
  DfuEvent({
    required this.timestamp,
    required this.eventName,
    required this.message,
    this.isError = false,
  });
  final DateTime timestamp;
  final String eventName;
  final String message;
  final bool isError;
}

class ExampleDfuState {
  ExampleDfuState({
    required this.dfuRunning,
    this.progressPercent,
    this.filePath,
    this.lastError,
  });
  bool dfuRunning = false;
  int? progressPercent;
  String? filePath;
  String? lastError;
  final List<DfuEvent> events = [];

  void addEvent(String eventName, String message, {bool isError = false}) {
    events.add(DfuEvent(
      timestamp: DateTime.now(),
      eventName: eventName,
      message: message,
      isError: isError,
    ));
  }

  void clearEvents() {
    events.clear();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static const tag = 'nordic_dfu_example:';
  StreamSubscription<ScanResult>? scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  Map<String, ExampleDfuState> dfuStateMap = {};
  bool get anyDfuRunning => dfuStateMap.values.any((state) => state.dfuRunning);

  Future<void> doDfu(BuildContext context, String deviceId) async {
    final messenger = ScaffoldMessenger.of(context);
    stopScan();

    // Pick ZIP file from device storage
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select DFU firmware file (.zip)',
    );

    if (result == null) {
      debugPrint('$tag File selection cancelled');
      return;
    }

    final filePath = result.files.single.path;
    if (filePath == null || filePath.isEmpty) {
      debugPrint('$tag Invalid file path');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Invalid file path'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('$tag Selected firmware file: $filePath');

    // Start DFU with the selected file
    await _startDfu(context, deviceId, filePath);
  }

  Future<void> retryDfu(BuildContext context, String deviceId) async {
    final state = dfuStateMap[deviceId];
    if (state?.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No previous file path found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('$tag Retrying DFU with file: ${state!.filePath}');
    await _startDfu(context, deviceId, state.filePath!);
  }

  Future<void> _startDfu(BuildContext context, String deviceId, String filePath) async {
    final messenger = ScaffoldMessenger.of(context)
    ..showSnackBar(
      SnackBar(
        content: Text('Starting DFU with file: ${filePath.split('/').last}'),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      dfuStateMap[deviceId] = ExampleDfuState(
        dfuRunning: true,
        filePath: filePath,
      );
      dfuStateMap[deviceId]?.clearEvents();
      dfuStateMap[deviceId]?.addEvent('File Selected', 'File: ${filePath.split('/').last}');
    });

    // Auto-open timeline dialog when DFU starts
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _showEventTimeline(context, deviceId);
      }
    });
    try {
      final eventHandler = DfuEventHandler(
        onDeviceConnecting: (string) {
          debugPrint('$tag device connecting: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Connecting', 'Connecting to device...');
          });
        },
        onDeviceConnected: (string) {
          debugPrint('$tag device connected: $string'); //1
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Connected', 'Device connected successfully');
          });
        },
        onDeviceDisconnecting: (string) { // 3
          debugPrint('$tag device disconnecting: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Disconnecting', 'Disconnecting from device...');
          });
        },
        onDeviceDisconnected: (string) { // 4
          debugPrint('$tag device disconnected: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Disconnected', 'Device disconnected');
          });
        },
        onDfuAborted: (string) {
          debugPrint('$tag dfu aborted: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Aborted', 'DFU process aborted by user', isError: true);
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text('DFU aborted for $string'),
              backgroundColor: Colors.orange,
            ),
          );
        },
        onDfuCompleted: (string) { //5
          debugPrint('$tag dfu completed: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Completed', 'DFU completed successfully! ✓');
            dfuStateMap[deviceId]?.lastError = null;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text('DFU completed successfully for $string'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onDfuProcessStarted: (string) {// start
          debugPrint('$tag dfu process started: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Process Started', 'DFU process started, uploading firmware...');
          });
        },
        onDfuProcessStarting: (string) {
          debugPrint('$tag dfu process starting: $string'); //2
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Process Starting', 'Initializing DFU process...');
          });
        },
        onEnablingDfuMode: (string) {
          debugPrint('$tag dfu enabled: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Enabling DFU Mode', 'Switching device to DFU mode...');
          });
        },
        onFirmwareValidating: (string) {
          debugPrint('$tag firmware validating: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Validating', 'Validating firmware...');
          });
        },
        onFirmwareUploading: (string) {
          debugPrint('$tag firmware uploading: $string');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Uploading', 'Uploading firmware to device...');
          });
        },
        onError: (
          address,
          error,
          errorType,
          message,
        ) {
          debugPrint(
              '$tag error: device $address, error $error, errorType $errorType, message $message');
          setState(() {
            dfuStateMap[deviceId]?.addEvent('Error', 'Error $error: $message', isError: true);
            dfuStateMap[deviceId]?.lastError = message;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text('DFU Error: $message'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        },
        onProgressChanged: (
          deviceAddress,
          percent,
          speed,
          avgSpeed,
          currentPart,
          partsTotal,
        ) {
          debugPrint(
              '$tag progress changed: device $deviceAddress, percent: $percent, speed $speed, avgSpeed $avgSpeed, currentPart $currentPart, total parts: $partsTotal');
          setState(() {
            dfuStateMap[deviceId]?.progressPercent = percent;
            if (percent % 10 == 0 || percent == 100) {
              dfuStateMap[deviceId]?.addEvent(
                'Progress $percent%',
                'Part $currentPart/$partsTotal - Speed: ${speed.toStringAsFixed(1)} B/s',
              );
            }
          });
        },
      );

      final s = await NordicDfu().startDfu(
        deviceId,
        filePath,
        dfuEventHandler: eventHandler,
        androidParameters: const AndroidParameters(rebootTime: 1000),
        // darwinParameters: const DarwinParameters(),
      );
      debugPrint('$tag DFU result: $s');
      setState(() {
        dfuStateMap[deviceId]?.dfuRunning = false;
      });
    } catch (e) {
      final errorMsg = e.toString();
      setState(() {
        dfuStateMap[deviceId]?.dfuRunning = false;
        dfuStateMap[deviceId]?.lastError = errorMsg;
        dfuStateMap[deviceId]?.addEvent('Exception', 'DFU failed: $errorMsg', isError: true);
      });
      debugPrint('$tag DFU Exception: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('DFU failed: $errorMsg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> startScan() async {
    // You can request multiple permissions at once.

    if (!Platform.isMacOS) {
      await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.bluetooth,
      ].request();
    }

    await scanSubscription?.cancel();
    await FlutterBluePlus.startScan();
    scanResults.clear();
    scanSubscription = FlutterBluePlus.scanResults.expand((e) => e).listen(
      (scanResult) {
        final exists = scanResults.firstWhereOrNull(
          (ele) => ele.device.remoteId == scanResult.device.remoteId,
        );

        if (exists != null) {
          return;
        }

        setState(() {
          scanResults
            ..add(scanResult)
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      },
    );
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    scanSubscription?.cancel();
    scanSubscription = null;
    setState(() => scanSubscription = null);
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = scanSubscription != null;
    final hasDevice = scanResults.isNotEmpty;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Nordic DFU Example App'),
          actions: <Widget>[
            if (anyDfuRunning)
              TextButton(
                onPressed: NordicDfu().abortDfu,
                child: const Text('Abort Dfu'),
              ),
            if (isScanning)
              IconButton(
                icon: const Icon(Icons.pause_circle_filled),
                onPressed: anyDfuRunning ? null : stopScan,
              )
            else
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: anyDfuRunning ? null : startScan,
              ),
          ],
        ),
        body: !hasDevice
            ? const Center(
                child: Text('No device'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemBuilder: _deviceItemBuilder,
                separatorBuilder: (context, index) => const SizedBox(height: 5),
                itemCount: scanResults.length,
              ),
      ),
    );
  }

  void _showEventTimeline(BuildContext context, String deviceId) {
    final state = dfuStateMap[deviceId];
    if (state == null) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Auto-refresh dialog every 100ms to show new events in real-time
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              setDialogState(() {});
            }
          });

          final currentState = dfuStateMap[deviceId];
          if (currentState == null) {
            return const SizedBox.shrink();
          }

          final isDfuRunning = currentState.dfuRunning;
          final events = currentState.events;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DFU Event Timeline',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isDfuRunning && currentState.progressPercent != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Progress: ${currentState.progressPercent}%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  if (events.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('No events yet...'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final timeStr = '${event.timestamp.hour.toString().padLeft(2, '0')}:'
                              '${event.timestamp.minute.toString().padLeft(2, '0')}:'
                              '${event.timestamp.second.toString().padLeft(2, '0')}';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: event.isError ? Colors.red.shade50 : Colors.green.shade50,
                            child: ListTile(
                              leading: Icon(
                                event.isError ? Icons.error : Icons.check_circle,
                                color: event.isError ? Colors.red : Colors.green,
                              ),
                              title: Text(
                                event.eventName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(event.message),
                              trailing: Text(
                                timeStr,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (isDfuRunning)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                NordicDfu().abortDfu(address: deviceId);
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.cancel),
                              label: const Text('Abort DFU'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _deviceItemBuilder(BuildContext context, int index) {
    final result = scanResults[index];
    final deviceId = result.device.remoteId.str;
    return DeviceItem(
      dfuState: dfuStateMap[deviceId],
      scanResult: result,
      onPress: dfuStateMap[deviceId]?.dfuRunning ?? false
          ? () => NordicDfu().abortDfu(address: deviceId)
          : () => doDfu(context, deviceId),
      onRetry: dfuStateMap[deviceId]?.lastError != null && !(dfuStateMap[deviceId]?.dfuRunning ?? false)
          ? () => retryDfu(context, deviceId)
          : null,
      onShowTimeline: dfuStateMap[deviceId]?.events.isNotEmpty ?? false
          ? () => _showEventTimeline(context, deviceId)
          : null,
    );
  }
}

class DeviceItem extends StatelessWidget {
  const DeviceItem({
    required this.scanResult,
    this.onPress,
    this.onRetry,
    this.onShowTimeline,
    this.dfuState,
    super.key,
  });
  final ScanResult scanResult;

  final VoidCallback? onPress;
  final VoidCallback? onRetry;
  final VoidCallback? onShowTimeline;

  final ExampleDfuState? dfuState;

  String _getDfuButtonText() {
    if (dfuState?.dfuRunning ?? false) {
      final progressText = dfuState?.progressPercent != null
          ? '\n(${dfuState!.progressPercent}%)'
          : '';
      return 'Abort DFU$progressText';
    }
    return 'Select ZIP\n& Start DFU';
  }

  @override
  Widget build(BuildContext context) {
    var name = 'Unknown';
    if (scanResult.device.platformName.isNotEmpty) {
      name = scanResult.device.platformName;
    }

    final hasError = dfuState?.lastError != null;
    final hasEvents = dfuState?.events.isNotEmpty ?? false;

    return Card(
      color: hasError ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: <Widget>[
                const Icon(Icons.bluetooth),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(scanResult.device.remoteId.str, style: const TextStyle(fontSize: 12)),
                      Text('RSSI: ${scanResult.rssi}', style: const TextStyle(fontSize: 12)),
                      if (dfuState?.progressPercent != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(
                            value: (dfuState!.progressPercent!) / 100,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: onPress,
                      child: Text(
                        _getDfuButtonText(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (onRetry != null)
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (hasEvents)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dfuState!.events.last.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: dfuState!.events.last.isError ? Colors.red : Colors.green,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onShowTimeline,
                      icon: const Icon(Icons.timeline, size: 16),
                      label: Text('Timeline (${dfuState!.events.length})'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

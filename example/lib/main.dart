import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nordic_dfu/nordic_dfu.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class ExampleDfuState {
  bool dfuRunning = false;
  int? progressPercent;

  ExampleDfuState({
    required this.dfuRunning,
    this.progressPercent,
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<ScanResult>? scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  Map<String, ExampleDfuState> dfuStateMap = {};
  bool get anyDfuRunning => dfuStateMap.values.any((state)=>state.dfuRunning);

  Future<void> doDfu(String deviceId) async {
    stopScan();
    setState((){
      dfuStateMap[deviceId] = ExampleDfuState(dfuRunning: true);
    });

    final result = await FilePicker.platform.pickFiles();

    if (result == null) return;
    try {
      final s = await NordicDfu().startDfu(
        deviceId,
        result.files.single.path ?? '',
        onDeviceDisconnecting: (string) {
          debugPrint('deviceAddress: $string');
        },
        // onErrorHandle: (string) {
        //   debugPrint('deviceAddress: $string');
        // },
        onProgressChanged: (
          deviceAddress,
          percent,
          speed,
          avgSpeed,
          currentPart,
          partsTotal,
        ) {
          debugPrint('deviceAddress: $deviceAddress, percent: $percent');
          setState((){
            dfuStateMap[deviceId]?.progressPercent = percent;
          });
        },
        // androidSpecialParameter: const AndroidSpecialParameter(rebootTime: 1000),
      );
      debugPrint(s);
      setState((){
        dfuStateMap[deviceId]?.dfuRunning = false;
      });
    } catch (e) {
      setState((){
        dfuStateMap[deviceId]?.dfuRunning = false;
      });
      debugPrint(e.toString());
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

    scanSubscription?.cancel();
    FlutterBluePlus.startScan();
    scanResults.clear();
    scanSubscription = FlutterBluePlus.scanResults.expand((e) => e).listen(
      (scanResult) {
        if (scanResults.firstWhereOrNull(
              (ele) => ele.device.remoteId == scanResult.device.remoteId,
            ) !=
            null) {
          return;
        }
        setState(() {
          /// add result to results if not added
          scanResults.add(scanResult);
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
          title: const Text('Plugin example app'),
          actions: <Widget>[
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

  Widget _deviceItemBuilder(BuildContext context, int index) {
    final result = scanResults[index];
    final deviceId = result.device.remoteId.str;
    return DeviceItem(
      dfuState: dfuStateMap[deviceId],
      scanResult: result,
      onPress: dfuStateMap[deviceId]?.dfuRunning ?? false
        ? () => NordicDfu().abortDfu(address: deviceId)
        : () => doDfu(deviceId)
    );
  }
}

// class ProgressListenerListener extends DfuProgressListenerAdapter {
//   @override
//   void onProgressChanged(
//     String? deviceAddress,
//     int? percent,
//     double? speed,
//     double? avgSpeed,
//     int? currentPart,
//     int? partsTotal,
//   ) {
//     super.onProgressChanged(
//       deviceAddress,
//       percent,
//       speed,
//       avgSpeed,
//       currentPart,
//       partsTotal,
//     );
//     debugPrint('deviceAddress: $deviceAddress, percent: $percent');
//   }
// }

class DeviceItem extends StatelessWidget {
  final ScanResult scanResult;

  final VoidCallback? onPress;

  final ExampleDfuState? dfuState;

  const DeviceItem({
    required this.scanResult,
    this.onPress,
    this.dfuState,
    Key? key,
  }) : super(key: key);

  String _getDfuButtonText() {
    final progressText = dfuState?.progressPercent != null
      ? '\n(${dfuState!.progressPercent}%)'
      : '';
    return (dfuState?.dfuRunning == true ? 'Abort Dfu' : 'Start Dfu') + progressText;
  }

  @override
  Widget build(BuildContext context) {
    var name = 'Unknown';
    if (scanResult.device.platformName.isNotEmpty) {
      name = scanResult.device.platformName;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: <Widget>[
            const Icon(Icons.bluetooth),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name),
                  Text(scanResult.device.remoteId.str),
                  Text('RSSI: ${scanResult.rssi}'),
                ],
              ),
            ),
            TextButton(
              onPressed: onPress,
              child: Text(
                _getDfuButtonText(),
                textAlign: TextAlign.center,
              )
            ),
          ],
        ),
      ),
    );
  }
}

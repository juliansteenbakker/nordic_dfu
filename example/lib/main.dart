import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nordic_dfu/nordic_dfu.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<ScanResult>? scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  bool dfuRunning = false;
  int? dfuRunningInx;

  Future<void> doDfu(String deviceId) async {
    stopScan();
    dfuRunning = true;
    try {
      final s = await NordicDfu().startDfu(
        deviceId,
        'assets/file.zip',
        fileInAsset: true,
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
        },
        // androidSpecialParameter: const AndroidSpecialParameter(rebootTime: 1000),
      );
      debugPrint(s);
      dfuRunning = false;
    } catch (e) {
      dfuRunning = false;
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
    setState(() {
      scanResults.clear();
      scanSubscription = FlutterBluePlus.scan(allowDuplicates: true).listen(
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
    });
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
                onPressed: dfuRunning ? null : stopScan,
              )
            else
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: dfuRunning ? null : startScan,
              )
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
    return DeviceItem(
      isRunningItem: dfuRunningInx == index,
      scanResult: result,
      onPress: dfuRunning
          ? () async {
              await NordicDfu().abortDfu();
              setState(() {
                dfuRunningInx = null;
              });
            }
          : () async {
              setState(() {
                dfuRunningInx = index;
              });
              await doDfu(result.device.remoteId.str);
              setState(() {
                dfuRunningInx = null;
              });
            },
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

  final bool? isRunningItem;

  const DeviceItem({
    required this.scanResult,
    this.onPress,
    this.isRunningItem,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var name = 'Unknown';
    if (scanResult.device.localName.isNotEmpty) {
      name = scanResult.device.localName;
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
              child: isRunningItem!
                  ? const Text('Abort Dfu')
                  : const Text('Start Dfu'),
            )
          ],
        ),
      ),
    );
  }
}

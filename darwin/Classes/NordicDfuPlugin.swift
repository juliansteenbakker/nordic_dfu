import NordicDFU
import CoreBluetooth

#if os(iOS)
  import Flutter
  import UIKit
#else
  import AppKit
  import FlutterMacOS
#endif

public class NordicDfuPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, LoggerDelegate {
    
    let registrar: FlutterPluginRegistrar
    private var sink: FlutterEventSink?
    private var activeDfuMap: [String: DfuProcess] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NordicDfuPlugin(registrar)
        
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        
        let method = FlutterMethodChannel(name: "dev.steenbakker.nordic_dfu/method", binaryMessenger: messenger)
        
        let event = FlutterEventChannel(name:
                                            "dev.steenbakker.nordic_dfu/event", binaryMessenger: messenger)

        registrar.addMethodCallDelegate(instance, channel: method)
        event.setStreamHandler(instance)
    }
    
    init(_ registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startDfu": initializeDfu(call, result)
        case "abortDfu" : abortDfu(call, result)
        default: result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    // Aborts ongoing DFU process(es)
    // If `call.arguments["address"]` is nil, aborts all active DFU processes.
    // If `call.arguments["address"]` contains an address, aborts the DFU process for that address.
    private func abortDfu(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let address = arguments["address"] as? String else {
            // Abort all DFU processes
            if activeDfuMap.isEmpty {
                result(FlutterError(code: "NO_ACTIVE_DFU", message: "No active DFU processes to abort", details: nil))
            } else {
                activeDfuMap.values.forEach { _ = $0.controller?.abort() } // Explicitly ignore result of `abort()`
                result(nil)
            }
            return
        }

        // Abort DFU process for the specified address
        guard let process = activeDfuMap[address] else {
            result(FlutterError(code: "INVALID_ADDRESS", message: "No DFU process found for address: \(address).", details: nil))
            return
        }

        _ = process.controller?.abort() // Explicitly ignore result of `abort()`
        result(nil)
    }
 
    private func initializeDfu(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? Dictionary<String, AnyObject> else {
            result(FlutterError(code: "ABNORMAL_PARAMETER", message: "no parameters", details: nil))
            return
        }
        guard let address = arguments["address"] as? String,
              var filePath = arguments["filePath"] as? String else {
            result(FlutterError(code: "ABNORMAL_PARAMETER", message: "address and filePath are required", details: nil))
            return
        }

        let options = DfuOptions(arguments: arguments)

        let fileInAsset = (arguments["fileInAsset"] as? Bool) ?? false
        
        if (fileInAsset) {
            let key = registrar.lookupKey(forAsset: filePath)
            guard let pathInAsset = Bundle.main.path(forResource: key, ofType: nil) else {
                result(FlutterError(code: "ABNORMAL_PARAMETER", message: "file in asset not found \(filePath)", details: nil))
                return
            }

            filePath = pathInAsset
        }
        
        startDfu(address,
                 filePath: filePath,
                 options: options,
                 result: result)
    }
    
    private func startDfu(
        _ address: String,
        filePath: String,
        options: DfuOptions,
        result: @escaping FlutterResult) {
        guard let uuid = UUID(uuidString: address) else {
            result(FlutterError(code: "DEVICE_ADDRESS_ERROR", message: "Device address conver to uuid failed", details: "Device uuid \(address) convert to uuid failed"))
            return
        }
        
        do {
            let firmware = try DFUFirmware(urlToZipFile: URL(fileURLWithPath: filePath))
            
            activeDfuMap[address] = DfuProcess(
                deviceAddress: address,
                firmware: firmware,
                uuid: uuid,
                delegate: self,
                result: result,
                options: options)
        } catch {
            result(FlutterError(code: "DFU_FIRMWARE_NOT_FOUND", message: "Could not dfu zip file", details: nil))
            return
        }
    }

    func dfuStateDidChange(to state: DFUState, deviceAddress: String) {
        switch state {
        case .completed:
            sink?(["onDfuCompleted":deviceAddress])
            activeDfuMap[deviceAddress]?.pendingResult(deviceAddress)
            activeDfuMap.removeValue(forKey: deviceAddress)
        case .disconnecting:
            sink?(["onDeviceDisconnecting":deviceAddress])
        case .aborted:
            sink?(["onDfuAborted":deviceAddress])
            activeDfuMap[deviceAddress]?.pendingResult(FlutterError(code: "DFU_ABORTED", message: "DFU aborted by user", details: "device address: \(deviceAddress)"))
            activeDfuMap.removeValue(forKey: deviceAddress)
        case .connecting:
            sink?(["onDeviceConnecting":deviceAddress])
        case .starting:
            sink?(["onDfuProcessStarting":deviceAddress])
        case .enablingDfuMode:
            sink?(["onEnablingDfuMode":deviceAddress])
        case .validating:
            sink?(["onFirmwareValidating":deviceAddress])
        case .uploading:
            sink?(["onDfuProcessStarted":deviceAddress])
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String, deviceAddress: String) {
        sink?(["onError": [
            "deviceAddress": deviceAddress,
            "error": error.rawValue,
            "errorType": error.rawValue,
            "message": message
        ]])
        
        activeDfuMap[deviceAddress]?.pendingResult(FlutterError(code: "\(error.rawValue)", message: "DFU FAILED: \(message)", details: "Address: \(deviceAddress), Error type \(error.rawValue)"))
        activeDfuMap.removeValue(forKey: deviceAddress)
    }

    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double, deviceAddress: String) {
        sink?(["onProgressChanged":["deviceAddress": deviceAddress, "percent": progress, "speed":currentSpeedBytesPerSecond, "avgSpeed": avgSpeedBytesPerSecond, "currentPart": part, "partsTotal": totalParts]])
    }

    //MARK: - LoggerDelegate
    public func logWith(_ level: LogLevel, message: String) {
        print("\(level.name()): \(message)")
    }
}

private struct DfuOptions {
    let name: String?
    let packetReceiptNotificationParameter: UInt16?
    let forceDfu: Bool?
    let forceScanningForNewAddressInLegacyDfu: Bool?
    let connectionTimeout: TimeInterval?
    let dataObjectPreparationDelay: TimeInterval?
    let alternativeAdvertisingNameEnabled: Bool?
    let alternativeAdvertisingName: String?
    let enableUnsafeExperimentalButtonlessServiceInSecureDfu: Bool?
    let disableResume: Bool?

    init(arguments: [String: Any]) {
        self.name = arguments["name"] as? String
        self.packetReceiptNotificationParameter = arguments["packetReceiptNotificationParameter"] as? UInt16
        self.forceDfu = arguments["forceDfu"] as? Bool
        self.forceScanningForNewAddressInLegacyDfu = arguments["forceScanningForNewAddressInLegacyDfu"] as? Bool
        self.connectionTimeout = arguments["connectionTimeout"] as? TimeInterval
        self.dataObjectPreparationDelay = arguments["dataObjectPreparationDelay"] as? TimeInterval
        self.alternativeAdvertisingNameEnabled = arguments["alternativeAdvertisingNameEnabled"] as? Bool
        self.alternativeAdvertisingName = arguments["alternativeAdvertisingName"] as? String
        self.enableUnsafeExperimentalButtonlessServiceInSecureDfu = arguments["enableUnsafeExperimentalButtonlessServiceInSecureDfu"] as? Bool
        self.disableResume = arguments["disableResume"] as? Bool
    }
}

private func configureDfuInitiator(
    _ dfuInitiator: DFUServiceInitiator,
    with options: DfuOptions
) {
    options.packetReceiptNotificationParameter.map { dfuInitiator.packetReceiptNotificationParameter = $0 }
    options.forceDfu.map { dfuInitiator.forceDfu = $0 }
    options.forceScanningForNewAddressInLegacyDfu.map { dfuInitiator.forceScanningForNewAddressInLegacyDfu = $0 }
    options.connectionTimeout.map { dfuInitiator.connectionTimeout = $0 }
    options.dataObjectPreparationDelay.map { dfuInitiator.dataObjectPreparationDelay = $0 }
    options.alternativeAdvertisingNameEnabled.map { dfuInitiator.alternativeAdvertisingNameEnabled = $0 }
    options.alternativeAdvertisingName.map { dfuInitiator.alternativeAdvertisingName = $0 }
    options.enableUnsafeExperimentalButtonlessServiceInSecureDfu.map { dfuInitiator.enableUnsafeExperimentalButtonlessServiceInSecureDfu = $0 }
    options.disableResume.map { dfuInitiator.disableResume = $0 }
}

private class DfuProcess {
    let controller: DFUServiceController?
    let pendingResult: FlutterResult
    let deviceDelegate: DeviceScopedDFUDelegate

    init(
        deviceAddress: String,
        firmware: DFUFirmware,
        uuid: UUID,
        delegate: NordicDfuPlugin,
        result: @escaping FlutterResult,
        options: DfuOptions
    ) {
        self.pendingResult = result
        self.deviceDelegate = DeviceScopedDFUDelegate(
            delegate: delegate,
            deviceAddress: deviceAddress
        )

        let dfuInitiator = DFUServiceInitiator(queue: nil)
            .with(firmware: firmware)

        dfuInitiator.delegate = self.deviceDelegate
        dfuInitiator.progressDelegate = self.deviceDelegate
        dfuInitiator.logger = delegate

        configureDfuInitiator(dfuInitiator, with: options)
        
        self.controller = dfuInitiator.start(targetWithIdentifier: uuid)
    }
}

// Handles DFU service and progress updates for a specific device
public class DeviceScopedDFUDelegate: NSObject, DFUServiceDelegate, DFUProgressDelegate {
    private let originalDelegate: NordicDfuPlugin
    private let deviceAddress: String

    init(delegate: NordicDfuPlugin, deviceAddress: String) {
        self.originalDelegate = delegate
        self.deviceAddress = deviceAddress
    }

    //MARK: DFUServiceDelegate
    public func dfuStateDidChange(to state: DFUState) {
        originalDelegate.dfuStateDidChange(to: state, deviceAddress: deviceAddress)
    }
    public func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        originalDelegate.dfuError(error, didOccurWithMessage: message, deviceAddress: deviceAddress)
    }

    //MARK: DFUProgressDelegate
    public func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        originalDelegate.dfuProgressDidChange(
            for: part,
            outOf: totalParts,
            to: progress,
            currentSpeedBytesPerSecond: currentSpeedBytesPerSecond,
            avgSpeedBytesPerSecond: avgSpeedBytesPerSecond,
            deviceAddress: deviceAddress
        )
    }
}

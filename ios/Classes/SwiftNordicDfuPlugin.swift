import Flutter
import UIKit
import iOSDFULibrary
import CoreBluetooth

public class SwiftNordicDfuPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, DFUServiceDelegate, DFUProgressDelegate, LoggerDelegate {
    
    let registrar: FlutterPluginRegistrar
    var sink: FlutterEventSink!
    var pendingResult: FlutterResult?
    var deviceAddress: String?
    private var dfuController : DFUServiceController!
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftNordicDfuPlugin(registrar)
        
        let method = FlutterMethodChannel(name: "dev.steenbakker.nordic_dfu/method", binaryMessenger: registrar.messenger())
        
        let event = FlutterEventChannel(name:
                                            "dev.steenbakker.nordic_dfu/event", binaryMessenger: registrar.messenger())

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
        case "abortDfu" : abortDfu()
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
    
    private func abortDfu() {
        _ = dfuController?.abort()
        dfuController = nil
    }
 
    private func initializeDfu(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? Dictionary<String, AnyObject> else {
            result(FlutterError(code: "ABNORMAL_PARAMETER", message: "no parameters", details: nil))
            return
        }
        let name = arguments["name"] as? String
        guard let address = arguments["address"] as? String,
            var filePath = arguments["filePath"] as? String else {
                result(FlutterError(code: "ABNORMAL_PARAMETER", message: "address and filePath are required", details: nil))
                return
        }
        
        let forceDfu = arguments["forceDfu"] as? Bool
        let forceScanningForNewAddressInLegacyDfu = arguments["forceScanningForNewAddressInLegacyDfu"] as? Bool
        let packetReceiptNotificationParameter = arguments["packetReceiptNotificationParameter"] as? UInt16
        let connectionTimeout = arguments["connectionTimeout"] as? TimeInterval
        let dataObjectPreparationDelay = arguments["dataObjectPreparationDelay"] as? TimeInterval
        let alternativeAdvertisingNameEnabled = arguments["alternativeAdvertisingNameEnabled"] as? Bool
        let alternativeAdvertisingName = arguments["alternativeAdvertisingName"] as? String
        let enableUnsafeExperimentalButtonlessServiceInSecureDfu = arguments["enableUnsafeExperimentalButtonlessServiceInSecureDfu"] as? Bool
        let disableResume = arguments["disableResume"] as? Bool

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
                 name: name,
                 filePath: filePath,
                 packetReceiptNotificationParameter: packetReceiptNotificationParameter,
                 forceDfu: forceDfu,
                 forceScanningForNewAddressInLegacyDfu: forceScanningForNewAddressInLegacyDfu,
                 connectionTimeout: connectionTimeout,
                 dataObjectPreparationDelay: dataObjectPreparationDelay,
                 alternativeAdvertisingNameEnabled: alternativeAdvertisingNameEnabled,
                 alternativeAdvertisingName: alternativeAdvertisingName,
                 enableUnsafeExperimentalButtonlessServiceInSecureDfu: enableUnsafeExperimentalButtonlessServiceInSecureDfu,
                 disableResume: disableResume,
                 result: result)
    }
    
    private func startDfu(
        _ address: String,
        name: String?,
        filePath: String,
        packetReceiptNotificationParameter: UInt16?,
        forceDfu: Bool?,
        forceScanningForNewAddressInLegacyDfu: Bool?,
        connectionTimeout: TimeInterval?,
        dataObjectPreparationDelay: TimeInterval?,
        alternativeAdvertisingNameEnabled: Bool?,
        alternativeAdvertisingName: String?,
        enableUnsafeExperimentalButtonlessServiceInSecureDfu: Bool?,
        disableResume: Bool?,
        result: @escaping FlutterResult) {
        guard let uuid = UUID(uuidString: address) else {
            result(FlutterError(code: "DEVICE_ADDRESS_ERROR", message: "Device address conver to uuid failed", details: "Device uuid \(address) convert to uuid failed"))
            return
        }
        
        do {
            let firmware = try DFUFirmware(urlToZipFile: URL(fileURLWithPath: filePath))
            
            let dfuInitiator = DFUServiceInitiator(queue: nil)
                .with(firmware: firmware);
            dfuInitiator.delegate = self
            dfuInitiator.progressDelegate = self
            dfuInitiator.logger = self
            
            packetReceiptNotificationParameter.map { dfuInitiator.packetReceiptNotificationParameter = $0 }
            forceDfu.map { dfuInitiator.forceDfu = $0 }
            forceScanningForNewAddressInLegacyDfu.map { dfuInitiator.forceScanningForNewAddressInLegacyDfu = $0 }
            connectionTimeout.map { dfuInitiator.connectionTimeout = $0 }
            dataObjectPreparationDelay.map { dfuInitiator.dataObjectPreparationDelay = $0 }
            alternativeAdvertisingNameEnabled.map { dfuInitiator.alternativeAdvertisingNameEnabled = $0 }
            alternativeAdvertisingName.map { dfuInitiator.alternativeAdvertisingName = $0 }
            enableUnsafeExperimentalButtonlessServiceInSecureDfu.map { dfuInitiator.enableUnsafeExperimentalButtonlessServiceInSecureDfu = $0 }
//            uuidHelper.map { dfuInitiator.uuidHelper = $0 }
            disableResume.map { dfuInitiator.disableResume = $0 }
            
            pendingResult = result
            deviceAddress = address
            
            dfuController = dfuInitiator.start(targetWithIdentifier: uuid)
        }
        catch{
        result(FlutterError(code: "DFU_FIRMWARE_NOT_FOUND", message: "Could not dfu zip file", details: nil))
            return
        }
    }
    
//    MARK: DFUServiceDelegate
    public func dfuStateDidChange(to state: DFUState) {
        switch state {
        case .completed:
            sink?(["onDfuCompleted":deviceAddress])
            pendingResult?(deviceAddress)
            pendingResult = nil
            dfuController = nil
        case .disconnecting:
            sink?(["onDeviceDisconnecting":deviceAddress])
        case .aborted:
            sink?(["onDfuAborted": deviceAddress])
            pendingResult?(FlutterError(code: "DFU_ABORTED", message: "DFU ABORTED by user", details: "device address: \(deviceAddress!)"))
            pendingResult = nil
        case .connecting:
            sink?(["onDeviceConnecting":deviceAddress])
        case .starting:
            sink?(["onDfuProcessStarting":deviceAddress])
        case .enablingDfuMode:
            sink?(["onEnablingDfuMode":deviceAddress])
        case .validating:
            sink?(["onFirmwareValidating":deviceAddress])
        case .uploading:
            sink?(["onFirmwareUploading":deviceAddress])
        }
    }
    
    public func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        sink?(["onError":["deviceAddress": deviceAddress!, "error": error.rawValue, "errorType":error.rawValue, "message": message]])
        pendingResult?(FlutterError(code: "\(error.rawValue)", message: "DFU FAILED: \(message)", details: "Address: \(deviceAddress!), Error type \(error.rawValue)"))
        pendingResult = nil
    }
    
    //MARK: DFUProgressDelegate
    public func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        sink?(["onProgressChanged":["deviceAddress": deviceAddress!, "percent": progress, "speed":currentSpeedBytesPerSecond, "avgSpeed": avgSpeedBytesPerSecond, "currentPart": part, "partsTotal": totalParts]])
    }
    
    //MARK: - LoggerDelegate
    public func logWith(_ level: LogLevel, message: String) {
        print("\(level.name()): \(message)")
    }
}

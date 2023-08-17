/// iOS parameters for DFUServiceInitiator object.
/// See https://github.com/NordicSemiconductor/IOS-Pods-DFU-Library for more information.
class IosSpecialParameter {
  /// By default, the Legacy DFU bootloader starting from SDK 7.1, when enabled using
  /// buttonless service, advertises with the same Bluetooth address as the application
  /// using direct advertisement. This complies with the Bluetooth specification.
  /// However, starting from iOS 13.x, iPhones and iPads use random addresses on each
  /// connection and do not expect direct advertising unless bonded. This causes thiose
  /// packets being missed and not reported to the library, making reconnection to the
  /// bootloader and proceeding with DFU impossible.
  /// A solution requires modifying either the bootloader not to use the direct advertising,
  /// or the application not to share the peer data with bootloader, in which case it will
  /// advertise undirectly using address +1, like it does when the switch to bootloader mode
  /// is initiated with a button. After such modification, setting this flag to true will make the
  /// library scan for the bootloader using `DFUPeripheralSelector`.
  ///
  /// Setting this flag to true without modifying the booloader behavior will break the DFU,
  /// as the direct advertising packets are empty and will not pass the default
  /// `DFUPeripheralSelector`.

  final bool? forceScanningForNewAddressInLegacyDfu;

  /// Connection timeout.
  ///
  /// When the DFU target does not connect before the time runs out, a timeout error
  /// is reported.
  final double? connectionTimeout;

  /// Duration of a delay, that the service will wait before sending each data object in
  /// Secure DFU. The delay will be done after a data object is created, and before
  /// any data byte is sent. The default value is 0, which disables this feature for the
  /// second and following data objects, but the first one will be delayed by 0.4 sec.
  ///
  /// It has been found, that a delay of at least 0.3 sec reduces the risk of packet lose
  /// (the bootloader needs some time to prepare flash memory) on DFU bootloader from
  /// SDK 15, 16 and 17. The delay does not have to be longer than 0.4 sec, as according to
  /// performed tests, such delay is sufficient.
  ///
  /// The longer the delay, the more time DFU will take to complete (delay will be repeated for
  /// each data object (4096 bytes)). However, with too small delay a packet lose may occur,
  /// causing the service to enable PRN and set them to 1 making DFU process very, very slow
  /// (but reliable).
  ///
  /// The recommended delay is from 0.3 to 0.4 second if your DFU bootloader is from
  /// SDK 15, 16 or 17. Older bootloaders do not need this delay.
  ///
  /// This variable is ignored in Legacy DFU.
  final double? dataObjectPreparationDelay;

  /// In SDK 14.0.0 a new feature was added to the Buttonless DFU for non-bonded
  /// devices which allows to send a unique name to the device before it is switched
  /// to bootloader mode. After jump, the bootloader will advertise with this name
  /// as the Complete Local Name making it easy to select proper device. In this case
  /// you don't have to override the default peripheral selector.
  ///
  /// Read more:
  /// http://infocenter.nordicsemi.com/topic/com.nordic.infocenter.sdk5.v14.0.0/service_dfu.html
  ///
  /// Setting this flag to false you will disable this feature. iOS DFU Library will
  /// not send the 0x02-[len]-[new name] command prior jumping and will rely on the DfuPeripheralSelectorDelegate just like it used to in previous SDK.
  ///
  /// This flag is ignored in Legacy DFU.
  ///
  /// **It is recommended to keep this flag set to true unless necessary.**
  ///
  /// For more information read:
  /// https://github.com/NordicSemiconductor/IOS-nRF-Connect/issues/16
  final bool? alternativeAdvertisingNameEnabled;

  /// If `alternativeAdvertisingNameEnabled` is `true` then this specifies the
  /// alternative name to use. If nil (default) then a random name is generated.
  ///
  /// The maximum length of the alertnative advertising name is 20 bytes.
  /// Longer name will be trundated. UTF-8 characters can be cut in the middle.
  final String? alternativeAdvertisingName;

  /// Disable the ability for the DFU process to resume from where it was.
  final bool? disableResume;

  /// The number of packets of firmware data to be received by the DFU target before
  /// sending a new Packet Receipt Notification. If this value is 0, the packet receipt
  /// notification will be disabled by the DFU target. Default value is 12.
  final int? packetReceiptNotificationParameter;

  const IosSpecialParameter({
    this.alternativeAdvertisingNameEnabled,
    this.forceScanningForNewAddressInLegacyDfu,
    this.connectionTimeout,
    this.dataObjectPreparationDelay,
    this.alternativeAdvertisingName,
    this.disableResume,
    this.packetReceiptNotificationParameter,
  });

  Map<String, dynamic> toJson() => {
        'alternativeAdvertisingNameEnabled': alternativeAdvertisingNameEnabled,
        'forceScanningForNewAddressInLegacyDfu':
            forceScanningForNewAddressInLegacyDfu,
        'connectionTimeout': connectionTimeout,
        'dataObjectPreparationDelay': dataObjectPreparationDelay,
        'alternativeAdvertisingName': alternativeAdvertisingName,
        'disableResume': disableResume,
        'packetReceiptNotificationParameter':
            packetReceiptNotificationParameter,
      };
}

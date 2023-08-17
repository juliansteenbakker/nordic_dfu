/// Android parameters for DFUServiceInitiator object.
/// See https://github.com/NordicSemiconductor/Android-DFU-Library for more information.
class AndroidSpecialParameter {
  ///Sets whether the progress notification in the status bar should be disabled.
  ///Defaults to false.
  final bool? disableNotification;

  ///
  /// Sets whether the DFU service should be started as a foreground service. By default it's
  /// <i>true</i>. According to
  /// <a href="https://developer.android.com/about/versions/oreo/background.html">
  /// https://developer.android.com/about/versions/oreo/background.html</a>
  /// the background service may be killed by the system on Android Oreo after user quits the
  /// application so it is recommended to keep it as a foreground service (default) at least on
  /// Android Oreo+.
  ///
  final bool? startAsForegroundService;

  /// Sets whether the bond information should be preserver after flashing new application.
  /// This feature requires DFU Bootloader version 0.6 or newer (SDK 8.0.0+).
  /// Please see the {@link DfuBaseService#EXTRA_KEEP_BOND} for more information regarding
  /// requirements. Remember that currently updating the Soft Device will remove the bond
  /// information.
  ///
  /// This flag is ignored when Secure DFU Buttonless Service is used. It will keep or remove the
  /// bond depending on the Buttonless service type.
  ///
  final bool? keepBond;

  /// Sets whether the bond should be created after the DFU is complete.
  /// Please see the {@link DfuBaseService#EXTRA_RESTORE_BOND} for more information regarding
  /// requirements.
  ///
  /// This flag is ignored when Secure DFU Buttonless Service is used. It will keep or will not
  /// restore the bond depending on the Buttonless service type.
  final bool? restoreBond;

  /// Enables or disables the Packet Receipt Notification (PRN) procedure.
  ///
  /// By default the PRNs are disabled on devices with Android Marshmallow or newer and enabled on
  /// older ones.
  final bool? packetReceiptNotificationsEnabled;

  /// This method sets the duration of a delay, that the service will wait before
  /// sending each data object in Secure DFU. The delay will be done after a data object is created,
  /// and before any data byte is sent. The default value is 0, which disables this feature.
  ///
  /// It has been found, that a delay of at least 300ms reduces the risk of packet lose
  /// (the bootloader needs some time to prepare flash memory) on DFU bootloader from SDK 15 and 16.
  /// The delay does not have to be longer than 400 ms, as according to performed tests, such delay is sufficient.
  ///
  /// The longer the delay, the more time DFU will take to complete
  /// (delay will be repeated for each data object (4096 bytes)). However, with too small delay
  /// a packet lose may occur, causing the service to enable PRN and set them to 1 making DFU process very, very slow (but reliable).
  ///
  /// Default: 400
  final int dataDelay;

  /// Sets the number of retries that the DFU service will use to complete DFU. The default value is 0, for backwards compatibility reason.
  ///
  /// If the given value is greater than 0, the service will restart itself at most max times in case of an undesired
  /// disconnection during DFU operation. This attempt counter is independent from another counter, for reconnection attempts,
  /// which is equal to 3. The latter one will be used when connection will fail with an error (possible packet collision or any other reason).
  /// After successful connection, the reconnection counter is reset, while the retry counter is cleared after a DFU finishes with success.
  ///
  /// The service will not try to retry DFU in case of any other error, for instance an error sent from the target device.
  ///
  /// Default: 10
  final int numberOfRetries;

  /// Sets the time required by the device to reboot. The library will wait for this time before
  /// scanning for the device in bootloader mode.
  ///
  /// rebootTime the reboot time in milliseconds, default 0.
  final int? rebootTime;

  const AndroidSpecialParameter({
    this.disableNotification,
    this.keepBond,
    this.packetReceiptNotificationsEnabled,
    this.restoreBond,
    this.startAsForegroundService,
    this.dataDelay = 400,
    this.numberOfRetries = 10,
    this.rebootTime,
  });

  Map<String, dynamic> toJson() => {
        'disableNotification': disableNotification,
        'keepBond': keepBond,
        'packetReceiptNotificationsEnabled': packetReceiptNotificationsEnabled,
        'restoreBond': restoreBond,
        'startAsForegroundService': startAsForegroundService,
        'dataDelay': dataDelay,
        'numberOfRetries': numberOfRetries,
        'rebootTime': rebootTime,
      };
}

/// Some parameter just use in Android
/// All this parameters can see in <a href="https://github.com/NordicSemiconductor/Android-DFU-Library">
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

  const AndroidSpecialParameter({
    this.disableNotification,
    this.keepBond,
    this.packetReceiptNotificationsEnabled,
    this.restoreBond,
    this.startAsForegroundService,
  });
}

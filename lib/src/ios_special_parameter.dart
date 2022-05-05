/// Some parameter just use in iOS
/// All this parameters can see in <a href="https://github.com/NordicSemiconductor/IOS-Pods-DFU-Library">
class IosSpecialParameter {
  ///Sets whether to send unique name to device before it is switched into bootloader mode
  ///Defaults to true.
  final bool? alternativeAdvertisingNameEnabled;

  const IosSpecialParameter({
    this.alternativeAdvertisingNameEnabled,
  });
}

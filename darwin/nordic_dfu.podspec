#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'nordic_dfu'
  s.version          = '7.1.1'
  s.summary          = 'DFU plugin for flutter.'
  s.description      = <<-DESC
A DFU plugin project.
                       DESC
  s.homepage         = 'http://www.timeyaa.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Timeyaa' => 'fengqiangboy@timeyaa.com' }
  s.source           = { :path => '.' }
  s.source_files = 'nordic_dfu/Sources/nordic_dfu/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.15'
  s.swift_version    = '5.4'
  s.dependency 'NordicDFU', '~> 4.16.0'  
  s.resource_bundles = {'nordic_dfu' => ['nordic_dfu/Sources/nordic_dfu/Resources/PrivacyInfo.xcprivacy']}
end


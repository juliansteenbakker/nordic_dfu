#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hello.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'nordic_dfu'
  s.version          = '1.0.0'
  s.summary          = 'MACOS DFU plugin for flutter.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://www.timeyaa.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Timeyaa' => 'fengqiangboy@timeyaa.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.swift_version = '5.4'
  s.dependency 'FlutterMacOS'
  s.dependency 'iOSDFULibrary', '~> 4.13.0'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

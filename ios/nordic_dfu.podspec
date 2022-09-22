#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'nordic_dfu'
  s.version          = '1.0.0'
  s.summary          = 'iOS DFU plugin for flutter.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://www.timeyaa.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Timeyaa' => 'fengqiangboy@timeyaa.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.swift_version    = '5.4'
  s.dependency 'Flutter'
  s.dependency 'iOSDFULibrary', '~> 4.13.0'

  s.ios.deployment_target = '9.0'
end


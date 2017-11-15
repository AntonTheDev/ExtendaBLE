Pod::Spec.new do |s|
  s.name         = "ExtendaBLE"
  s.version      = "0.4"
  s.summary      = "Blocks Based Bluetooth LE Connectivity framework for iOS/watchOS/tvOS/OSX"
  s.homepage     = "https://github.com/AntonTheDev/ExtendaBLE"
  s.license      = 'MIT'
  s.author       = { "Anton Doudarev" => "antonthedev@gmail.com" }
  s.source       = { :git => 'https://github.com/AntonTheDev/ExtendaBLE.git', :tag => s.version }

  s.platform     = :ios, "9.0"
  s.platform     = :tvos, "9.0"
  s.platform     = :osx, "10.10"

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '3.0'

  s.source_files = "Source/*.*", "Source/EBMaker/*.*", "Source/EBManager/*.*", "Source/EBTransaction/*.*", "Source/Extensions/*.*", "Source/Logger/*.*"
end

Pod::Spec.new do |s|
  s.name         = "ExtendaBLE"
  s.version      = "0.1"
  s.summary      = "Bluetooth Low Energy On Crack"
  s.homepage     = "https://github.com/AntonTheDev/ExtendaBLE"
  s.license      = 'MIT'
  s.author       = { "Anton Doudarev" => "antonthedev@gmail.com" }
  s.source       = { :git => 'https://github.com/AntonTheDev/ExtendaBLE.git', :tag => s.version }
  

  s.platform     = :ios, "9.0"
  s.platform     = :tvos, "9.0"

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.source_files = "Source/*.*", "Source/Extensions/*.*", "Source/FAAnimation/*.*", "Source/FAInterpolation/*.*"
end



require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = "react-native-beep-player"
  s.version      = package['version']
  s.summary      = package['description']
  s.homepage     = package['homepage'] || "https://github.com/ausgandalf"
  s.license      = package['license'] || "MIT"
  s.author       = package['author'] || { "Jessee Beecham" => "jsbchm0320@gmail.com" }
  s.source       = { :git => "https://github.com/ausgandalf/react-native-beep-player.git", :tag => "#{s.version}" }

  s.platform     = :ios, "11.0"
  s.source_files = "ios/**/*.{h,m,swift}"
  s.requires_arc = true
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/ios/BeepPlayer-Bridging-Header.h' }

  s.dependency 'React-Core'
end

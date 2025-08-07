Pod::Spec.new do |s|
  s.name         = "react-native-beep-player"
  s.version      = "1.0.0"
  s.summary      = "Native module for precise beep looping in React Native"
  s.description  = <<-DESC
                    Plays beep sounds continuously with sample-accurate scheduling on iOS and Android.
                   DESC
  s.homepage     = "https://github.com/yourusername/react-native-beep-player"
  s.license      = { :type => "MIT" }
  s.author       = { "Jessee Beecham" => "jsbchm0320@gmail.com" }
  s.platform     = :ios, "10.0"
  s.source       = { :git => "https://github.com/ausgandalf/react-native-beep-player.git", :tag => s.version.to_s }
  s.source_files = "ios/**/*.{swift,h,m}"
  s.requires_arc = true
  s.swift_version = "5.0"
  
  s.dependency "React-Core"
end

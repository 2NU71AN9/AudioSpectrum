Pod::Spec.new do |s|

  s.name         = "AudioSpectrum"
  s.version      = "0.1.0"
  s.swift_version  = "5.0"
  s.summary      = "音频频谱"
  s.description  = "音频频谱音频频谱音频频谱"
  s.homepage     = "https://github.com/2NU71AN9/SLIKit" #项目主页，不是git地址
  s.license      = { :type => "MIT", :file => "LICENSE" } #开源协议
  s.author       = { "2UN7" => "1491859758@qq.com" }
  s.platform     = :ios, "13.0"
  s.source       = { :git => "https://github.com/2NU71AN9/SLIKit.git", :tag => "v#{s.version}" } #存储库的git地址，以及tag值
  s.source_files = "RecordDemo/Classes/**/*.{h,m,swift,xib,xcassets,mp3}"
  
  s.requires_arc = true #是否支持ARC
  
end

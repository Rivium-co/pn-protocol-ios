Pod::Spec.new do |s|
  s.name             = 'PNProtocol'
  s.version          = '0.2.1'
  s.summary          = 'Realtime messaging protocol for Rivium'
  s.description      = 'Realtime messaging protocol powered by pn-protocol'
  s.homepage         = 'https://rivium.co'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Rivium' => 'support@rivium.co' }
  s.source           = { :git => 'https://github.com/Rivium-co/pn-protocol-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'Sources/PNProtocol/**/*.swift'

  s.dependency 'CocoaMQTT', '~> 2.1'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

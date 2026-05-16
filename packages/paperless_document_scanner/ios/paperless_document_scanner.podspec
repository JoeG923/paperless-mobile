#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint paperless_document_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'paperless_document_scanner'
  s.version          = '0.0.1'
  s.summary          = 'Internal document scanner plugin for Paperless Mobile.'
  s.description      = <<-DESC
Internal document scanner plugin for Paperless Mobile.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{swift,c,m,h,mm,cpp,plist}'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.preserve_paths = 'opencv2.framework'
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework opencv2' }
  s.vendored_frameworks = 'opencv2.framework'
  s.frameworks = 'AVFoundation'
  s.library = 'c++'
end

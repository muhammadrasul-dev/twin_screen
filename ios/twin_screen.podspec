#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint twin_screen.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'twin_screen'
  s.version          = '0.4.2'
  s.summary          = 'Fold-aware and dual-screen layouts for Flutter: iPhone Duo, Android foldables and flip phones, web viewport segments, with window size classes, a fold-aware dialog and a debug fold simulator.'
  s.description      = <<-DESC
Fold-aware and dual-screen layouts for Flutter: iPhone Duo, Android foldables and flip phones, web viewport segments, with window size classes, a fold-aware dialog and a debug fold simulator.
                       DESC
  s.homepage         = 'https://github.com/muhammadrasul-dev/twin_screen'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Muhammadrasul' => 'https://github.com/muhammadrasul-dev' }
  s.source           = { :path => '.' }
  s.source_files = 'twin_screen/Sources/twin_screen/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # The plugin collects no data and uses no required-reason APIs.
  s.resource_bundles = {'twin_screen_privacy' => ['twin_screen/Sources/twin_screen/PrivacyInfo.xcprivacy']}
end

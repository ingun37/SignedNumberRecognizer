#
# Be sure to run `pod lib lint SignedNumberRecognizer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SignedNumberRecognizer'
  s.version          = '0.1.0'
  s.summary          = 'It recognizes handwritten signed number using tensorflow.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This library recognizes handwritten signed number using pre-built tensorflow model.
                       DESC

  s.homepage         = 'https://github.com/ingun37/SignedNumberRecognizer'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ingun37' => 'ingun37@gmail.com' }
  s.source           = { :git => 'https://github.com/ingun37/SignedNumberRecognizer.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  s.swift_versions   = '5.0'
  s.ios.deployment_target = '12.4'

  s.source_files = 'SignedNumberRecognizer/Classes/**/*'
  
  s.resource_bundles = {
    'SignedNumberRecognizer' => ['SignedNumberRecognizer/Assets/*']
  }

  s.static_framework = true
  s.dependency 'TensorFlowLiteSwift'
end

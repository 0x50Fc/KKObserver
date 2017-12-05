#
#  Be sure to run `pod spec lint KKObserver.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|


  s.name         = "KKObserver"
  s.version      = "1.0.1"
  s.summary      = "响应式数据对象"
  s.description  = "响应式数据对象, UI开发解耦小工具"

  s.homepage     = "https://github.com/hailongz/KKObserver"
  s.license      = "MIT"
  s.author       = { "zhang hailong" => "hailongz@qq.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/hailongz/KKObserver.git", :tag => "#{s.version}" }

  s.vendored_frameworks = 'KKObserver.framework'
  s.requires_arc = true

end

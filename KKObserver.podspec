
Pod::Spec.new do |s|


  s.name         = "KKObserver"
  s.version      = "1.0.2"
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

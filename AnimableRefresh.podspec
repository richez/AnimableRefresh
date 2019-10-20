Pod::Spec.new do |s|
  s.name         = "AnimableRefresh"
  s.version      = "0.1.0"
  s.summary      = "A customizable refresh view for `ScrollView`"
  s.description  = <<-DESC
  A much much longer description will come soon
                   DESC
  s.license      = "MIT"
  s.author       = { "Junda" => "junda@just2us.com" }
  s.source       = { :git => "https://github.com/richez/AnimableRefresh", :tag => "#{s.version}" }
  s.source_files  = "Source/*.swift"
  s.ios.framework  = 'UIKit'
  s.ios.deployment_target  = '11.0'
end

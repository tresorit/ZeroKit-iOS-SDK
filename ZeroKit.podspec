Pod::Spec.new do |s|
  s.name         = "ZeroKit"
  s.version      = "4.2.0"
  s.summary      = "ZeroKit is a simple, breach-proof user authentication and end-to-end encryption library."
  s.homepage     = "https://tresorit.com/zerokit/"
  s.license      = "BSD-3-Clause"
  s.author       = { "Tresorit" => "zerokit@tresorit.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/tresorit/ZeroKit-iOS-SDK.git", :tag => s.version, :submodules => true }
  s.source_files = "ZeroKit/**/*.{swift,h,m}", "ZeroKitNative/ZeroKitClientNative.h"
  s.resources    = "ZeroKit/**/*.js"
end

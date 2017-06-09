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

  # Built native crypto libs
  s.preserve_paths = "out/**/libZeroKitClientNative.a"

  # Build native crypto libs
  s.prepare_command = <<-CMD
                        export ARCHS="armv7,arm64,x86_64,i386"
                        make || { echo Building ZeroKit native crypto failed; exit 1; }
                      CMD
  
  # Link native crypto lib
  s.pod_target_xcconfig = { "_LIBS_DIR" => "$(SRCROOT)/ZeroKit/out",
                            "LIBRARY_SEARCH_PATHS[arch=arm64]" => "$(_LIBS_DIR)/ios_arm64",
                            "LIBRARY_SEARCH_PATHS[arch=armv7]" => "$(_LIBS_DIR)/ios_arm",
                            "LIBRARY_SEARCH_PATHS[arch=i386]" => "$(_LIBS_DIR)/ios_x86",
                            "LIBRARY_SEARCH_PATHS[arch=x86_64]" => "$(_LIBS_DIR)/ios_x64",
                            "OTHER_LDFLAGS" => "-lZeroKitClientNative",
                            "PRODUCT_BUNDLE_IDENTIFIER" => "com.tresorit.zerokit" }

  s.libraries = "c++"
end

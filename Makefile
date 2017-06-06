# This is a Makefile to support building the ZeroKit Xcode project

BUILD_DIR="ZeroKitNative"

build install:
	echo "Building ZeroKitNative for $(ARCHS)..."

ifneq (,$(findstring armv7,$(ARCHS)))
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=arm OUTDIR=../out/ios_arm -j
endif

ifneq (,$(findstring arm64,$(ARCHS)))
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=arm64 OUTDIR=../out/ios_arm64 -j
endif

ifneq (,$(findstring x86_64,$(ARCHS)))
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=x64 OUTDIR=../out/ios_x64 -j
endif

ifneq (,$(findstring i386,$(ARCHS)))
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=x86 OUTDIR=../out/ios_x86 -j
endif

clean:
	echo "Cleaning ZeroKitNative..."
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=arm OUTDIR=../out/ios_arm clean
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=arm64 OUTDIR=../out/ios_arm64 clean
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=x64 OUTDIR=../out/ios_x64 clean
	make -C $(BUILD_DIR) TARGET_OS=ios TARGET_CPU=x86 OUTDIR=../out/ios_x86 clean

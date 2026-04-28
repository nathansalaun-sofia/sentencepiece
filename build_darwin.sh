set -e

# Restrict the dylib's exported symbols to sentencepiece's own namespace, so
# bundled protobuf/abseil symbols don't weak-coalesce with another copy in the
# host process (e.g. Firebase's statically-linked protobuf).
EXPORT_LIST="$(realpath sentencepiece.exp)"

# Applies to libsentencepiece itself: restrict exports, and allow undefined
# symbols (a no-op for libsentencepiece since its protobuf/absl are statically
# linked, but needed for libsentencepiece_train.dylib which references those
# symbols across the shared-library boundary). We don't ship libsentencepiece_train,
# but the install step still requires it to link successfully.
LDFLAGS="-Wl,-exported_symbols_list,${EXPORT_LIST} -Wl,-undefined,dynamic_lookup"

# Same rationale for the spm_* CLI executables: not shipped, but must link.
EXE_LDFLAGS="-Wl,-undefined,dynamic_lookup"

# $1: dylib path
# $2: output framework path
# $3: headers path
# $4: platform sdk name (iphoneos | iphonesimulator | macosx)
# $5: minimum OS version
create_framework () {
    rm -rf $2
    mkdir -p $2

    # Lib
    lipo -create $1 -output $2/libsentencepiece 
    echo "Setting rpath to @rpath/libsentencepiece.framework/libsentencepiece"
    install_name_tool -id @rpath/libsentencepiece.framework/libsentencepiece $2/libsentencepiece

    # Headers
    mkdir -p $2/Headers
    cp $3/sentencepiece_processor.h $2/Headers

    # Modulemap
    mkdir -p $2/Modules
    cat > $2/Modules/module.modulemap <<- EOM
framework module libsentencepiece {
    header "sentencepiece_processor.h"
    export *
    requires cplusplus
}
EOM

    # Info.plist — platform-specific keys
    case "$4" in
        iphoneos)        supported_platform="iPhoneOS";        min_version_key="MinimumOSVersion" ;;
        iphonesimulator) supported_platform="iPhoneSimulator"; min_version_key="MinimumOSVersion" ;;
        macosx)          supported_platform="MacOSX";          min_version_key="LSMinimumSystemVersion" ;;
        *) echo "Unknown platform: $4" >&2; exit 1 ;;
    esac

    cat > $2/Info.plist <<- EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.google.sentencepiece</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>sentencepiece</string>
    <key>CFBundleExecutable</key>
    <string>libsentencepiece</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleVersion</key>
    <string>0.2.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>${supported_platform}</string>
    </array>
    <key>DTPlatformName</key>
    <string>$4</string>
    <key>${min_version_key}</key>
    <string>$5</string>
</dict>
</plist>
EOM
}

# iOS
mkdir -p build_ios
cd build_ios
mkdir -p install
cmake .. -GXcode -DCMAKE_TOOLCHAIN_FILE="../cmake/ios.toolchain.cmake" -DCMAKE_SYSTEM_NAME="iOS" -DPLATFORM="OS64" -DDEPLOYMENT_TARGET="18.6" -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" -DCMAKE_EXE_LINKER_FLAGS="${EXE_LDFLAGS}"
cmake --build . --config Release
cmake --install . --prefix "$(realpath install)"
cd ..

# iOS Simulator
mkdir -p build_iphonesimulator
cd build_iphonesimulator
mkdir -p install
cmake .. -GXcode -DCMAKE_TOOLCHAIN_FILE="../cmake/ios.toolchain.cmake" -DCMAKE_SYSTEM_NAME="iOS" -DPLATFORM="SIMULATORARM64" -DDEPLOYMENT_TARGET="18.6" -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" -DCMAKE_EXE_LINKER_FLAGS="${EXE_LDFLAGS}"
cmake --build . --config Release
cmake --install . --prefix "$(realpath install)"
cd ..

# macOS
mkdir -p build_macos
cd build_macos
mkdir -p install
cmake .. -GXcode -DDEPLOYMENT_TARGET="15.5" -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" -DCMAKE_EXE_LINKER_FLAGS="${EXE_LDFLAGS}"
cmake --build . --config Release
cmake --install . --prefix "$(realpath install)"
cd ..

# Replace links by their actual file
# This is necessary because SOVERSION is "0" in the CMakeLists so the file MUST be named libsentencepiece.0.dylib otherwise dyld won't find it at runtime
rm build_ios/install/lib/libsentencepiece.0.dylib
rm build_macos/install/lib/libsentencepiece.0.dylib
rm build_iphonesimulator/install/lib/libsentencepiece.0.dylib

cp build_ios/install/lib/libsentencepiece.0.0.0.dylib build_ios/install/lib/libsentencepiece.0.dylib
cp build_macos/install/lib/libsentencepiece.0.0.0.dylib build_macos/install/lib/libsentencepiece.0.dylib
cp build_iphonesimulator/install/lib/libsentencepiece.0.0.0.dylib build_iphonesimulator/install/lib/libsentencepiece.0.dylib

# Create frameworks
create_framework build_ios/install/lib/libsentencepiece.0.dylib build_ios/libsentencepiece.framework build_ios/install/include iphoneos 18.6
create_framework build_iphonesimulator/install/lib/libsentencepiece.0.dylib build_iphonesimulator/libsentencepiece.framework build_iphonesimulator/install/include iphonesimulator 18.6
create_framework build_macos/install/lib/libsentencepiece.0.dylib build_macos/libsentencepiece.framework build_macos/install/include macosx 15.5

# Create xcframework
# sentencepiece HAS to be linked dynamically because it has conflicting dependencies with the Firebase SDK (protobuf and abseil) which is linked statically in the app
rm -rf libsentencepiece.xcframework
xcodebuild -create-xcframework -framework build_ios/libsentencepiece.framework -framework build_macos/libsentencepiece.framework -framework build_iphonesimulator/libsentencepiece.framework -output libsentencepiece.xcframework
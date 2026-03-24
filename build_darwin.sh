set -e

# iOS
mkdir -p build_ios
cd build_ios
mkdir -p install
cmake .. -GXcode -DCMAKE_TOOLCHAIN_FILE="../cmake/ios.toolchain.cmake" -DCMAKE_SYSTEM_NAME="iOS" -DPLATFORM="OS64" -DDEPLOYMENT_TARGET="18.6"
cmake --build . --config Release
cmake --install . --prefix "$(realpath install)"
cd ..

# iOS Simulator
mkdir -p build_iphonesimulator
cd build_iphonesimulator
mkdir -p install
cmake .. -GXcode -DCMAKE_TOOLCHAIN_FILE="../cmake/ios.toolchain.cmake" -DCMAKE_SYSTEM_NAME="iOS" -DPLATFORM="SIMULATORARM64" -DDEPLOYMENT_TARGET="18.6"
cmake --build . --config Release
cmake --install . --prefix "$(realpath install)"
cd ..

# macOS
mkdir -p build_macos
cd build_macos
mkdir -p install
cmake .. -GXcode -DDEPLOYMENT_TARGET="15.5"
cmake --build . --config Release
cmake --install . --prefix "$(realpath install)"
cd ..

# Create xcframework
rm -rf libsentencepiece.xcframework
xcodebuild -create-xcframework -library build_ios/install/lib/libsentencepiece.0.0.0.dylib -headers build_ios/install/include -library build_macos/install/lib/libsentencepiece.0.0.0.dylib -headers build_macos/install/include -library build_iphonesimulator/install/lib/libsentencepiece.0.0.0.dylib -headers build_iphonesimulator/install/include -output libsentencepiece.xcframework
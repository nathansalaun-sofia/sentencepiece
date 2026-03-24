# iOS
mkdir build_ios
cd build_ios
mkdir install
cmake .. -GXcode -DCMAKE_TOOLCHAIN_FILE="../cmake/ios.toolchain.cmake" -DCMAKE_SYSTEM_NAME="iOS" -DPLATFORM="OS64" -DDEPLOYMENT_TARGET="18.6"
cmake --build . --config Release
cmake --install . --prefix "install"
cd ..

# iOS Simulator
mkdir build_iphonesimulator
cd build_iphonesimulator
mkdir install
cmake .. -GXcode -DCMAKE_TOOLCHAIN_FILE="../cmake/ios.toolchain.cmake" -DCMAKE_SYSTEM_NAME="iOS" -DPLATFORM="SIMULATOR64" -DDEPLOYMENT_TARGET="18.6"
cmake --build . --config Release
cmake --install . --prefix "install"
cd ..

# macOS
mkdir build_macos
cd build_macos
mkdir install
cmake .. -GXcode -DDEPLOYMENT_TARGET="15.5"
cmake --build . --config Release
cmake --install . --prefix "install"
cd ..

# Create xcframework
rm -rf libsentencepiece.xcframework
xcodebuild -create-xcframework -library build_ios/install/lib/libsentencepiece.a -library build_iphonesimulator/install/lib/libsentencepiece.a -library build_macos/install/lib/libsentencepiece.a -headers build_ios/install/include -headers build_macos/install/include -output libsentencepiece.xcframework
cp -R libsentencepiece.xcframework/macos-arm64/Headers libsentencepiece.xcframework/ios-arm64/Headers
echo "Don't forget to edit Info.plist to add missing iOS and simulator HeadersPath tags (copy paste from macOS)"
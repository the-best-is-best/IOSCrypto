#!/bin/bash
set -e

# Configuration
ARCHIVE_PATH="build"
FRAMEWORK_NAME="kmmcrypto"
SCHEME="kmmcrypto"
DERIVED_DATA_PATH="DerivedData"  # Fixed typo from original error
WORKSPACE_NAME="${FRAMEWORK_NAME}.xcworkspace"  # Changed to workspace
PROJECT_NAME="${FRAMEWORK_NAME}.xcodeproj"
MODULE_MAP_FILE="module.modulemap"
XCPRETTY_AVAILABLE=$(command -v xcpretty >/dev/null && echo "yes" || echo "no")

# Verify project existence
if [ -d "$WORKSPACE_NAME" ]; then
    BUILD_TARGET="-workspace \"$WORKSPACE_NAME\""
elif [ -d "$PROJECT_NAME" ]; then
    BUILD_TARGET="-project \"$PROJECT_NAME\""
else
    echo "❌ Error: Neither $WORKSPACE_NAME nor $PROJECT_NAME found in $(pwd)"
    echo "Contents of current directory:"
    ls -la
    exit 1
fi

# Cleanup
echo "🧹 Cleaning up..."
rm -rf "$ARCHIVE_PATH" "$DERIVED_DATA_PATH"
mkdir -p "$ARCHIVE_PATH"

# Create modulemap if missing
if [ ! -f "$MODULE_MAP_FILE" ]; then
  echo "📝 Creating module map file..."
  cat > "$MODULE_MAP_FILE" <<EOL
framework module $FRAMEWORK_NAME {
  umbrella header "${FRAMEWORK_NAME}.h"
  export *
  module * { export * }
}
EOL
fi

# Build function with improved error handling
build_archive() {
    local platform="$1"
    local suffix="$2"
    local sdk="$3"
    local destination="$4"
    
    echo "🔨 Building for $platform (SDK: $sdk)..."
    
    local build_command="xcodebuild archive \
      $BUILD_TARGET \
      -scheme \"$SCHEME\" \
      -destination \"$destination\" \
      -archivePath \"$ARCHIVE_PATH/$FRAMEWORK_NAME-$suffix.xcarchive\" \
      -derivedDataPath \"$DERIVED_DATA_PATH\" \
      -sdk \"$sdk\" \
      -configuration Release \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      SKIP_INSTALL=NO \
      INSTALL_PATH=\"/Library/Frameworks\" \
      PUBLIC_HEADERS_FOLDER_PATH=\"$FRAMEWORK_NAME.framework/Headers\" \
      OTHER_CFLAGS=\"-fmodule-map-file=\$PWD/$MODULE_MAP_FILE\" \
      GCC_INSTALL_HEADERS=YES \
      CLANG_ENABLE_MODULES=YES \
      DEFINES_MODULE=YES"

    echo "🚀 Build command:"
    echo "$build_command"
    
    if [ "$XCPRETTY_AVAILABLE" = "yes" ]; then
        eval "$build_command" | xcpretty || { echo "❌ Build failed"; exit 1; }
    else
        eval "$build_command" || { echo "❌ Build failed"; exit 1; }
    fi
}

# Build for device
build_archive "iOS" "device" "iphoneos" "generic/platform=iOS"

# Build for simulator
build_archive "iOS Simulator" "simulator" "iphonesimulator" "generic/platform=iOS Simulator"

# Enhanced framework finder
find_framework() {
    local suffix="$1"
    local platform="$2"
    
    # Possible framework locations
    local search_paths=(
        "$ARCHIVE_PATH/$FRAMEWORK_NAME-$suffix.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
        "$ARCHIVE_PATH/$FRAMEWORK_NAME-$suffix.xcarchive/Products/usr/local/lib/$FRAMEWORK_NAME.framework"
        "$DERIVED_DATA_PATH/Build/Products/Release-$platform/$FRAMEWORK_NAME.framework"
        "$DERIVED_DATA_PATH/Build/Products/Release/$FRAMEWORK_NAME.framework"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    echo "❌ Error: Failed to locate $suffix framework in:"
    printf "  - %s\n" "${search_paths[@]}"
    echo "Searching all derived data:"
    find "$DERIVED_DATA_PATH" -name "$FRAMEWORK_NAME.framework" -print
    exit 1
}

# Locate frameworks
DEVICE_FRAMEWORK=$(find_framework "device" "iphoneos")
SIMULATOR_FRAMEWORK=$(find_framework "simulator" "iphonesimulator")

echo "📌 Device framework found at: $DEVICE_FRAMEWORK"
echo "📌 Simulator framework found at: $SIMULATOR_FRAMEWORK"

# Create XCFramework
echo "📦 Creating XCFramework..."
rm -rf "$ARCHIVE_PATH/$FRAMEWORK_NAME.xcframework"
xcodebuild -create-xcframework \
  -framework "$DEVICE_FRAMEWORK" \
  -framework "$SIMULATOR_FRAMEWORK" \
  -output "$ARCHIVE_PATH/$FRAMEWORK_NAME.xcframework"

# Verify output
if [ ! -d "$ARCHIVE_PATH/$FRAMEWORK_NAME.xcframework" ]; then
    echo "❌ Error: XCFramework creation failed"
    exit 1
fi

echo "✅ Success! XCFramework created at: $ARCHIVE_PATH/$FRAMEWORK_NAME.xcframework"
echo "📦 Final structure:"
tree -L 3 "$ARCHIVE_PATH/$FRAMEWORK_NAME.xcframework"
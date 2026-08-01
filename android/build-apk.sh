#!/bin/bash
set -e

echo "=== Build Kids Study APK ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_DIR/build"

# Clean and create build dir
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/obj"

# Paths
ANDROID_JAR="$ANDROID_SDK_ROOT/platforms/android-34/android.jar"
BUILD_TOOLS="$ANDROID_SDK_ROOT/build-tools/34.0.0"

echo "SDK Root: $ANDROID_SDK_ROOT"
echo "Android JAR: $ANDROID_JAR"

# 1. Compile Java -> .class files
echo "--- Compiling Java ---"
javac -source 11 -target 11 \
    -bootclasspath "$ANDROID_JAR" \
    -d "$BUILD_DIR/obj" \
    "$PROJECT_DIR/MainActivity.java"

echo "Java compilation done."

# 2. Convert .class -> .dex (D8)
echo "--- Converting to DEX ---"
"$BUILD_TOOLS/d8" \
    --lib "$ANDROID_JAR" \
    --output "$BUILD_DIR" \
    $(find "$BUILD_DIR/obj" -name "*.class")

echo "DEX conversion done."

# 3. Compile resources with aapt2
echo "--- Compiling resources ---"
"$BUILD_TOOLS/aapt2" compile \
    -o "$BUILD_DIR/compiled.flata" \
    --dir "$PROJECT_DIR/res/"

echo "--- Linking APK ---"
"$BUILD_TOOLS/aapt2" link \
    -o "$BUILD_DIR/base.apk" \
    -I "$ANDROID_JAR" \
    --manifest "$PROJECT_DIR/AndroidManifest.xml" \
    "$BUILD_DIR/compiled.flata" \
    --auto-add-overlay

echo "APK base created."

# 4. Add classes.dex to APK
echo "--- Adding DEX to APK ---"
cd "$BUILD_DIR"
zip -j base.apk classes.dex

# 5. Generate debug keystore
echo "--- Generating keystore ---"
keytool -genkey -v \
    -keystore "$BUILD_DIR/debug.keystore" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug, O=KidsStudy, C=CN"

# 6. Sign APK
echo "--- Signing APK ---"
"$BUILD_TOOLS/apksigner" sign \
    --ks "$BUILD_DIR/debug.keystore" \
    --ks-pass pass:android \
    --ks-key-alias androiddebugkey \
    --key-pass pass:android \
    --out "$BUILD_DIR/kids-study-signed.apk" \
    "$BUILD_DIR/base.apk"

# 7. Zip align
echo "--- Aligning APK ---"
"$BUILD_TOOLS/zipalign" -f 4 \
    "$BUILD_DIR/kids-study-signed.apk" \
    "$BUILD_DIR/kids-study.apk"

echo "=== APK BUILD SUCCESS ==="
echo "Output: $BUILD_DIR/kids-study.apk"
ls -lh "$BUILD_DIR/kids-study.apk"

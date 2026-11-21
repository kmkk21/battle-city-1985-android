#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antigravity/battle-city-android"
BUILD_DIR="$PROJECT_DIR/build"
SDK="/opt/android-sdk"
BT="$SDK/build-tools/35.0.0"
PLATFORM="$SDK/platforms/android-34/android.jar"
KEYSTORE="$PROJECT_DIR/battlecity-debug.keystore"
OUT_APK="$PROJECT_DIR/BattleCity1985.apk"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/res_compiled" "$BUILD_DIR/gen" "$BUILD_DIR/classes" "$BUILD_DIR/dex"

echo "[1/6] Compiling resources with aapt2..."
"$BT/aapt2" compile --dir "$PROJECT_DIR/res" -o "$BUILD_DIR/res_compiled/res.zip"

echo "[2/6] Linking resources and generating R.java..."
"$BT/aapt2" link \
  -I "$PLATFORM" \
  --manifest "$PROJECT_DIR/AndroidManifest.xml" \
  -A "$PROJECT_DIR/assets" \
  --java "$BUILD_DIR/gen" \
  -o "$BUILD_DIR/unsigned.apk" \
  "$BUILD_DIR/res_compiled/res.zip"

echo "[3/6] Compiling Java sources..."
javac --release 8 \
  -classpath "$PLATFORM" \
  -d "$BUILD_DIR/classes" \
  "$BUILD_DIR/gen/com/retro/battlecity/R.java" \
  "$PROJECT_DIR/src/com/retro/battlecity/MainActivity.java"

echo "[4/6] Converting bytecode to DEX with d8..."
"$BT/d8" --min-api 24 --lib "$PLATFORM" --output "$BUILD_DIR/dex" \
  "$BUILD_DIR/classes/com/retro/battlecity/"*.class

echo "[5/6] Packaging classes.dex and aligning APK..."
(cd "$BUILD_DIR/dex" && zip -q "$BUILD_DIR/unsigned.apk" classes.dex)
"$BT/zipalign" -f -p 4 "$BUILD_DIR/unsigned.apk" "$BUILD_DIR/aligned.apk"

echo "[6/6] Signing APK with apksigner..."
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -storepass battlecity1985 \
    -keypass battlecity1985 \
    -alias battlecity \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=BattleCity1985, OU=Retro, O=Retro, L=Seoul, ST=Seoul, C=KR" >/dev/null 2>&1
fi

"$BT/apksigner" sign \
  --ks "$KEYSTORE" \
  --ks-pass pass:battlecity1985 \
  --key-pass pass:battlecity1985 \
  --ks-key-alias battlecity \
  --out "$OUT_APK" \
  "$BUILD_DIR/aligned.apk"

echo "Verifying APK signature..."
"$BT/apksigner" verify --verbose "$OUT_APK"
ls -lh "$OUT_APK"

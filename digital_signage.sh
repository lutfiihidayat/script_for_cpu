#!/bin/bash

IP="$1"
DEVICE="$IP:5555"

APK_URL="https://github.com/lutfiihidayat/script_for_cpu/
PROD20260025.apk"
APK_FILE="app.apk"

PACKAGE="id.bgn.sbn.ds"
ACTIVITY="id.bgn.sbn.ds/id.dmmgroup.dmmplayersignage.Splash"
TARGET_VERSION_CODE=25

echo "[ADB] Processing $DEVICE"

# ================= DOWNLOAD APK =================
if [ ! -f "$APK_FILE" ]; then
    echo "[ADB] Download APK..."
    curl -L -o "$APK_FILE" "$APK_URL"
fi

# ================= CONNECT =================
adb connect "$DEVICE" >/dev/null 2>&1

STATUS=$(adb devices | grep "$DEVICE" | awk '{print $2}')
if [ "$STATUS" != "device" ]; then
    echo "$DEVICE,OFFLINE"
    exit
fi

# ================= CHECK VERSION =================
VERSION_INFO=$(adb -s "$DEVICE" shell dumpsys package "$PACKAGE" 2>/dev/null | grep versionCode)

if [ -z "$VERSION_INFO" ]; then
    CURRENT_VERSION=0
else
    CURRENT_VERSION=$(echo "$VERSION_INFO" | awk -F= '{print $2}' | awk '{print $1}')
fi

# ================= INSTALL =================
if [ "$CURRENT_VERSION" -lt "$TARGET_VERSION_CODE" ]; then
    echo "[ADB] Installing APK..."

    OUTPUT=$(adb -s "$DEVICE" install -r "$APK_FILE" 2>&1)

    if ! echo "$OUTPUT" | grep -q "Success"; then
        echo "$DEVICE,INSTALL_FAILED"
        exit
    fi
fi

# ================= START APP =================
adb -s "$DEVICE" shell am start -n "$ACTIVITY" >/dev/null 2>&1

echo "$DEVICE,SUCCESS"

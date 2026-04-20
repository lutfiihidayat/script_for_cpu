#!/bin/bash

IP="$1"
DEVICE="$IP:5555"

APK_URL="https://raw.githubusercontent.com/lutfiihidayat/script_for_cpu/main/PROD20260025.apk"
APK_FILE="app.apk"

PACKAGE="id.bgn.sbn.ds"
ACTIVITY="id.bgn.sbn.ds/id.dmmgroup.dmmplayersignage.Splash"
TARGET_VERSION_CODE=25

MAX_INSTALL_RETRY=3
MAX_ID_RETRY=5

echo "[ADB] Processing $DEVICE"

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

echo "[ADB] Current version: $CURRENT_VERSION"

# ================= INSTALL ONLY IF NEEDED =================
if [ "$CURRENT_VERSION" -lt "$TARGET_VERSION_CODE" ]; then

    echo "[ADB] Version < $TARGET_VERSION_CODE → Update diperlukan"

    # ================= CHECK APK =================
    NEED_DOWNLOAD=0

    if [ ! -f "$APK_FILE" ]; then
        NEED_DOWNLOAD=1
    else
        FILE_TYPE=$(file "$APK_FILE")
        if [[ "$FILE_TYPE" != *"Android"* ]]; then
            NEED_DOWNLOAD=1
        fi
    fi

    # ================= DOWNLOAD =================
    if [ $NEED_DOWNLOAD -eq 1 ]; then
        echo "[ADB] Download APK..."
        curl -L -o "$APK_FILE" "$APK_URL"

        if [ ! -f "$APK_FILE" ]; then
            echo "$DEVICE,APK_DOWNLOAD_FAILED"
            exit
        fi
    else
        echo "[ADB] APK sudah ada, skip download"
    fi

    # ================= VALIDASI APK =================
    FILE_TYPE=$(file "$APK_FILE")
    if [[ "$FILE_TYPE" != *"Android"* ]]; then
        echo "$DEVICE,INVALID_APK"
        exit
    fi

    # ================= INSTALL =================
    echo "[ADB] Installing APK..."

    RETRY=1
    INSTALL_OK=0

    while [ $RETRY -le $MAX_INSTALL_RETRY ]
    do
        OUTPUT=$(adb -s "$DEVICE" install -r "$APK_FILE" 2>&1)

        if echo "$OUTPUT" | grep -q "Success"; then
            INSTALL_OK=1
            break
        fi

        RETRY=$((RETRY+1))
        sleep 2
    done

    if [ $INSTALL_OK -eq 0 ]; then
        echo "$DEVICE,INSTALL_FAILED"
        exit
    fi

else
    echo "[ADB] Version sudah terbaru → skip install"
fi

# ================= FIX PERMISSION =================
adb -s "$DEVICE" shell appops set "$PACKAGE" REQUEST_INSTALL_PACKAGES allow >/dev/null 2>&1
adb -s "$DEVICE" shell settings put global verifier_verify_adb_installs 0 >/dev/null 2>&1

# ================= START APP =================
adb -s "$DEVICE" shell am start -n "$ACTIVITY" >/dev/null 2>&1

sleep 3

# ================= GET DEVICE ID =================
DEVICE_ID=""
TRY=1

while [ $TRY -le $MAX_ID_RETRY ]
do
    DEVICE_ID=$(adb -s "$DEVICE" shell \
    "uiautomator dump /sdcard/x.xml >/dev/null && grep -o '[A-F0-9]\{16\}' /sdcard/x.xml | head -n 1")

    if [[ "$DEVICE_ID" =~ ^[A-F0-9]{16}$ ]]; then
        break
    fi

    TRY=$((TRY+1))
    sleep 2
done

# ================= RESULT =================
if [[ "$DEVICE_ID" =~ ^[A-F0-9]{16}$ ]]; then
    echo "$DEVICE,SUCCESS,VERSION=$CURRENT_VERSION,ID=$DEVICE_ID"
else
    echo "$DEVICE,DEVICE_ID_NOT_FOUND"
fi
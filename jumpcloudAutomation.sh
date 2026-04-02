#!/bin/bash

SUDO_PASS="151971"

PVR_SCRIPT_URL="https://raw.githubusercontent.com/lutfiihidayat/script_for_cpu/main/pvr_dapur.py"
ADB_SCRIPT_URL="https://raw.githubusercontent.com/lutfiihidayat/script_for_cpu/main/digital_signage.sh"

BOT_TOKEN="8512215313:AAHlAiCIjau7nKCfBC-5HWO9W8evE21lzZw"
CHAT_ID="-1003384312801"
HOSTNAME=$(hostname)
TMP_PVR="pvr.txt"
TMP_ADB="adb.txt"
TMP_CCTV="cctv.txt"

> "$TMP_PVR"
> "$TMP_ADB"
> "$TMP_CCTV"

run_sudo() {
    echo "$SUDO_PASS" | sudo -S "$@"
}

echo "=============================="
echo " AUTO SCAN + REPORT"
echo "=============================="

# ================= INSTALL =================
command -v nmap &> /dev/null || run_sudo apt install nmap -y
command -v python3 &> /dev/null || run_sudo apt install python3 python3-pip -y
command -v adb &> /dev/null || run_sudo apt install adb -y

python3 -m pip show requests &> /dev/null || python3 -m pip install requests

# ================= DOWNLOAD =================
curl -s -o pvr_dapur.py $PVR_SCRIPT_URL
curl -s -o digital_signage.sh $ADB_SCRIPT_URL
chmod +x digital_signage.sh

# ================= NETWORK =================
BASE=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n1 | cut -d. -f1-3)

for i in {1..254}; do
    ping -c 1 -W 1 $BASE.$i > /dev/null 2>&1 &
done
wait

IPS=$(arp -a | awk -F '[()]' '{print $2}' | grep -E "^$BASE\." | sort -u)

echo "[INFO] Total IP: $(echo "$IPS" | wc -l)"

# ================= PROCESS =================
for ip in $IPS; do
(
    result=$(nmap -Pn -p 1443,5555,554 --open -oG - $ip)

    # ---------- PVR ----------
    if echo "$result" | grep -q "1443/open"; then
        out=$(python3 pvr_dapur.py $ip)
        echo "$out"
        echo "$out" >> "$TMP_PVR"
    fi

    # ---------- ADB ----------
    if echo "$result" | grep -q "5555/open"; then
        out=$(./digital_signage.sh $ip)
        echo "$out"
        echo "$out" >> "$TMP_ADB"
    fi

    # ---------- CCTV ----------
    if echo "$result" | grep -q "554/open"; then
        echo "$ip,PORT_554_OPEN" >> "$TMP_CCTV"
    fi

) &
done

wait

# ================= FORMAT =================
PVR_RESULTS=$(cat "$TMP_PVR")
ADB_RESULTS=$(cat "$TMP_ADB")
CCTV_RESULTS=$(cat "$TMP_CCTV")

PVR_RESULTS=$(echo "$PVR_RESULTS" | sed 's/,/ | /g')
ADB_RESULTS=$(echo "$ADB_RESULTS" | sed 's/,/ | /g')
CCTV_RESULTS=$(echo "$CCTV_RESULTS" | sed 's/,/ | /g')

TOTAL_PVR=$(wc -l < "$TMP_PVR")
TOTAL_ADB=$(wc -l < "$TMP_ADB")
TOTAL_CCTV=$(grep -c "PORT_554_OPEN" "$TMP_CCTV")

REPORT="📡 AUTO REPORT $HOSTNAME

🟢 PVR ($TOTAL_PVR)
$PVR_RESULTS

📺 DIGITAL SIGNAGE ($TOTAL_ADB)
$ADB_RESULTS

🎥 CCTV ($TOTAL_CCTV FOUND)
$CCTV_RESULTS"

# ================= TELEGRAM =================
echo "[INFO] Send to Telegram..."

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
-d "chat_id=$CHAT_ID" \
-d "text=$REPORT"

echo "=============================="
echo " DONE"
echo "=============================="
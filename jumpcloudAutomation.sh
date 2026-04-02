#!/bin/bash

SUDO_PASS="151971"

PVR_SCRIPT_URL="https://raw.githubusercontent.com/lutfiihidayat/script_for_cpu/main/pvr_dapur.py"
ADB_SCRIPT_URL="https://raw.githubusercontent.com/lutfiihidayat/script_for_cpu/main/digital_signage.sh"

run_sudo() {
    echo "$SUDO_PASS" | sudo -S "$@"
}

echo "=============================="
echo " AUTO SCAN + PVR + ADB"
echo "=============================="

# ================= INSTALL =================
if ! command -v nmap &> /dev/null; then
    run_sudo apt update -y
    run_sudo apt install nmap -y
fi

if ! command -v python3 &> /dev/null; then
    run_sudo apt install python3 python3-pip -y
fi

if ! command -v pip3 &> /dev/null; then
    run_sudo apt install python3-pip -y
fi

if ! command -v adb &> /dev/null; then
    run_sudo apt install adb -y
fi

# python deps
python3 -m pip show requests &> /dev/null
if [ $? -ne 0 ]; then
    python3 -m pip install requests
fi

# ================= DOWNLOAD =================
echo "[INFO] Download scripts..."
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
    result=$(nmap -Pn -p 1443,5555 --open -oG - $ip)

    if echo "$result" | grep -q "1443/open"; then
        echo "[PVR] $ip"
        python3 pvr_dapur.py $ip
    fi

    if echo "$result" | grep -q "5555/open"; then
        echo "[ADB] $ip"
        ./digital_signage.sh $ip
    fi

) &
done

wait

echo "=============================="
echo " DONE"
echo "=============================="

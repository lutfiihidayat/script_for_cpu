import requests
import re
import time
import random
import sys

requests.packages.urllib3.disable_warnings()

PORT = 1443
NEW_PASS = "Peruri@123"
OLD_PASS = "admin@123"
MIDDLEWARE = "https://sipgn-api.bgn.go.id/api/v1/middleware-pvr-dapur"

# ================= SAFE REQUEST =================
def safe_request(session, method, url, **kwargs):
    for _ in range(3):
        try:
            time.sleep(random.uniform(0.4, 1.2))
            return session.request(method, url, timeout=10, **kwargs)
        except requests.exceptions.RequestException:
            time.sleep(2)
    return None

def extract_hash(html):
    match = re.search(r'name="hash"\s+value="([^"]+)"', html)
    return match.group(1) if match else None

def extract_serial_number(html):
    patterns = [
        r'Nomor Seri.*?<td>([^<]+)</td>',
        r'Serial Number.*?<td>([^<]+)</td>'
    ]

    for pattern in patterns:
        match = re.search(pattern, html, re.DOTALL | re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return None

# ================= LOGIN FIX =================
def login(session, base, password):

    safe_request(session, "GET", f"{base}/login.html")

    payload = {
        "username": "admin",
        "password": password
    }

    r = safe_request(
        session,
        "POST",
        f"{base}/action/login",
        data=payload,
        allow_redirects=True
    )

    if not r:
        return False

    # ✅ cek redirect
    if "start.html" in r.url.lower():
        return True

    # ✅ cek dashboard
    check = safe_request(session, "GET", f"{base}/start.html")

    if check and check.status_code == 200:
        text = check.text.lower()

        if any(x in text for x in ["frame", "menu", "logout", "system"]):
            return True

    return False


# ================= MAIN PROCESS =================
def process_device(ip):

    base = f"https://{ip}:{PORT}"

    session = requests.Session()
    session.verify = False

    print(f"[INFO] Processing {ip}")

    # ================= LOGIN FLOW =================
    if login(session, base, NEW_PASS):
        print(f"[INFO] Login pakai NEW_PASS")
    elif login(session, base, OLD_PASS):
        print(f"[INFO] Login pakai OLD_PASS")
    else:
        print(f"{ip},LOGIN_FAILED")
        return

    # beri waktu session stabil
    time.sleep(1)

    # ================= GET SN =================
    pages = ["deviceinfo.html", "systeminfo.html"]

    sn = None
    for page in pages:
        r = safe_request(session, "GET", f"{base}/{page}")
        if r:
            sn = extract_serial_number(r.text)
            if sn:
                break

    if not sn:
        print(f"{ip},SN_NOT_FOUND")
        return

    # ================= UPDATE =================
    r = safe_request(session, "GET", f"{base}/cloud.html")
    if not r:
        print(f"{ip},{sn},CLOUD_FAIL")
        return

    hash_device = extract_hash(r.text)

    if not hash_device:
        print(f"{ip},{sn},HASH_FAIL")
        return

    payload = {
        "WebServerURLModel": "1",
        "cloudserver": MIDDLEWARE,
        "cloudport": "8081",
        "hash": hash_device
    }

    r = safe_request(
        session,
        "POST",
        f"{base}/action/deviceset?act=3",
        data=payload
    )

    if not r:
        print(f"{ip},{sn},UPDATE_FAILED")
        return

    print(f"{ip},{sn},SUCCESS")


# ================= ENTRY =================
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python pvr_dapur.py <ip>")
        exit(1)

    process_device(sys.argv[1])
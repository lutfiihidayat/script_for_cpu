import requests
import urllib3
import re
import time
import random
import sys

urllib3.disable_warnings()

# ================= CONFIG =================
OLD_PASS = "admin@123"
NEW_PASS = "Peruri@123"
MIDDLEWARE = "https://sipgn-api.bgn.go.id/api/v1/middleware-pvr-dapur"
PORT = 1443
# ==========================================

# ================= SAFE REQUEST =================
def safe_request(session, method, url, **kwargs):
    for _ in range(3):
        try:
            time.sleep(random.uniform(0.4, 1.2))
            return session.request(method, url, timeout=10, **kwargs)
        except requests.exceptions.RequestException:
            time.sleep(2)
    return None

# ================= PARSER =================
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

# ================= DEVICE PROCESS =================
def process_device(ip):

    BASE = f"https://{ip}:{PORT}"

    def new_session():
        s = requests.Session()
        s.verify = False
        return s

    # ================= LOGIN =================
    def login(session, password):

        headers = {
            "User-Agent": "Mozilla/5.0",
            "Referer": f"{BASE}/login.html",
            "Content-Type": "application/x-www-form-urlencoded"
        }

        safe_request(session, "GET", f"{BASE}/login.html", headers=headers)

        payload = {
            "username": "admin",
            "password": password
        }

        r = safe_request(
            session,
            "POST",
            f"{BASE}/action/login",
            data=payload,
            headers=headers,
            allow_redirects=True
        )

        if not r:
            return False

        # ================= COOKIE CHECK =================
        cookies = session.cookies.get_dict()
        if "uid" in cookies or "username" in cookies:
            return True

        # ================= URL CHECK =================
        if "start.html" in r.url.lower():
            return True

        # ================= DASHBOARD CHECK =================
        check = safe_request(session, "GET", f"{BASE}/start.html")

        if check and check.status_code == 200:
            text = check.text.lower()

            if any(x in text for x in [
                "frame",
                "menu",
                "logout",
                "system"
            ]):
                return True

        return False


    # ================= LOGIN FLOW =================
    session = new_session()

    print(f"[INFO] Processing {ip}")

    if not login(session, NEW_PASS):

        session = new_session()

        if not login(session, OLD_PASS):
            print(f"{ip},LOGIN_FAILED")
            return

        print(f"[INFO] Login pakai OLD_PASS")

        time.sleep(1)

        # ================= CHANGE PASSWORD =================
        r = safe_request(session, "GET", f"{BASE}/chgpwd.html")
        if not r:
            print(f"{ip},CHGPWD_PAGE_FAILED")
            return

        hash_pwd = extract_hash(r.text)
        if not hash_pwd:
            print(f"{ip},HASH_NOT_FOUND")
            return

        payload = {
            "oldpassword": OLD_PASS,
            "adminpwd": NEW_PASS,
            "readminpwd": NEW_PASS,
            "hash": hash_pwd
        }

        r = safe_request(
            session,
            "POST",
            f"{BASE}/action/changepwd",
            data=payload,
            allow_redirects=True
        )

        if not r:
            print(f"{ip},CHGPWD_FAILED")
            return

        session = new_session()

        if not login(session, NEW_PASS):
            print(f"{ip},RELOGIN_FAILED")
            return

    else:
        print(f"[INFO] Login pakai NEW_PASS")

    time.sleep(1)

    # ================= GET SN =================
    pages = [
        "desktop.html",
        "start.html",
        "info.html",
        "systeminfo.html",
        "deviceinfo.html"
    ]

    sn = None

    for page in pages:
        r = safe_request(session, "GET", f"{BASE}/{page}")
        if r and r.status_code == 200:
            sn = extract_serial_number(r.text)
            if sn:
                break

    if not sn:
        print(f"{ip},SN_NOT_FOUND")
        return

    # ================= UPDATE =================
    r = safe_request(session, "GET", f"{BASE}/cloud.html")
    if not r:
        print(f"{ip},{sn},CLOUD_PAGE_FAILED")
        return

    hash_device = extract_hash(r.text)
    if not hash_device:
        print(f"{ip},{sn},CLOUD_HASH_FAILED")
        return

    payload = {
        "WebServerURLModel": "1",
        "cloudserver": MIDDLEWARE,
        "BestInitializeURL": "",
        "cloudport": "8081",
        "proxyserverip": "0.0.0.0",
        "proxyserverport": "0",
        "hash": hash_device
    }

    r = safe_request(
        session,
        "POST",
        f"{BASE}/action/deviceset?act=3",
        data=payload,
        allow_redirects=True
    )

    if not r:
        print(f"{ip},{sn},MIDDLEWARE_UPDATE_FAILED")
        return

    safe_request(session, "GET", f"{BASE}/action/logout")

    print(f"{ip},{sn},SUCCESS")


# ================= ENTRY =================
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python pvr_dapur.py <ip>")
        exit(1)

    process_device(sys.argv[1])
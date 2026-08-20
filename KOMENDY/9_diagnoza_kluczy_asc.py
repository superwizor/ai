#!/usr/bin/env python3
"""Diagnostyka poswiadczen App Store Connect API.

altool zwraca 401 bez wskazania, ktora czesc zawiodla. Ten skrypt
rozdziela trzy mozliwe przyczyny:

  1. Issuer ID jest zly            -> 401 NOT_AUTHORIZED
  2. Klucz zostal uniewazniony     -> 401 NOT_AUTHORIZED
  3. Klucz ma za waska role        -> 200 na /apps, 403 na zapisie

Punkty 1 i 2 wygladaja z zewnatrz identycznie, dlatego skrypt testuje
KAZDY klucz z ~/private_keys po kolei. Jesli jeden przechodzi, a drugi
nie, przyczyna jest rozstrzygnieta bez zgadywania.

Uzycie:  python3 KOMENDY/9_diagnoza_kluczy_asc.py <ISSUER_ID>

Issuer ID: App Store Connect -> Users and Access -> Integrations ->
App Store Connect API, na gorze strony (UUID, 36 znakow).

Powstalo 20.08.2026, gdy wysylka builda 1.0.8+44 stanela na 401 z
altool. Sprawdzono wtedy lokalnie i wykluczono: oba pliki .p8 sa
poprawnymi kluczami EC P-256, konwersja podpisu DER -> raw R||S jest
poprawna (zweryfikowana roundtripem przez openssl), i zaden z kluczy
nie jest kluczem indywidualnym. Zostal wiec Issuer ID albo status
klucza po stronie Apple - i to rozstrzyga ten skrypt.

Nie wypisuje materialu klucza ani tokenu.
"""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def der_to_raw(der: bytes) -> bytes:
    """Podpis ES256 w JWT to surowe R||S po 32 bajty.

    openssl zwraca DER: SEQUENCE { INTEGER r, INTEGER s }. Podanie DER
    wprost daje token, ktory Apple odrzuca jako zle podpisany - i wtedy
    401 wyglada jak zly issuer, choc problem jest w kodowaniu.
    """
    if der[0] != 0x30:
        raise ValueError("to nie jest DER SEQUENCE")
    idx = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)

    def read_int(i):
        assert der[i] == 0x02, "oczekiwano INTEGER"
        ln = der[i + 1]
        val = der[i + 2 : i + 2 + ln]
        return val.lstrip(b"\x00").rjust(32, b"\x00"), i + 2 + ln

    r, idx = read_int(idx)
    s, _ = read_int(idx)
    return r + s

def make_token(key_path: str, key_id: str, issuer: str) -> str:
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": issuer,
        "iat": now,
        "exp": now + 1200,          # Apple odrzuca > 20 minut
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{b64u(json.dumps(header,separators=(',',':')).encode())}." \
                    f"{b64u(json.dumps(payload,separators=(',',':')).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode(), capture_output=True, check=True).stdout
    return f"{signing_input}.{b64u(der_to_raw(der))}"

def probe(token: str):
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com/v1/apps?limit=1",
        headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = json.load(r)
            apps = [a["attributes"].get("bundleId") for a in body.get("data", [])]
            return r.status, apps, None
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            detail = json.load(e).get("errors", [{}])[0].get("code", "")
        except Exception:
            pass
        return e.code, None, detail

def main():
    if len(sys.argv) != 2:
        print(__doc__); sys.exit(2)
    issuer = sys.argv[1].strip()
    if len(issuer) != 36 or issuer.count("-") != 4:
        print(f"UWAGA: '{issuer}' nie wyglada na UUID. Issuer ID to UUID "
              f"36-znakowy z App Store Connect -> Users and Access -> Integrations.\n")

    keydir = os.path.expanduser("~/private_keys")
    keys = sorted(f for f in os.listdir(keydir) if f.startswith("AuthKey_") and f.endswith(".p8"))
    if not keys:
        print("Brak plikow AuthKey_*.p8 w ~/private_keys"); sys.exit(1)

    print(f"Issuer ID: {issuer[:8]}...{issuer[-4:]}  (dlugosc {len(issuer)})")
    print(f"Klucze do sprawdzenia: {len(keys)}\n")

    ok = []
    for fn in keys:
        key_id = fn[len("AuthKey_"):-len(".p8")]
        try:
            token = make_token(os.path.join(keydir, fn), key_id, issuer)
        except Exception as e:
            print(f"  {key_id}: NIE UDALO SIE PODPISAC ({e})"); continue
        status, apps, code = probe(token)
        if status == 200:
            ok.append(key_id)
            print(f"  {key_id}: DZIALA (200). Widoczne aplikacje: {apps}")
        else:
            print(f"  {key_id}: ODRZUCONY ({status} {code})")

    print()
    if ok:
        print(f"WNIOSEK: uzyj --apiKey {ok[0]}")
        print(f"  Issuer ID jest poprawny. Pozostale klucze sa uniewaznione")
        print(f"  albo nie naleza do tego zespolu.")
    else:
        print("WNIOSEK: zaden klucz nie przeszedl.")
        print("  Skoro oba pliki sa poprawnymi kluczami EC P-256, a zaden nie")
        print("  autoryzuje, najbardziej prawdopodobny jest ZLY ISSUER ID.")
        print("  Sprawdz: App Store Connect -> Users and Access -> Integrations")
        print("  -> App Store Connect API. Issuer ID jest na gorze strony.")
        print("  Drugi wariant: oba klucze uniewazniono - wtedy wygeneruj nowy")
        print("  (rola Admin lub App Manager) i zapisz .p8 do ~/private_keys.")

if __name__ == "__main__":
    main()

import argparse
import subprocess, os, sys
from pathlib import Path
from itertools import permutations

DEFAULT_OUTPUT_DIR = Path("artifacts/keyguesser")

def build_parser():
    parser = argparse.ArgumentParser(description="Try known key patterns against an encrypted configuration backup.")
    parser.add_argument("backup", type=Path)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--ssid-suffix", required=True)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    return parser

def decrypt_command(openssl, hex_key, source, output):
    return [openssl, "aes-128-cbc", "-d", "-pass", "pass:" + hex_key, "-md", "sha256", "-in", str(source), "-out", str(output)]

inFileName  = "BACKUP.enc"
outFileName = "decrypted.bin"
routerSerial = ""
routerSsid   = ""

keyStrings = [
    "REPLACE_WITH_KEY_CANDIDATE_1",
    "REPLACE_WITH_KEY_CANDIDATE_2",
    "REPLACE_WITH_KEY_CANDIDATE_3",
    "REPLACE_WITH_KEY_CANDIDATE_4",
    "REPLACE_WITH_KEY_CANDIDATE_5",
    "REPLACE_WITH_KEY_CANDIDATE_6",
    "REPLACE_WITH_KEY_CANDIDATE_7",
    "REPLACE_WITH_KEY_CANDIDATE_8",
    "REPLACE_WITH_KEY_CANDIDATE_9",
    "REPLACE_WITH_KEY_CANDIDATE_10",
    "REPLACE_WITH_KEY_CANDIDATE_11",
    "REPLACE_WITH_KEY_CANDIDATE_12",
    "REPLACE_WITH_KEY_CANDIDATE_13",
    "REPLACE_WITH_KEY_CANDIDATE_14",
    "REPLACE_WITH_KEY_CANDIDATE_15",
]

def classify(path):
    try:
        with open(path,'rb') as f: head = f.read(512)
    except OSError:
        return None
    if head.startswith(b'config.') or b'config.userdb' in head: return 'LUA'
    if head.startswith(b'\x1f\x8b'): return 'GZIP/tar.gz'
    if head.startswith(b'PK\x03\x04'): return 'ZIP'
    if head.startswith(b'\xfd7zXZ\x00'): return 'XZ'
    if head[257:262] == b'ustar': return 'TAR'
    return None   # padding-luck garbage -> reject

def tryDecrypt(hexKey):
    p = subprocess.run(decrypt_command("openssl", hexKey, inFileName, outFileName), capture_output=True)
    if p.returncode != 0: return None
    return classify(outFileName)

def tryKey(key):
    p = subprocess.run(["openssl","enc","-aes-128-cbc","-k",key,"-md","sha256","-P","-nosalt"],
                       capture_output=True, text=True)
    i = p.stdout.find("key=")
    if i < 0: return
    hexKey = p.stdout[i+4:].splitlines()[0].strip()
    kind = tryDecrypt(hexKey)
    if kind:
        print("REAL KEY:", hexKey, "| content type:", kind)
        open("key.txt","w").write(hexKey + "\n")
        print("key.txt written. Decrypted content:", outFileName)
        sys.exit(0)
    if os.path.exists(outFileName): os.remove(outFileName)

def main(argv=None):
    global inFileName, outFileName, routerSerial, routerSsid
    args = build_parser().parse_args(argv)
    if not args.backup.is_file():
        print("backup file does not exist", file=sys.stderr)
        return 2
    args.output_dir.mkdir(parents=True, exist_ok=True)
    inFileName = str(args.backup)
    outFileName = str(args.output_dir / "decrypted.bin")
    routerSerial, routerSsid = args.serial, args.ssid_suffix
    n = 0
    for ks in keyStrings:
        x = [routerSerial, ks, routerSsid]
        for r in range(1, 4):
            for c in permutations(x, r):
                n += 1
                if n % 25 == 0: print("...tried", n)
                tryKey("".join(c))
    print("No content-valid key found in list.")
    return 1

if __name__ == "__main__":
    raise SystemExit(main())

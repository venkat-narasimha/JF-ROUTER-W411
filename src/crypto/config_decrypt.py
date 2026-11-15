"""Decrypt a Jio ONT configuration backup into an ignored artifacts folder."""
import argparse
import subprocess
import sys
from pathlib import Path

DEFAULT_OUTPUT_DIR = Path("artifacts/config")

def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path)
    parser.add_argument("--key-file", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--openssl", default="openssl")
    return parser

def openssl_command(openssl, decrypt, key_file, source, output):
    command = [openssl, "aes-128-cbc"]
    if decrypt:
        command.append("-d")
    return command + ["-pass", f"file:{key_file}", "-md", "sha256", "-in", str(source), "-out", str(output)]

def main(argv=None):
    args = build_parser().parse_args(argv)
    if not args.backup.is_file() or not args.key_file.is_file():
        print("backup and key file must both exist", file=sys.stderr)
        return 2
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "cfg.txt"
    result = subprocess.run(openssl_command(args.openssl, True, args.key_file, args.backup, output), capture_output=True, text=True)
    if result.returncode:
        print(result.stderr.strip() or "OpenSSL failed", file=sys.stderr)
        return 1
    data = output.read_bytes()
    if not data.startswith(b"config.userdb = {}"):
        print("decrypted file is not the expected Lua configuration", file=sys.stderr)
        return 1
    print(f"Decrypted OK: {len(data)} bytes -> {output}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

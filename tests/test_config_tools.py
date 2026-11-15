import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, relative_path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class ConfigDecryptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tool = load_module("config_decrypt", "src/crypto/config_decrypt.py")

    def test_parser_defaults_output_to_artifacts_directory(self):
        args = self.tool.build_parser().parse_args(["backup.enc", "--key-file", "server.key"])
        self.assertEqual(args.output_dir, Path("artifacts/config"))

    def test_decrypt_command_uses_sha256_digest(self):
        command = self.tool.openssl_command("openssl", True, Path("server.key"), Path("backup.enc"), Path("cfg.txt"))
        self.assertIn("-md", command)
        self.assertEqual(command[command.index("-md") + 1], "sha256")


class KeyGuesserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tool = load_module("keyguesser", "src/crypto/keyguesser.py")

    def test_parser_requires_router_identity_and_defaults_to_artifacts(self):
        args = self.tool.build_parser().parse_args([
            "backup.enc", "--serial", "TESTSERIAL", "--ssid-suffix", "TestSuffix"
        ])
        self.assertEqual(args.output_dir, Path("artifacts/keyguesser"))

    def test_decrypt_command_uses_sha256_digest(self):
        command = self.tool.decrypt_command("openssl", "00" * 16, Path("backup.enc"), Path("decrypted.bin"))
        self.assertIn("-md", command)
        self.assertEqual(command[command.index("-md") + 1], "sha256")


if __name__ == "__main__":
    unittest.main()

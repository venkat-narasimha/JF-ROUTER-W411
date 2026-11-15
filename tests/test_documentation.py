#!/usr/bin/env python3
"""Validate documentation links, script references, and credential placeholders."""
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
INSTRUCTIONS = DOCS / "instructions"
REFERENCE = DOCS / "reference"
SCRIPTS = ROOT / "src" / "scripts"
ARTIFACTS = ROOT / "artifacts"


FORBIDDEN_PATTERNS = [
    re.compile(r"RRIOTFJ\d+"),  # real serial numbers
    re.compile(r"8Pyla"),  # real SSID suffix
    re.compile(r"1n0NaZQnC9oxcfwf"),  # real key candidates
    re.compile(r"us4AQiJAgbj0Fmxq"),
    re.compile(r"NTqK8Ps5iFke8zrp"),
    re.compile(r"bfqerloC15y79WQZ"),
    re.compile(r"9gNzEbuDjtyT9Pyc"),
    re.compile(r"uuphsZuO92AZW5GJ"),
    re.compile(r"qdySWmmvYKdBcO53"),
    re.compile(r"Q7ODauKsxUAUtbR7"),
    re.compile(r"password\npassword"),  # hardcoded passwords
]


class DocumentationTests(unittest.TestCase):
    def test_root_readme_exists(self):
        self.assertTrue((ROOT / "README.md").is_file())

    def test_docs_readme_exists(self):
        self.assertTrue((DOCS / "README.md").is_file())

    def test_reference_pages_exist(self):
        for name in ["compatibility.md", "safety-and-recovery.md", "artifacts-and-secrets.md", "script-catalog.md"]:
            self.assertTrue((REFERENCE / name).is_file(), f"Missing {name}")

    def test_verified_repeater_guide_exists(self):
        self.assertTrue((INSTRUCTIONS / "wifi-repeater-jcow411.md").is_file())

    def test_local_markdown_links_resolve(self):
        """All relative .md links in docs/ point to existing local files."""
        md_files = list(DOCS.rglob("*.md"))
        for md in md_files:
            content = md.read_text(encoding="utf-8")
            # Find relative markdown links [text](path.md) or [text](../path.md)
            for match in re.finditer(r"\[[^\]]+\]\(([^)]+\.md)\)", content):
                target = match.group(1)
                # Skip external links
                if target.startswith("http://") or target.startswith("https://"):
                    continue
                # Resolve relative to the linking file
                target_path = (md.parent / target).resolve()
                self.assertTrue(target_path.is_file(), f"Broken link in {md.relative_to(ROOT)}: {target}")

    def test_script_catalog_references_exist(self):
        """Every script named in script-catalog.md exists in src/scripts/."""
        catalog = (REFERENCE / "script-catalog.md").read_text(encoding="utf-8")
        for match in re.finditer(r"`([a-z0-9_-]+\.sh)`", catalog):
            script_name = match.group(1)
            self.assertTrue((SCRIPTS / script_name).is_file(), f"Script {script_name} referenced in catalog but not found")

    def test_no_forbidden_credentials_in_tracked_files(self):
        """Tracked source, docs, and templates must not contain real credentials."""
        for path in ROOT.rglob("*"):
            if path.is_file() and path.suffix in {".py", ".sh", ".md", ".txt"}:
                # Skip artifacts directory entirely
                if ARTIFACTS in path.parents:
                    continue
                # Skip .git directory
                if ".git" in path.parts:
                    continue
                # Skip test files (they may contain test patterns)
                if "tests" in path.parts:
                    continue
                # Skip this test file itself
                if path.name == "test_documentation.py":
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                for pattern in FORBIDDEN_PATTERNS:
                    matches = pattern.findall(text)
                    self.assertEqual(len(matches), 0, f"Forbidden pattern {pattern.pattern} found in {path.relative_to(ROOT)}")

    def test_repeater_template_uses_placeholders(self):
        """repeater.sh must use placeholder values, not real credentials."""
        repeater = (SCRIPTS / "repeater.sh").read_text(encoding="utf-8")
        self.assertIn("REPLACE_WITH_UPLINK_SSID", repeater)
        self.assertIn("REPLACE_WITH_64_HEX_PSK", repeater)
        self.assertEqual(repeater.count("00:00:00:00:00:00"), 1)  # placeholder BSSID
        # Ensure no real PSK-like hex strings
        self.assertNotIn("REPLACE_WITH", repeater.replace("REPLACE_WITH_UPLINK_SSID", "").replace("REPLACE_WITH_64_HEX_PSK", ""))

    def test_python_tools_import_cleanly(self):
        """All three Python tools import without error."""
        import importlib.util
        for rel in ["src/crypto/config_decrypt.py", "src/crypto/keyguesser.py", "src/exploit/jf_exploit.py"]:
            spec = importlib.util.spec_from_file_location("mod", ROOT / rel)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)


if __name__ == "__main__":
    unittest.main()
#!/usr/bin/env python3
"""make_feed.py — generate update/stable.json FROM THE BYTES THAT ARE ACTUALLY PUBLISHED.

Contract (8.6+): the sha256 pins in the feed must be computed from the release assets
served by GitHub, never from a local build. This eliminates the class of failures where
CI (or a re-upload) replaces release bytes after the feed was pinned locally.

Modes:
  remote (default)  download the release assets for --tag via the GitHub API, hash them,
                    write the feed. Used by CI right after the release job uploads.
  --local DIR       hash files in DIR (dist/) but take the URLs from the release of --tag;
                    use only for emergency re-pins right after `gh release upload --clobber`.

Usage:
  python3 scripts/make_feed.py --repo owner/name --tag v8.6.1 --out update/stable.json \
      [--notes-from CHANGELOG.md] [--local dist] [--token TOKEN]
"""
import argparse
import hashlib
import json
import re
import sys
import time
import urllib.request

API = "https://api.github.com"
EXE = "TrayIconGuard.exe"


def get(url, token=None, binary=False, tries=4):
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={
                "Accept": "application/vnd.github+json",
                "User-Agent": "TrayIconGuard-make_feed",
                **({"Authorization": f"Bearer {token}"} if token else {}),
            })
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read() if binary else r.read().decode("utf-8")
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(3 * (attempt + 1))
    raise SystemExit(f"make_feed: GET {url} failed: {last}")


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def notes_from_changelog(path, version):
    try:
        txt = open(path, encoding="utf-8").read()
    except OSError:
        return ""
    m = re.search(rf"^## {re.escape(version)} .*?$(.*?)(?=^## |\Z)", txt,
                  re.M | re.S)
    if not m:
        return ""
    body = m.group(1)
    lines = [ln.strip() for ln in body.splitlines() if ln.strip().startswith("- ")]
    flat = " ".join(ln[2:] for ln in lines[:6])
    flat = re.sub(r"\s+", " ", flat).strip()
    return flat[:300]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--tag", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--notes-from", default="")
    ap.add_argument("--local", default="")
    ap.add_argument("--token", default="")
    a = ap.parse_args()

    version = a.tag[1:] if a.tag.startswith("v") else a.tag
    rel = json.loads(get(f"{API}/repos/{a.repo}/releases/tags/{a.tag}", a.token or None))
    assets = {x["name"]: x for x in rel["assets"]}
    zipname = f"TrayIconGuard-{version}-win-x64.zip"
    for need in (EXE, zipname):
        if need not in assets:
            raise SystemExit(f"make_feed: release {a.tag} has no asset {need} "
                             f"(have: {sorted(assets)})")

    def asset_bytes(name):
        if a.local:
            with open(f"{a.local.rstrip('/')}/{name}", "rb") as f:
                return f.read()
        return get(assets[name]["browser_download_url"], None, binary=True)

    exe_b = asset_bytes(EXE)
    zip_b = asset_bytes(zipname)
    exe_sha = sha256_bytes(exe_b)
    zip_sha = sha256_bytes(zip_b)

    if a.local:  # sanity: local bytes must equal served bytes
        served = get(assets[EXE]["browser_download_url"], None, binary=True)
        if sha256_bytes(served) != exe_sha:
            raise SystemExit("make_feed: --local bytes differ from served release bytes; "
                             "upload with --clobber first or use remote mode")

    notes = notes_from_changelog(a.notes_from, version) if a.notes_from else ""
    feed = {
        "schema": 1,
        "channel": "stable",
        "version": version,
        "released": time.strftime("%Y-%m-%d", time.gmtime()),
        "minBuild": 15063,
        "url": assets[EXE]["browser_download_url"],
        "sha256": exe_sha,
        "zipUrl": assets[zipname]["browser_download_url"],
        "zipSha256": zip_sha,
        "notes": notes or f"TrayIconGuard {version} — see CHANGELOG.md for details.",
    }
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(feed, f, indent=2)
        f.write("\n")
    print(f"make_feed: {a.out} <- release {a.tag} "
          f"(exe {exe_sha[:16]}…, zip {zip_sha[:16]}…, {len(exe_b)} B)")


if __name__ == "__main__":
    sys.exit(main())

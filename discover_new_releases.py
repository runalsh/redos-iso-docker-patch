#!/usr/bin/env python3
"""
RED OS ISO Release Discoverer
Scans official RED OS mirrors for new Everything DVD ISOs and updates releases.txt.
Sets GITHUB_ENV variables for automated Pull Request creation.
"""
import urllib.request
import urllib.parse
import re
import sys
import os

URLS = [
    ("7.3", "https://repo3.red-soft.ru/redos/7.3/x86_64/iso/"),
    ("8.0", "https://repo3.red-soft.ru/redos/8.0/x86_64/iso/")
]

def fetch_iso_links(base_url):
    try:
        req = urllib.request.Request(base_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=30) as resp:
            html = resp.read().decode('utf-8', errors='ignore')
            links = re.findall(r'href=["\']([^"\']+\.iso)["\']', html)
            full_links = []
            for l in links:
                if "Everything" in l and "DVD1" in l:
                    full_url = urllib.parse.urljoin(base_url, l)
                    full_links.append((l, full_url))
            return full_links
    except Exception as e:
        print(f"Error fetching {base_url}: {e}", file=sys.stderr)
        return []

def main():
    releases_file = os.path.join(os.path.dirname(__file__), "releases.txt")
    existing_map = {}

    if os.path.exists(releases_file):
        with open(releases_file, "r") as f:
            for line in f:
                line_str = line.strip()
                if line_str and not line_str.startswith("#"):
                    parts = line_str.split(maxsplit=1)
                    if len(parts) == 2:
                        existing_map[parts[1]] = parts[0]

    all_discovered = []
    new_releases = []

    for branch, base_url in URLS:
        print(f"Scanning {branch} at {base_url}...")
        links = fetch_iso_links(base_url)
        links = sorted(links, key=lambda x: x[0])
        
        for idx, (fname, full_url) in enumerate(links):
            if full_url in existing_map:
                tag = existing_map[full_url]
            else:
                if branch == "7.3":
                    m = re.search(r'redos-MUROM-(7\.3(?:\.[0-9]+)?)', fname)
                    if m:
                        ver = m.group(1)
                        tag = ver if ver.count('.') == 2 else f"{ver}.0"
                    else:
                        tag = f"7.3.{idx}"
                else:
                    tag = f"8.0.{idx}"
                new_releases.append((tag, full_url))
            all_discovered.append((tag, full_url))

    with open(releases_file, "w") as f:
        for tag, url in all_discovered:
            f.write(f"{tag} {url}\n")

    print(f"Updated {releases_file}: total {len(all_discovered)} releases ({len(new_releases)} new).")

    github_env = os.getenv("GITHUB_ENV")
    if github_env and new_releases:
        new_tag, new_url = new_releases[-1]
        with open(github_env, "a") as f:
            f.write("NEW_RELEASE_FOUND=true\n")
            f.write(f"NEW_TAG={new_tag}\n")
            f.write(f"NEW_URL={new_url}\n")
            f.write(f"NEW_COUNT={len(new_releases)}\n")
        print(f"Exported GITHUB_ENV: NEW_TAG={new_tag}")
    elif github_env:
        with open(github_env, "a") as f:
            f.write("NEW_RELEASE_FOUND=false\n")

if __name__ == "__main__":
    main()

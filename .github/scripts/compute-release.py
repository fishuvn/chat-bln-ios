#!/usr/bin/env python3
"""
Automatic Version & Changelog Generator for Chat BLN (Web/Backend, iOS, Android).

Versioning Policy:
- Format: MAJOR.MINOR.PATCH (tag: vMAJOR.MINOR.PATCH)
- Small/Incremental changes (fix, feat, perf, refactor, etc.):
  - Increment PATCH: 1.0.0 -> 1.0.1 -> ... -> 1.0.10 (max digit is 10).
  - When PATCH reaches 10, next small change rolls to 1.(MINOR+1).0 (e.g. 1.0.10 -> 1.1.0).
  - Minor explicit marker ([minor]): increments MINOR and resets PATCH to 0 (up to MINOR = 10).
  - When MINOR == 10 and PATCH == 10 (1.10.10), next bump rolls to (MAJOR+1).0.0.
- Major changes (x.0.0 -> (MAJOR+1).0.0):
  - Triggered by breaking/architectural commits (`feat!:`, `arch!:`, `ui!:`, `BREAKING CHANGE`, `[major]`, `[breaking]`),
    explicit workflow_dispatch `bump_type=major`, OR detected OS minimum target / language toolchain upgrade
    (`minSdk` increase on Android, `IPHONEOS_DEPLOYMENT_TARGET` increase on iOS, `<java.version>` major increase).
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import os
import re
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple

MAX_SUB_VERSION = 10
VN_TZ = timezone(timedelta(hours=7))
SEMVER_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")


def run_git(args: List[str]) -> str:
    res = subprocess.run(["git", *args], capture_output=True, text=True, check=False)
    return res.stdout.strip()


def parse_version(raw: str) -> Optional[Tuple[int, int, int]]:
    m = SEMVER_RE.match(raw.strip())
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def format_version(v: Tuple[int, int, int]) -> str:
    return f"{v[0]}.{v[1]}.{v[2]}"


def compute_build_number(v: Tuple[int, int, int]) -> int:
    # Strictly monotonic integer: e.g. 1.0.1 -> 10001, 1.0.10 -> 10010, 1.1.0 -> 10100, 2.0.0 -> 20000
    return v[0] * 10000 + v[1] * 100 + v[2]


def bump_version(current: Tuple[int, int, int], bump_kind: str) -> Tuple[int, int, int]:
    major, minor, patch = current
    if bump_kind == "major":
        return (major + 1, 0, 0)
    if bump_kind == "minor":
        if minor < MAX_SUB_VERSION:
            return (major, minor + 1, 0)
        return (major + 1, 0, 0)
    # Default: patch (max 10 per slot)
    if patch < MAX_SUB_VERSION:
        return (major, minor, patch + 1)
    if minor < MAX_SUB_VERSION:
        return (major, minor + 1, 0)
    return (major + 1, 0, 0)


def get_latest_git_tag() -> Tuple[Optional[str], Optional[Tuple[int, int, int]]]:
    raw_tags = run_git(["tag", "-l", "v*"]).splitlines()
    parsed: List[Tuple[Tuple[int, int, int], str]] = []
    for t in raw_tags:
        v = parse_version(t)
        if v is not None:
            parsed.append((v, t.strip()))
    if not parsed:
        return None, None
    parsed.sort(key=lambda item: item[0])
    best_v, best_tag = parsed[-1]
    return best_tag, best_v


def detect_os_or_runtime_upgrade(prev_tag: Optional[str]) -> Optional[str]:
    if not prev_tag:
        return None
    diff_range = f"{prev_tag}..HEAD"
    watched_files = [
        "app/build.gradle.kts",
        "ChatBLN.xcodeproj/project.pbxproj",
        "backend/pom.xml",
    ]
    existing = [f for f in watched_files if Path(f).exists()]
    if not existing:
        return None
    diff_txt = run_git(["diff", diff_range, "--", *existing])
    if not diff_txt:
        return None

    def extract_old_new(pattern: str) -> Tuple[List[float], List[float]]:
        olds, news = [], []
        for line in diff_txt.splitlines():
            if line.startswith("---") or line.startswith("+++"):
                continue
            if line.startswith("-"):
                for m in re.finditer(pattern, line[1:]):
                    olds.append(float(m.group(1)))
            elif line.startswith("+"):
                for m in re.finditer(pattern, line[1:]):
                    news.append(float(m.group(1)))
        return olds, news

    old_sdk, new_sdk = extract_old_new(r"minSdk\s*=\s*(\d+)")
    if old_sdk and new_sdk and max(new_sdk) > max(old_sdk):
        return f"Nâng cấp phiên bản Android tối thiểu (`minSdk` {int(max(old_sdk))} -> {int(max(new_sdk))})"

    old_ios, new_ios = extract_old_new(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9]+(?:\.[0-9]+)?)")
    if old_ios and new_ios and max(new_ios) > max(old_ios):
        return f"Nâng cấp phiên bản iOS hỗ trợ tối thiểu ({max(old_ios)} -> {max(new_ios)})"

    old_java, new_java = extract_old_new(r"<java\.version>(\d+)</java\.version>")
    if old_java and new_java and max(new_java) > max(old_java):
        return f"Nâng cấp nền tảng Java runtime ({int(max(old_java))} -> {int(max(new_java))})"

    return None


def collect_commits(prev_tag: Optional[str]) -> List[Tuple[str, str, str]]:
    fmt = "%h%x1f%s%x1f%b%x1e"
    rev_spec = f"{prev_tag}..HEAD" if prev_tag else "-n 12"
    cmd = ["log", *rev_spec.split(), f"--pretty=format:{fmt}"]
    raw = run_git(cmd)
    commits: List[Tuple[str, str, str]] = []
    for rec in raw.split("\x1e"):
        rec = rec.strip()
        if not rec:
            continue
        parts = rec.split("\x1f")
        if len(parts) < 2:
            continue
        sha = parts[0].strip()
        subj = parts[1].strip()
        body = parts[2].strip() if len(parts) > 2 else ""
        if "[skip ci]" in subj.lower() or subj.lower().startswith("chore(release):"):
            continue
        commits.append((sha, subj, body))
    return commits


def determine_bump_kind(
    commits: List[Tuple[str, str, str]],
    forced_bump: str,
    os_upgrade_reason: Optional[str],
) -> str:
    forced = (forced_bump or "auto").strip().lower()
    if forced in ("major", "minor", "patch"):
        return forced

    if os_upgrade_reason:
        return "major"

    major_header_re = re.compile(r"^[a-zA-Z]+(\([^)]+\))?!:")
    for _, subj, body in commits:
        combined = f"{subj}\n{body}"
        lower = combined.lower()
        if (
            "breaking change" in lower
            or "[major]" in lower
            or "[breaking]" in lower
            or "[major-ui]" in lower
            or major_header_re.search(subj)
        ):
            return "major"

    for _, subj, body in commits:
        lower = f"{subj}\n{body}".lower()
        if "[minor]" in lower:
            return "minor"

    return "patch"


def clean_commit_subject(subj: str) -> str:
    cleaned = re.sub(r"\[(major|minor|patch|breaking|major-ui)\]", "", subj, flags=re.IGNORECASE).strip()
    return cleaned


def build_changelog_section(
    version_str: str,
    build_number: int,
    bump_kind: str,
    commits: List[Tuple[str, str, str]],
    os_upgrade_reason: Optional[str],
    platform_label: str,
) -> str:
    now_vn = datetime.now(VN_TZ).strftime("%Y-%m-%d %H:%M UTC+7")
    bump_labels = {
        "major": "Cập nhật lớn (`x.0.0` — Kiến trúc / Ngôn ngữ / HĐH / Đại tu UI-UX)",
        "minor": "Cập nhật nhánh tính năng (`1.x.0`, giới hạn nhánh tối đa `.10`)",
        "patch": "Bản cập nhật & sửa lỗi nhỏ (`1.x.x`, giới hạn tối đa `.10`)",
    }

    major_items: List[str] = []
    feat_items: List[str] = []
    fix_items: List[str] = []
    other_items: List[str] = []

    if os_upgrade_reason:
        major_items.append(f"- {os_upgrade_reason}")

    major_header_re = re.compile(r"^[a-zA-Z]+(\([^)]+\))?!:")
    for sha, subj, body in commits:
        display = f"- {clean_commit_subject(subj)} (`{sha}`)"
        lower = f"{subj}\n{body}".lower()
        if (
            "breaking change" in lower
            or "[major]" in lower
            or "[breaking]" in lower
            or "[major-ui]" in lower
            or major_header_re.search(subj)
        ):
            major_items.append(display)
        elif re.match(r"^feat(\([^)]+\))?:", subj, flags=re.IGNORECASE):
            feat_items.append(display)
        elif re.match(r"^fix(\([^)]+\))?:", subj, flags=re.IGNORECASE):
            fix_items.append(display)
        else:
            other_items.append(display)

    if not (major_items or feat_items or fix_items or other_items):
        other_items.append("- Đồng bộ mã nguồn và phát hành gói cài đặt tự động.")

    lines = [
        f"## v{version_str} — {platform_label} ({now_vn})",
        "",
        f"- **Phiên bản**: `v{version_str}` (Build `{build_number}`)",
        f"- **Phân loại**: {bump_labels.get(bump_kind, bump_labels['patch'])}",
        "",
    ]

    if major_items:
        lines.extend(["### 🚀 Thay đổi lớn (Cấu trúc / HĐH / UI-UX)", *major_items, ""])
    if feat_items:
        lines.extend(["### ✨ Tính năng mới", *feat_items, ""])
    if fix_items:
        lines.extend(["### 🐛 Sửa lỗi", *fix_items, ""])
    if other_items:
        lines.extend(["### 🔧 Cải tiến & Bảo trì", *other_items, ""])

    return "\n".join(lines).rstrip() + "\n"


def update_project_version_files(version_str: str, build_number: int) -> List[str]:
    touched: List[str] = []

    # 1. Root VERSION file
    Path("VERSION").write_text(f"{version_str}\n", encoding="utf-8")
    touched.append("VERSION")

    # 1b. Rust Cargo.toml & Dioxus.toml
    cargo_toml = Path("Cargo.toml")
    if cargo_toml.exists():
        txt = cargo_toml.read_text(encoding="utf-8")
        txt_new = re.sub(
            r'(?m)^(version\s*=\s*")[^"]+(")',
            rf"\g<1>{version_str}\g<2>",
            txt,
            count=1,
        )
        cargo_toml.write_text(txt_new, encoding="utf-8")
        touched.append("Cargo.toml")

    dioxus_toml = Path("Dioxus.toml")
    if dioxus_toml.exists():
        txt = dioxus_toml.read_text(encoding="utf-8")
        txt_new = re.sub(
            r'(?m)^(version\s*=\s*")[^"]+(")',
            rf"\g<1>{version_str}\g<2>",
            txt,
            count=1,
        )
        dioxus_toml.write_text(txt_new, encoding="utf-8")
        touched.append("Dioxus.toml")

    # 2. Android app/build.gradle.kts
    gradle_file = Path("app/build.gradle.kts")
    if gradle_file.exists():
        txt = gradle_file.read_text(encoding="utf-8")
        txt_new = re.sub(r'versionCode\s*=\s*\d+', f"versionCode = {build_number}", txt)
        txt_new = re.sub(r'versionName\s*=\s*"[^"]+"', f'versionName = "{version_str}"', txt_new)
        gradle_file.write_text(txt_new, encoding="utf-8")
        touched.append(str(gradle_file))

    # 3. iOS ChatBLN.xcodeproj/project.pbxproj
    pbxproj = Path("ChatBLN.xcodeproj/project.pbxproj")
    if pbxproj.exists():
        txt = pbxproj.read_text(encoding="utf-8")
        txt_new = re.sub(r"MARKETING_VERSION\s*=\s*[^;]+;", f"MARKETING_VERSION = {version_str};", txt)
        txt_new = re.sub(r"CURRENT_PROJECT_VERSION\s*=\s*[^;]+;", f"CURRENT_PROJECT_VERSION = {build_number};", txt_new)
        pbxproj.write_text(txt_new, encoding="utf-8")
        touched.append(str(pbxproj))

    # 4. Web frontend/package.json
    pkg_json = Path("frontend/package.json")
    if pkg_json.exists():
        txt = pkg_json.read_text(encoding="utf-8")
        txt_new = re.sub(
            r'("version"\s*:\s*")[^"]+(")',
            rf"\g<1>{version_str}\g<2>",
            txt,
            count=1,
        )
        pkg_json.write_text(txt_new, encoding="utf-8")
        touched.append(str(pkg_json))

    # 5. Backend backend/pom.xml (project version right after <artifactId>chat-bln</artifactId>)
    pom_xml = Path("backend/pom.xml")
    if pom_xml.exists():
        txt = pom_xml.read_text(encoding="utf-8")
        txt_new = re.sub(
            r"(<artifactId>chat-bln</artifactId>\s*<version>)[^<]+(</version>)",
            rf"\g<1>{version_str}\g<2>",
            txt,
            count=1,
        )
        pom_xml.write_text(txt_new, encoding="utf-8")
        touched.append(str(pom_xml))

    return touched


def prepend_changelog(section_md: str, platform_label: str) -> None:
    changelog_path = Path("CHANGELOG.md")
    header = (
        f"# Changelog — {platform_label}\n\n"
        "Quy ước phiên bản: `1.0.x` / `1.x.x` cho các bản cập nhật và sửa lỗi nhỏ (mỗi bậc tối đa `10`, "
        "ví dụ `1.0.10` → `1.1.0`); `x.0.0` dành cho thay đổi lớn về kiến trúc, ngôn ngữ lập trình, "
        "nâng phiên bản HĐH tối thiểu hoặc đại tu UI/UX.\n\n"
    )
    if changelog_path.exists():
        existing = changelog_path.read_text(encoding="utf-8")
        first_h2 = existing.find("\n## ")
        if first_h2 != -1:
            updated = existing[: first_h2 + 1] + section_md + "\n" + existing[first_h2 + 1 :].lstrip("\n")
        elif existing.startswith("## "):
            updated = header + section_md + "\n" + existing
        else:
            updated = existing.rstrip() + "\n\n" + section_md
    else:
        updated = header + section_md
    changelog_path.write_text(updated, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, help="Display label, e.g. 'Chat BLN Android'")
    parser.add_argument("--bump", default="auto", help="auto | patch | minor | major")
    parser.add_argument("--explicit-version", default="", help="Optional explicit X.Y.Z override")
    parser.add_argument("--release-notes-out", default="RELEASE_NOTES.md")
    parser.add_argument("--apply-files", action="store_true", help="Write VERSION, CHANGELOG.md, and project files")
    args = parser.parse_args()

    prev_tag, tag_ver = get_latest_git_tag()
    file_ver = parse_version(Path("VERSION").read_text(encoding="utf-8")) if Path("VERSION").exists() else None

    os_upgrade_reason = detect_os_or_runtime_upgrade(prev_tag)
    commits = collect_commits(prev_tag)
    bump_kind = determine_bump_kind(commits, args.bump, os_upgrade_reason)

    explicit = parse_version(args.explicit_version) if args.explicit_version.strip() else None
    if explicit is not None:
        next_ver = explicit
    elif file_ver is not None and (tag_ver is None or file_ver > tag_ver):
        # Developer explicitly raised VERSION higher than latest tag in their commit
        if prev_tag is None and file_ver == (1, 0, 0):
            # Initial baseline 1.0.0 -> bump to 1.0.1 (or 2.0.0 if major) on first automated release
            next_ver = bump_version(file_ver, bump_kind)
        else:
            next_ver = file_ver
    else:
        base_ver = tag_ver or file_ver or (1, 0, 0)
        next_ver = bump_version(base_ver, bump_kind)

    version_str = format_version(next_ver)
    build_number = compute_build_number(next_ver)
    section_md = build_changelog_section(
        version_str=version_str,
        build_number=build_number,
        bump_kind=bump_kind,
        commits=commits,
        os_upgrade_reason=os_upgrade_reason,
        platform_label=args.platform,
    )

    Path(args.release_notes_out).write_text(section_md, encoding="utf-8")
    if args.apply_files:
        update_project_version_files(version_str, build_number)
        prepend_changelog(section_md, args.platform)

    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out:
        with open(gh_out, "a", encoding="utf-8") as f:
            f.write(f"version={version_str}\n")
            f.write(f"tag=v{version_str}\n")
            f.write(f"build_number={build_number}\n")
            f.write(f"bump_kind={bump_kind}\n")

    print(f"Computed release: v{version_str} (build {build_number}, bump={bump_kind}, prev_tag={prev_tag})")


if __name__ == "__main__":
    main()

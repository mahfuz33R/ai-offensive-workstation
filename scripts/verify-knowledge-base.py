#!/usr/bin/env python3
"""Validate Hermes skill structure and exact tool-inventory coverage."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_SECTIONS = {
    "## Purpose",
    "## Appropriate use",
    "## Prerequisites",
    "## Basic command",
    "## Intermediate example",
    "## Advanced safe workflow",
    "## Output and interpretation",
    "## Common problems",
    "## Verification",
    "## Exact installed help",
    "## Authoritative source",
}


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("missing opening YAML frontmatter delimiter")
    result: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return result
        if line and not line.startswith((" ", "\t")) and ":" in line:
            key, value = line.split(":", 1)
            result[key.strip()] = value.strip().strip("'\"")
    raise ValueError("missing closing YAML frontmatter delimiter")


def inventory_rows(path: Path):
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw or raw.startswith("#"):
            continue
        parts = raw.split("\t")
        if len(parts) != 3:
            raise ValueError(f"{path}:{number}: expected three tab-separated fields")
        yield tuple(parts)


def local_links(path: Path):
    content = path.read_text(encoding="utf-8")
    for match in re.finditer(r"\[[^]]*\]\(([^)]+)\)", content):
        target = match.group(1).strip().split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        yield target


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    image_inventory = Path("/opt/security-manifest/tool-inventory.tsv")
    image_skill = Path("/opt/hermes/skills/cybersecurity/offensive-workstation")
    active_skill = Path("/opt/data/skills/cybersecurity/offensive-workstation")
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--inventory",
        type=Path,
        default=image_inventory if image_inventory.is_file() else root / "scripts/tool-inventory.tsv",
    )
    parser.add_argument(
        "--skill-dir",
        type=Path,
        default=(
            active_skill
            if active_skill.is_dir()
            else image_skill
            if image_skill.is_dir()
            else root / "Rules/offensive-workstation-pentesting"
        ),
    )
    parser.add_argument("--require-help", action="store_true")
    args = parser.parse_args()

    errors: list[str] = []
    skill_dir = args.skill_dir.resolve()
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        errors.append(f"missing {skill_md}")
    else:
        try:
            meta = frontmatter(skill_md)
            if meta.get("name") != "offensive-workstation-pentesting":
                errors.append("SKILL.md name must be offensive-workstation-pentesting")
            for key in ("description",):
                if not meta.get(key):
                    errors.append(f"SKILL.md is missing {key}")
        except ValueError as exc:
            errors.append(f"{skill_md}: {exc}")

    primary = []
    aliases = []
    for kind, name, check in inventory_rows(args.inventory):
        if kind == "command" and name.startswith("legacy-"):
            aliases.append((name, check))
        elif kind == "command":
            primary.append((name, check))

    guide_commands: dict[str, Path] = {}
    guide_paths: set[Path] = set()
    for name, command in primary:
        guide_path = skill_dir / "references/tools" / f"{slug(name)}.md"
        guide_paths.add(guide_path.resolve())
        if not guide_path.is_file():
            errors.append(f"missing guide for {name}: {guide_path}")
            continue
        content = guide_path.read_text(encoding="utf-8")
        try:
            meta = frontmatter(guide_path)
        except ValueError as exc:
            errors.append(f"{guide_path}: {exc}")
            continue
        if meta.get("tool") != name:
            errors.append(f"{guide_path}: tool frontmatter does not match {name}")
        if meta.get("command") != command:
            errors.append(f"{guide_path}: command must be {command}")
        source = meta.get("source", "")
        if not source.startswith("https://"):
            errors.append(f"{guide_path}: source must be an HTTPS upstream URL")
        if command in guide_commands:
            errors.append(f"duplicate command guide {command}: {guide_commands[command]} and {guide_path}")
        guide_commands[command] = guide_path
        missing_sections = sorted(section for section in REQUIRED_SECTIONS if section not in content)
        if missing_sections:
            errors.append(f"{guide_path}: missing sections {', '.join(missing_sections)}")

    actual_guides = {path.resolve() for path in (skill_dir / "references/tools").glob("*.md")}
    for unexpected in sorted(actual_guides - guide_paths):
        errors.append(f"guide is not represented by a primary inventory command: {unexpected}")

    catalog = skill_dir / "help-commands.tsv"
    catalog_names: set[str] = set()
    if not catalog.is_file():
        errors.append(f"missing {catalog}")
    else:
        for number, raw in enumerate(catalog.read_text(encoding="utf-8").splitlines(), 1):
            if not raw or raw.startswith("#"):
                continue
            parts = raw.split("\t")
            if len(parts) != 3 or not all(parts):
                errors.append(f"{catalog}:{number}: expected tool, command, and help arguments")
                continue
            name, command, _ = parts
            if name in catalog_names:
                errors.append(f"{catalog}:{number}: duplicate tool {name}")
            catalog_names.add(name)
            expected = dict(primary).get(name)
            if expected != command:
                errors.append(f"{catalog}:{number}: {name} command must be {expected}")
    missing_catalog = sorted(set(dict(primary)) - catalog_names)
    extra_catalog = sorted(catalog_names - set(dict(primary)))
    if missing_catalog:
        errors.append(f"help catalog missing: {', '.join(missing_catalog)}")
    if extra_catalog:
        errors.append(f"help catalog has non-primary tools: {', '.join(extra_catalog)}")

    for required in (
        "references/TOOL-INDEX.md",
        "references/ASSETS.md",
        "references/SAFETY.md",
        "references/TROUBLESHOOTING.md",
    ):
        if not (skill_dir / required).is_file():
            errors.append(f"missing {skill_dir / required}")
    if "cyberstrike" in dict(primary):
        cyberstrike_files = (
            "INDEX.md",
            "LOCAL-RAG.md",
            "QUICKSTART.md",
            "CLI.md",
            "CONFIGURATION.md",
            "AGENTS.md",
            "HACKBROWSER.md",
            "MCP-BOLT.md",
            "HERMES-AUTOMATION.md",
            "SOURCE-NOTES.md",
            "UPSTREAM-INDEX.md",
        )
        for filename in cyberstrike_files:
            required_path = skill_dir / "references/cyberstrike" / filename
            if not required_path.is_file():
                errors.append(f"missing CyberStrike RAG reference: {required_path}")
        if skill_md.is_file() and "references/cyberstrike/INDEX.md" not in skill_md.read_text(encoding="utf-8"):
            errors.append("SKILL.md does not route CyberStrike tasks to references/cyberstrike/INDEX.md")
        source_library = skill_dir / "references/cyberstrike/source-library"
        source_files = [path for path in source_library.rglob("*") if path.is_file()]
        if len(source_files) < 71:
            errors.append(
                f"CyberStrike source library is incomplete: expected at least 71 files, found {len(source_files)}"
            )
        if skill_md.is_file():
            skill_content = skill_md.read_text(encoding="utf-8")
            if "whenever the user mentions CyberStrike" not in skill_content:
                errors.append("SKILL.md description does not explicitly trigger on CyberStrike requests")
            if "without invoking `cyberstrike run`" not in skill_content:
                errors.append("SKILL.md does not route informational CyberStrike questions to local RAG")
    workflows = list((skill_dir / "references/workflows").glob("*.md"))
    if len(workflows) < 10:
        errors.append("at least ten focused workflow references are required")

    for markdown in skill_dir.rglob("*.md"):
        if "references/cli-help" in markdown.as_posix():
            continue
        if "references/cyberstrike/source-library" in markdown.as_posix():
            continue
        for target in local_links(markdown):
            resolved = (markdown.parent / target).resolve()
            if "references/cli-help/" in str(resolved) and not args.require_help:
                continue
            if not resolved.is_file():
                errors.append(f"{markdown}: broken local link {target}")

    if args.require_help:
        for name, _ in primary:
            help_path = skill_dir / "references/cli-help" / f"{slug(name)}.md"
            if not help_path.is_file() or help_path.stat().st_size < 80:
                errors.append(f"missing or empty installed-help snapshot for {name}: {help_path}")

    credential_pattern = re.compile(
        r"(?i)(api[_-]?key|access[_-]?token|client[_-]?secret)\s*[:=]\s*['\"]?[A-Za-z0-9_./+-]{16,}"
    )
    for path in skill_dir.rglob("*"):
        if path.is_file() and path.suffix in {".md", ".tsv"}:
            if "references/cyberstrike/source-library" in path.as_posix():
                # This is an unchanged public documentation export containing
                # visibly truncated example key prefixes, not configured
                # credentials. Public/build secret scanning still runs
                # independently in preflight.
                continue
            match = credential_pattern.search(path.read_text(encoding="utf-8", errors="replace"))
            if match and "$" not in match.group(0) and "PLACEHOLDER" not in match.group(0):
                errors.append(f"credential-like value found in {path}")

    if errors:
        for error in errors:
            print(f"[FAIL] {error}", file=sys.stderr)
        print(f"Knowledge verification failed: {len(errors)} problem(s).", file=sys.stderr)
        return 1
    print(
        f"Knowledge verification passed: {len(primary)} primary guides, "
        f"{len(aliases)} compatibility aliases, {len(workflows)} workflows."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

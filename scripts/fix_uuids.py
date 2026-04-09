#!/usr/bin/env python3
"""
fix_uuids.py — Wolfmed UUID validator and fixer.

Usage:
    python fix_uuids.py <json_file> [--db <wolfmed_db_path>] [--dry-run]

What it does:
    1. Scans every 'id' field in the JSON array for valid UUID v4 format.
       Valid UUID v4: 8-4-4-4-12 hex characters (0-9, a-f only), lowercase.
    2. Replaces each invalid ID with a freshly generated uuid4().
    3. Updates the JSON file in-place (atomic write via temp file).
    4. Updates wolfmed.db uuid_registry: swaps the old bad UUID for the new one.
    5. Writes a repair log to the same directory as the JSON file.

UUID v4 rule (strict):
    - Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    - Characters: ONLY 0-9 and a-f (hex). Letters g-z are INVALID.
    - Length: 8-4-4-4-12 (32 hex digits + 4 dashes = 36 chars total)
    - Version nibble (position 14): must be '4'
    - Variant nibble (position 19): must be 8, 9, a, or b

Defaults:
    - db path: <json_file_dir>/../data/wolfmed.db
    - dry-run: False (changes are written)
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import uuid
from datetime import datetime
from pathlib import Path


# Strict UUID v4: hex-only, version nibble = 4, variant nibble in [89ab]
UUID_V4_STRICT = re.compile(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
)
# Loose UUID: correct shape but may have invalid chars or wrong version
UUID_LOOSE = re.compile(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
)


def is_valid_uuid(value: str) -> bool:
    """Return True only if value is a properly formatted UUID v4 (hex-only)."""
    if not isinstance(value, str):
        return False
    return bool(UUID_V4_STRICT.match(value.lower()))


def is_valid_uuid_loose(value: str) -> bool:
    """Return True if value has UUID shape with hex-only chars (any version)."""
    if not isinstance(value, str):
        return False
    return bool(UUID_LOOSE.match(value.lower()))


def new_uuid() -> str:
    return str(uuid.uuid4())


def fix_json(data: list, dry_run: bool, strict: bool = True) -> tuple[list, list]:
    """
    Scan data for invalid UUIDs in 'id' field.
    Returns (updated_data, repairs) where repairs is list of (old_id, new_id).

    strict=True (default): fixes non-hex chars AND wrong version/variant nibbles.
    strict=False: fixes only non-hex chars (shape-only check).
    """
    check = is_valid_uuid if strict else is_valid_uuid_loose
    repairs = []
    for item in data:
        old_id = item.get('id', '')
        if not check(old_id):
            replacement = new_uuid()
            repairs.append((old_id, replacement))
            if not dry_run:
                item['id'] = replacement
    return data, repairs


def fix_db(db_path: Path, repairs: list, dry_run: bool) -> list:
    """
    For each (old_id, new_id) in repairs, update uuid_registry in wolfmed.db.
    Returns list of (old_id, new_id, status) tuples.

    NOTE: wolfmed.db lives on a Windows NTFS mount. If conn.commit() throws a
    disk I/O error (common on mounted filesystems), the function falls back to
    writing a SQL patch file next to wolfmed.db. Run the patch from Windows:
        python apply_uuid_patch.py wolfmed.db uuid_patch_TIMESTAMP.sql
    """
    results = []
    if not db_path.exists():
        print(f"[WARN] wolfmed.db not found at {db_path} — skipping DB update.")
        return [(old, new, 'db_not_found') for old, new in repairs]

    if dry_run:
        # In dry-run mode just report what would happen, no writes
        for old_id, new_id in repairs:
            results.append((old_id, new_id, 'dry_run'))
        return results

    # Build SQL patch first so we always have a fallback
    patch_path = _write_sql_patch(db_path, repairs)
    print(f"[INFO] SQL patch written: {patch_path}")
    print(f"       Run from Windows if direct DB update fails:")
    print(f"       python extractor/scripts/apply_uuid_patch.py \"{db_path}\" \"{patch_path}\"")

    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()

        for old_id, new_id in repairs:
            cur.execute("SELECT uuid FROM uuid_registry WHERE uuid = ?", (old_id,))
            row = cur.fetchone()
            if row:
                cur.execute(
                    "UPDATE uuid_registry SET uuid = ? WHERE uuid = ?",
                    (new_id, old_id)
                )
                results.append((old_id, new_id, 'updated'))
            else:
                cur.execute(
                    "INSERT INTO uuid_registry (uuid, category, question_hash, registered_at) "
                    "VALUES (?, ?, ?, ?)",
                    (new_id, 'unknown', 'repaired', datetime.now().isoformat())
                )
                results.append((old_id, new_id, 'inserted_new'))

        conn.commit()
        conn.close()
        print(f"[OK] wolfmed.db updated directly.")

    except sqlite3.OperationalError as e:
        print(f"[WARN] Direct DB update failed ({e}).")
        print(f"[WARN] Apply the SQL patch manually from Windows (path above).")
        for i, (old_id, new_id) in enumerate(repairs):
            if i < len(results):
                continue  # already recorded
            results.append((old_id, new_id, 'patch_required'))

    return results


def _write_sql_patch(db_path: Path, repairs: list) -> Path:
    """Write a .sql file with UPDATE/INSERT statements for wolfmed.db."""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    patch_path = db_path.parent / f'uuid_patch_{timestamp}.sql'
    lines = [
        f"-- UUID repair patch generated {datetime.now().isoformat()}",
        f"-- Apply with: sqlite3 wolfmed.db < {patch_path.name}",
        f"-- Or run:     python extractor/scripts/apply_uuid_patch.py wolfmed.db {patch_path.name}",
        "",
        "BEGIN TRANSACTION;",
        "",
    ]
    for old_id, new_id in repairs:
        lines.append(f"-- {old_id} -> {new_id}")
        lines.append(f"UPDATE uuid_registry SET uuid = '{new_id}' WHERE uuid = '{old_id}';")
        lines.append("")
    lines += ["COMMIT;", ""]
    patch_path.write_text('\n'.join(lines), encoding='utf-8')
    return patch_path


def write_repair_log(log_path: Path, json_file: Path, db_path: Path,
                     repairs: list, db_results: list, dry_run: bool):
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    lines = [
        f"# UUID Repair Log",
        f"Generated: {now}",
        f"File:      {json_file}",
        f"DB:        {db_path}",
        f"Dry run:   {dry_run}",
        f"Repairs:   {len(repairs)}",
        "",
        "## ID Replacements",
    ]
    for i, (old_id, new_id) in enumerate(repairs):
        db_status = db_results[i][2] if i < len(db_results) else 'unknown'
        lines.append(f"  [{i+1}] {old_id}")
        lines.append(f"       -> {new_id}  (db: {db_status})")
    lines.append("")
    log_path.write_text('\n'.join(lines), encoding='utf-8')
    print(f"[LOG] Repair log written: {log_path}")


def main():
    parser = argparse.ArgumentParser(description='Wolfmed UUID fixer')
    parser.add_argument('json_file', help='Path to the merged JSON file')
    parser.add_argument('--db', help='Path to wolfmed.db (default: auto-detect)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Report issues without writing any changes')
    parser.add_argument('--loose', action='store_true',
                        help='Only fix non-hex characters; allow wrong version/variant nibbles')
    args = parser.parse_args()

    json_path = Path(args.json_file).resolve()
    if not json_path.exists():
        print(f"[ERROR] File not found: {json_path}")
        sys.exit(1)

    # Auto-detect DB path
    if args.db:
        db_path = Path(args.db).resolve()
    else:
        db_path = json_path.parent.parent / 'data' / 'wolfmed.db'

    dry_run = args.dry_run
    if dry_run:
        print("[DRY RUN] No files will be modified.")

    # Load JSON
    print(f"[INFO] Loading: {json_path}")
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if not isinstance(data, list):
        print("[ERROR] Expected a JSON array at root level.")
        sys.exit(1)

    print(f"[INFO] Total records: {len(data)}")

    # Find and fix bad UUIDs
    strict = not args.loose
    data, repairs = fix_json(data, dry_run, strict=strict)

    if not repairs:
        print("[OK] All UUIDs are valid. Nothing to fix.")
        sys.exit(0)

    print(f"[WARN] Found {len(repairs)} invalid UUID(s):")
    for old_id, new_id in repairs:
        print(f"  BAD : {old_id}")
        print(f"  NEW : {new_id}")

    # Update wolfmed.db
    db_results = fix_db(db_path, repairs, dry_run)

    if not dry_run:
        # Atomic write: temp file then replace
        tmp_path = json_path.with_suffix('.tmp')
        with open(tmp_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        tmp_path.replace(json_path)
        print(f"[OK] JSON updated: {json_path}")

    # Write repair log next to JSON
    log_path = json_path.parent / (json_path.stem + '_uuid_repair_log.txt')
    write_repair_log(log_path, json_path, db_path, repairs, db_results, dry_run)

    print(f"[DONE] {len(repairs)} UUID(s) {'would be' if dry_run else 'were'} fixed.")


if __name__ == '__main__':
    main()

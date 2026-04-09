#!/usr/bin/env python3
"""
apply_uuid_patch.py — Apply a UUID SQL patch to wolfmed.db from Windows.

Usage (run from Windows PowerShell):
    python extractor/scripts/apply_uuid_patch.py <wolfmed_db> <patch_sql_file>

Example:
    python extractor/scripts/apply_uuid_patch.py extractor/data/wolfmed.db extractor/data/uuid_patch_20260409_120000.sql
"""

import sqlite3
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print("Usage: apply_uuid_patch.py <wolfmed_db> <patch_sql>")
        sys.exit(1)

    db_path = Path(sys.argv[1])
    sql_path = Path(sys.argv[2])

    if not db_path.exists():
        print(f"[ERROR] DB not found: {db_path}")
        sys.exit(1)

    if not sql_path.exists():
        print(f"[ERROR] SQL patch not found: {sql_path}")
        sys.exit(1)

    sql = sql_path.read_text(encoding='utf-8')

    conn = sqlite3.connect(str(db_path))
    try:
        conn.executescript(sql)
        conn.commit()
        print(f"[OK] Patch applied successfully to {db_path}")
    except sqlite3.Error as e:
        print(f"[ERROR] Patch failed: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        conn.close()


if __name__ == '__main__':
    main()

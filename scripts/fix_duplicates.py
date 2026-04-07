#!/usr/bin/env python3
import json
import uuid
import sys
from pathlib import Path

def fix_duplicate_ids(input_file, output_file=None):
    # Default output file
    if output_file is None:
        input_path = Path(input_file)
        output_file = str(input_path.with_name(f"{input_path.stem}_fixed{input_path.suffix}"))
    
    print("=" * 40)
    print("Fixing IDs")
    print("=" * 40)
    print(f"Input:  {input_file}")
    print(f"Output: {output_file}")
    print()
    
    # Read JSON
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    total_records = len(data)
    print(f"Total records: {total_records}")
    print()
    
    # Track seen IDs and counts
    seen_ids = {}
    duplicates_fixed = 0
    invalid_fixed = 0

    # Process each record
    for i, record in enumerate(data):
        record_id = record.get('id')
        is_valid = True

        # Validate UUID format
        try:
            uuid.UUID(record_id)
        except (ValueError, AttributeError, TypeError):
            # Invalid UUID - generate new one
            is_valid = False
            new_id = str(uuid.uuid4())
            invalid_fixed += 1
            if invalid_fixed <= 5:
                print(f"  Invalid UUID: {record_id} -> {new_id}")
            record['id'] = new_id
            record_id = new_id

        # Check for duplicates
        if record_id in seen_ids:
            # Duplicate found - generate new UUID
            new_id = str(uuid.uuid4())
            record['id'] = new_id
            duplicates_fixed += 1
            if duplicates_fixed <= 5:
                print(f"  Duplicate: {record_id} -> {new_id}")
        else:
            # First occurrence - track it
            seen_ids[record_id] = True

    print()
    print(f"Invalid UUIDs fixed: {invalid_fixed}")
    print(f"Duplicates fixed: {duplicates_fixed}")
    print()
    
    # Write output
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    # Verify
    unique_ids = len(set(r['id'] for r in data))
    
    print("=" * 40)
    print("Results:")
    print("=" * 40)
    print(f"Total records:     {total_records}")
    print(f"Unique IDs after:  {unique_ids}")
    print()
    
    if unique_ids == total_records:
        print("SUCCESS - All IDs valid and unique")
    else:
        print("Warning: Still have duplicates")
        return 1
    
    print()
    print(f"Saved: {output_file}")
    print("=" * 40)
    return 0

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python fix_duplicates.py <input.json> [output.json]")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    exit_code = fix_duplicate_ids(input_file, output_file)
    sys.exit(exit_code)

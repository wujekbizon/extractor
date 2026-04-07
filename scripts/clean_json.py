"""
JSON Cleaner & Global Deduping Tool
---------------------------
Purpose:
1. Removes duplicate questions within the current file (case-insensitive, whitespace ignored).
2. Fixes duplicate IDs (generates a new UUID if an ID is already taken).
3. Validates UUID format (generates a fresh UUID if current ID is malformed).
4. **Global Tracking**: Maintains a persistent registry file (uuid_registry.json) 
   to ensure IDs are unique across ALL processed files in the project.

Usage: python clean_json.py <input.json> <output.json>
"""

import json
import uuid
import sys
import os

# Registry file location - stores all IDs used across the project
REGISTRY_PATH = r'c:\extractor\data\uuid_registry.json'

def load_registry():
    """Loads the global UUID registry. Returns a set of UUID strings."""
    if not os.path.exists(REGISTRY_PATH):
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(REGISTRY_PATH), exist_ok=True)
        return set()
    
    try:
        with open(REGISTRY_PATH, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return set(data)
    except (json.JSONDecodeError, IOError):
        return set()

def save_registry(registry_set):
    """Saves the updated global UUID registry."""
    with open(REGISTRY_PATH, 'w', encoding='utf-8') as f:
        json.dump(list(registry_set), f, indent=4)

def clean_json(input_path, output_path):
    if not os.path.exists(input_path):
        print(f"Error: File {input_path} not found.")
        return

    # 1. Load Data and Global Registry
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    global_registry = load_registry()
    
    seen_local_ids = set()
    seen_questions = set()
    unique_data = []

    dup_questions = 0
    dup_ids_local = 0
    dup_ids_global = 0
    invalid_uuids = 0

    for item in data:
        # 2. Normalize Question for comparison
        raw_question = item.get('data', {}).get('question', '')
        question_norm = raw_question.strip().lower()
        
        # Skip if question is already in THIS file
        if question_norm in seen_questions:
            dup_questions += 1
            continue
        
        # 3. Handle ID Validation & Uniqueness
        item_id = item.get('id')
        needs_new_id = False
        
        # Check Format
        try:
            uuid.UUID(str(item_id))
        except (ValueError, AttributeError, TypeError):
            invalid_uuids += 1
            needs_new_id = True

        # Check for Local Collision (within this file)
        if not needs_new_id and item_id in seen_local_ids:
            dup_ids_local += 1
            needs_new_id = True
            
        # Check for Global Collision (against registry)
        if not needs_new_id and item_id in global_registry:
            dup_ids_global += 1
            needs_new_id = True

        # Generate new ID if any check failed
        if needs_new_id:
            new_id = str(uuid.uuid4())
            # Ensure the new ID itself isn't somehow already in the registry (paranoia)
            while new_id in global_registry or new_id in seen_local_ids:
                new_id = str(uuid.uuid4())
            item['id'] = new_id
            item_id = new_id

        # 4. Success - Track and Store
        seen_questions.add(question_norm)
        seen_local_ids.add(item_id)
        global_registry.add(item_id)
        unique_data.append(item)

    # 5. Save Results
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(unique_data, f, ensure_ascii=False, indent=4)
    
    save_registry(global_registry)

    print(f"\n--- Clean Up Summary ---")
    print(f"File processed:          {os.path.basename(input_path)}")
    print(f"Total items in file:     {len(data)}")
    print(f"Duplicate questions:     {dup_questions}")
    print(f"Invalid UUIDs fixed:     {invalid_uuids}")
    print(f"Local ID collisions:     {dup_ids_local}")
    print(f"Global ID collisions:    {dup_ids_global}")
    print(f"Unique items saved:      {len(unique_data)}")
    print(f"Global Registry size:    {len(global_registry)}")
    print(f"------------------------\n")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python clean_json.py <input_file> <output_file>")
    else:
        clean_json(sys.argv[1], sys.argv[2])

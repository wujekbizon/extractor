import json
import os
import uuid
from datetime import datetime

def fix_json_format(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        fixed_data = []
        now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
        
        for item in data:
            # Generate valid UUID v4 if current one is invalid
            current_id = item.get('id', '')
            try:
                # Check if it's a valid UUID
                uuid.UUID(current_id, version=4)
                new_id = current_id
            except ValueError:
                new_id = str(uuid.uuid4())
            
            # Extract category
            category = item.get('category', '')
            if not category and 'meta' in item:
                category = item['meta'].get('category', '')
            
            # Build new structure
            new_item = {
                "id": new_id,
                "meta": {
                    "course": "pielegniarstwo",
                    "category": category
                },
                "data": item.get('data', {}),
                "createdAt": item.get('createdAt', now_str),
                "updatedAt": item.get('updatedAt', None)
            }
            
            # Ensure createdAt has 6 digits for micros if it was already there but short
            if '.' in new_item['createdAt']:
                base, micro = new_item['createdAt'].split('.')
                new_item['createdAt'] = f"{base}.{micro.ljust(6, '0')[:6]}"
            else:
                new_item['createdAt'] = f"{new_item['createdAt']}.000000"

            fixed_data.append(new_item)
            
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(fixed_data, f, ensure_ascii=False, indent=2)
        print(f"Fixed {file_path}")
    except Exception as e:
        print(f"Error fixing {file_path}: {e}")

outputs_dir = 'outputs'
for filename in os.listdir(outputs_dir):
    if filename.endswith('.json'):
        fix_json_format(os.path.join(outputs_dir, filename))

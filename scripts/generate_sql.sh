#!/bin/bash

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <json_file>"
    exit 1
fi

JSON_FILE="$1"

# Check if file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: File '$JSON_FILE' not found"
    exit 1
fi

# Output file
OUTPUT_FILE="insert_queries.sql"

# Clear output file if it exists
> "$OUTPUT_FILE"

# Add header comment
echo "-- Generated SQL INSERT statements from $JSON_FILE" >> "$OUTPUT_FILE"
echo "-- Generated at: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Parse JSON and generate INSERT statements
jq -r '.[] | 
"INSERT INTO wolfmed_tests (id, category, data, \"createdAt\", \"updatedAt\") VALUES (\n" +
"    '\''" + .id + "'\'',\n" +
"    '\''" + .category + "'\'',\n" +
"    $$" + (.data | @json) + "$$::jsonb,\n" +
"    '\''" + .createdAt + "'\''::timestamp,\n" +
"    NOW()\n" +
");"
' "$JSON_FILE" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "-- Total records: $(jq 'length' "$JSON_FILE")" >> "$OUTPUT_FILE"

echo "SQL queries generated successfully in $OUTPUT_FILE"
echo "Total records: $(jq 'length' "$JSON_FILE")"
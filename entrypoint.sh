#!/bin/bash

set -e

METADATA_ENV_FILE_CONTENT="${METADATA_ENV_FILE_CONTENT:-}"

if [ -z "$METADATA_ENV_FILE_CONTENT" ]; then
  echo "METADATA_ENV_FILE_CONTENT is not set"
  exec bash
fi

# Try to parse as JSON
TYPE=$(echo "$METADATA_ENV_FILE_CONTENT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(list(d.keys())[0])" 2>/dev/null || echo "")

if [ "$TYPE" = "s3" ]; then
  URL=$(echo "$METADATA_ENV_FILE_CONTENT" | python3 -c "import sys, json; print(json.load(sys.stdin)['s3'])")
  exec fmcp run "$URL" --s3 && exec bash
elif [ "$TYPE" = "file" ]; then
  VALUE=$(echo "$METADATA_ENV_FILE_CONTENT" | python3 -c "import sys, json; v=json.load(sys.stdin)['file']; import json; print(json.dumps(v))")
  # Check if VALUE is a string (file path) or dict (JSON)
  if echo "$VALUE" | python3 -c "import sys, json; v=json.load(sys.stdin); assert isinstance(v, str)" 2>/dev/null; then
    FILE_PATH=$(echo "$VALUE" | python3 -c "import sys, json; print(json.load(sys.stdin))")
    # Replace anything up to and including /fluidmcp with /app
    FILE_PATH=$(echo "$FILE_PATH" | sed -E 's|^.*/fluidmcp|/app|')
    DEST_PATH="/app/metadata_env_file.json"
    if [ -f "$FILE_PATH" ]; then
      cp "$FILE_PATH" "$DEST_PATH"
    else
      echo "File $FILE_PATH not found"
      exec bash
    fi
    exec fmcp run "$DEST_PATH" --file && exec bash
  else
    # It's a dict, write to file
    DEST_PATH="/app/metadata_env_file.json"
    echo "$VALUE" | python3 -c "import sys, json; json.dump(json.loads(sys.stdin.read()), open('$DEST_PATH', 'w'))"
    exec fmcp run "$DEST_PATH" --file && exec bash
  fi
else
  echo "Invalid METADATA_ENV_FILE_CONTENT format"
  exec bash
fi

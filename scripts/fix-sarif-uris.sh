#!/bin/bash
# Fix SARIF URI schemes to be compatible with GitHub Code Scanning
# Converts git:// URIs to file:// URIs

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <sarif-file> [<sarif-file> ...]"
    echo "Fixes URI schemes in SARIF files from git:// to file://"
    exit 1
fi

for SARIF_FILE in "$@"; do
    if [ ! -f "$SARIF_FILE" ]; then
        echo "⚠️  File not found: $SARIF_FILE"
        continue
    fi

    echo "🔧 Fixing URI schemes in $SARIF_FILE..."

    # Create backup
    cp "$SARIF_FILE" "${SARIF_FILE}.bak"

    # Replace git:// with file:// in URIs
    # This handles both artifactLocation.uri and physicalLocation.artifactLocation.uri
    jq '
        walk(
            if type == "object" and has("uri") then
                .uri |= gsub("^git://"; "file://")
            else
                .
            end
        )
    ' "${SARIF_FILE}.bak" > "$SARIF_FILE"

    # Verify the file is still valid JSON
    if jq empty "$SARIF_FILE" 2>/dev/null; then
        echo "✅ Fixed: $SARIF_FILE"
        rm "${SARIF_FILE}.bak"
    else
        echo "❌ Error: Invalid JSON after transformation, restoring backup"
        mv "${SARIF_FILE}.bak" "$SARIF_FILE"
        exit 1
    fi
done

echo ""
echo "✅ All SARIF files processed successfully"

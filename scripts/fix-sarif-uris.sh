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

    # Check for git:// URIs before fixing
    GIT_URIS=$(jq -r '.. | objects | select(has("uri")) | .uri | select(startswith("git://") or contains("git://"))' "$SARIF_FILE" 2>/dev/null | head -5)
    if [ -n "$GIT_URIS" ]; then
        echo "   Found git:// URIs to fix:"
        echo "$GIT_URIS" | sed 's/^/     /'
    else
        echo "   No git:// URIs found (file may already be fixed)"
    fi

    # Create backup
    cp "$SARIF_FILE" "${SARIF_FILE}.bak"

    # Replace git:// with file:// in URIs
    # This handles artifactLocation.uri, physicalLocation.artifactLocation.uri, and any other URI fields
    # Strategy:
    # 1. If URI starts with git://, replace with file://
    # 2. If URI contains git:// anywhere, replace ALL occurrences with file://
    # 3. Also handle git: scheme without // (some tools use this)
    jq '
        walk(
            if type == "object" and has("uri") then
                if .uri | type == "string" then
                    .uri |= (
                        # Replace git:// with file://
                        gsub("git://"; "file://") |
                        # Also handle git: without // (less common but seen in some tools)
                        gsub("^git:"; "file://") |
                        # Remove any duplicate file:// that might result
                        gsub("file://file://"; "file://")
                    )
                else
                    .
                end
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

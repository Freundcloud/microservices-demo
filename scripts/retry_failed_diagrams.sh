#!/bin/bash

###############################################################################
# Retry rendering failed diagrams using alternative method
###############################################################################

set -euo pipefail

DOCS_DIR="/home/olafkfreund/Source/Calitti/ARC/microservices-demo/docs"
DIAGRAMS_DIR="$DOCS_DIR/diagrams"
TEMP_DIR=$(mktemp -d)

echo "Retrying failed diagrams (5, 6, 8)..."
echo ""

# Extract specific diagrams from markdown
python3 - <<'PYTHON_SCRIPT'
import re
from pathlib import Path

docs_dir = Path("/home/olafkfreund/Source/Calitti/ARC/microservices-demo/docs")
md_file = docs_dir / "GITHUB-SERVICENOW-DATA-Integration-in-ARC.md"

with open(md_file, 'r') as f:
    content = f.read()

# Extract all mermaid diagrams
pattern = r'```mermaid\n(.*?)```'
diagrams = re.findall(pattern, content, re.DOTALL)

# Save specific diagrams
for num in [5, 6, 8]:
    if num <= len(diagrams):
        with open(f'/tmp/diagram-{num}.mmd', 'w') as f:
            f.write(diagrams[num-1])
        print(f"Extracted diagram {num}")
PYTHON_SCRIPT

echo ""
echo "Attempting to render with mermaid-cli (mmdc)..."
echo ""

# Try with mmdc if available
if command -v mmdc &> /dev/null; then
    for num in 5 6 8; do
        if [ -f "/tmp/diagram-${num}.mmd" ]; then
            echo "Rendering diagram $num with mmdc..."
            if mmdc -i "/tmp/diagram-${num}.mmd" -o "$DIAGRAMS_DIR/diagram-${num}.png" -b transparent 2>/dev/null; then
                echo "  ✓ Success"
            else
                echo "  ✗ Failed"
            fi
        fi
    done
else
    echo "mmdc not available, trying alternative API..."

    # Try alternative mermaid rendering service
    for num in 5 6 8; do
        if [ -f "/tmp/diagram-${num}.mmd" ]; then
            echo "Rendering diagram $num via alternative API..."

            # Read diagram content
            DIAGRAM=$(cat "/tmp/diagram-${num}.mmd")

            # Encode for URL (simple base64)
            ENCODED=$(echo "$DIAGRAM" | base64 -w 0)

            # Try kroki.io service as alternative
            curl -s -X POST "https://kroki.io/mermaid/png" \
                -H "Content-Type: text/plain" \
                --data "$DIAGRAM" \
                -o "$DIAGRAMS_DIR/diagram-${num}.png" 2>/dev/null && \
                echo "  ✓ Success" || echo "  ✗ Failed"

            sleep 2  # Rate limit
        fi
    done
fi

# Cleanup
rm -f /tmp/diagram-*.mmd

echo ""
echo "Checking results..."
ls -lh "$DIAGRAMS_DIR"/diagram-*.png 2>/dev/null || echo "No diagrams found"

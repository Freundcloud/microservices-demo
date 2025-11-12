#!/bin/bash

###############################################################################
# Create KARC Word Document with Embedded Diagram Images
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"
DIAGRAMS_DIR="$DOCS_DIR/diagrams-karc"
INPUT_MD="$DOCS_DIR/GITHUB-SERVICENOW-DATA-Integration-in-KARC.md"
TEMP_MD="$DOCS_DIR/temp-karc-with-images.md"
OUTPUT_DOCX="$DOCS_DIR/GITHUB-SERVICENOW-DATA-Integration-in-KARC-with-diagrams.docx"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Create KARC Word Document with Diagrams${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if input file exists
if [ ! -f "$INPUT_MD" ]; then
    echo -e "${RED}ERROR: Input file not found: $INPUT_MD${NC}"
    exit 1
fi

# Check if diagrams directory exists
if [ ! -d "$DIAGRAMS_DIR" ]; then
    echo -e "${RED}ERROR: Diagrams directory not found: $DIAGRAMS_DIR${NC}"
    echo -e "${YELLOW}Run 'python3 scripts/render_karc_diagrams.py' first to generate diagram images${NC}"
    exit 1
fi

# Count available diagrams
DIAGRAM_COUNT=$(find "$DIAGRAMS_DIR" -name "diagram-*.png" | wc -l)
echo -e "${GREEN}Found $DIAGRAM_COUNT diagram images${NC}"
echo ""

# Create temporary markdown with image references
echo -e "${BLUE}Processing markdown file...${NC}"

DIAGRAM_NUM=0
IN_MERMAID=0

> "$TEMP_MD"  # Clear temp file

while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\`mermaid ]]; then
        IN_MERMAID=1
        DIAGRAM_NUM=$((DIAGRAM_NUM + 1))

        # Check if diagram image exists
        DIAGRAM_FILE="$DIAGRAMS_DIR/diagram-${DIAGRAM_NUM}.png"
        if [ -f "$DIAGRAM_FILE" ]; then
            echo "" >> "$TEMP_MD"
            echo "**Diagram $DIAGRAM_NUM:**" >> "$TEMP_MD"
            echo "" >> "$TEMP_MD"
            echo "![Diagram $DIAGRAM_NUM]($DIAGRAM_FILE){width=6in}" >> "$TEMP_MD"
            echo "" >> "$TEMP_MD"
            echo -e "${GREEN}  ✓ Diagram $DIAGRAM_NUM - will be embedded${NC}"
        else
            echo "" >> "$TEMP_MD"
            echo "**[Diagram $DIAGRAM_NUM - Image not available]**" >> "$TEMP_MD"
            echo "" >> "$TEMP_MD"
            echo -e "${YELLOW}  ⚠ Diagram $DIAGRAM_NUM - file not found${NC}"
        fi
        continue
    fi

    if [[ $IN_MERMAID -eq 1 ]]; then
        if [[ "$line" =~ ^\`\`\`$ ]]; then
            IN_MERMAID=0
        fi
        # Skip mermaid diagram content
        continue
    fi

    # Write regular content
    echo "$line" >> "$TEMP_MD"
done < "$INPUT_MD"

echo ""
echo -e "${GREEN}✓ Processed markdown with $DIAGRAM_NUM diagram references${NC}"
echo ""

# Convert to Word using pandoc
echo -e "${BLUE}Converting to Word document...${NC}"

pandoc "$TEMP_MD" \
    -f markdown \
    -t docx \
    -o "$OUTPUT_DOCX" \
    --toc \
    --toc-depth=3 \
    --metadata title="GitHub-ServiceNow-Kosli Integration Architecture (KARC)"

if [ -f "$OUTPUT_DOCX" ]; then
    FILE_SIZE=$(du -h "$OUTPUT_DOCX" | cut -f1)
    echo -e "${GREEN}✓ Word document created${NC}"
    echo -e "${GREEN}  File: $OUTPUT_DOCX${NC}"
    echo -e "${GREEN}  Size: $FILE_SIZE${NC}"
else
    echo -e "${RED}ERROR: Failed to create Word document${NC}"
    rm -f "$TEMP_MD"
    exit 1
fi

# Cleanup
rm -f "$TEMP_MD"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Success!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Open the document with:"
echo -e "  ${YELLOW}libreoffice $OUTPUT_DOCX${NC}"
echo ""

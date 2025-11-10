#!/bin/bash

###############################################################################
# Export Markdown to Word Document with Rendered Diagrams
###############################################################################
#
# Purpose: Convert GITHUB-SERVICENOW-DATA-Integration-in-ARC.md to DOCX
#          with Mermaid diagrams rendered as images
#
# Requirements:
#   - pandoc (for markdown to docx conversion)
#   - mermaid-cli (mmdc) (for diagram rendering)
#   - node.js (for mermaid-cli)
#
# Installation:
#   sudo apt-get install pandoc
#   npm install -g @mermaid-js/mermaid-cli
#
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"
INPUT_FILE="$DOCS_DIR/GITHUB-SERVICENOW-DATA-Integration-in-ARC.md"
OUTPUT_FILE="$DOCS_DIR/GITHUB-SERVICENOW-DATA-Integration-in-ARC.docx"
TEMP_DIR="$(mktemp -d)"
TEMP_MD="$TEMP_DIR/processed.md"
DIAGRAMS_DIR="$TEMP_DIR/diagrams"

# Cleanup function
cleanup() {
    echo -e "${BLUE}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Check if required tools are installed
check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"

    local missing_deps=0

    if ! command -v pandoc &> /dev/null; then
        echo -e "${RED}ERROR: pandoc is not installed${NC}"
        echo "Install with: sudo apt-get install pandoc"
        missing_deps=1
    else
        echo -e "${GREEN}✓ pandoc installed${NC}"
    fi

    if ! command -v mmdc &> /dev/null; then
        echo -e "${YELLOW}WARNING: mermaid-cli (mmdc) is not installed${NC}"
        echo "Install with: npm install -g @mermaid-js/mermaid-cli"
        echo "Diagrams will not be rendered as images."
        return 1
    else
        echo -e "${GREEN}✓ mermaid-cli installed${NC}"
    fi

    if [ $missing_deps -eq 1 ]; then
        exit 1
    fi

    return 0
}

# Extract and render Mermaid diagrams
extract_and_render_diagrams() {
    echo -e "${BLUE}Extracting and rendering Mermaid diagrams...${NC}"

    mkdir -p "$DIAGRAMS_DIR"

    local diagram_count=0
    local in_mermaid=0
    local current_diagram=""
    local diagram_file=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\`mermaid ]]; then
            in_mermaid=1
            diagram_count=$((diagram_count + 1))
            diagram_file="$DIAGRAMS_DIR/diagram-${diagram_count}.mmd"
            current_diagram=""
            continue
        fi

        if [[ $in_mermaid -eq 1 ]]; then
            if [[ "$line" =~ ^\`\`\`$ ]]; then
                # End of mermaid block - render it
                echo "$current_diagram" > "$diagram_file"

                echo -e "${BLUE}  Rendering diagram ${diagram_count}...${NC}"
                if mmdc -i "$diagram_file" -o "$DIAGRAMS_DIR/diagram-${diagram_count}.png" -b transparent 2>/dev/null; then
                    echo -e "${GREEN}  ✓ Diagram ${diagram_count} rendered${NC}"
                else
                    echo -e "${YELLOW}  ⚠ Failed to render diagram ${diagram_count}${NC}"
                fi

                in_mermaid=0
                current_diagram=""
            else
                current_diagram="${current_diagram}${line}"$'\n'
            fi
        fi
    done < "$INPUT_FILE"

    echo -e "${GREEN}Rendered ${diagram_count} diagrams${NC}"
    return $diagram_count
}

# Replace Mermaid blocks with image references
replace_mermaid_with_images() {
    echo -e "${BLUE}Processing markdown file...${NC}"

    local diagram_count=0
    local in_mermaid=0
    local output_content=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\`mermaid ]]; then
            in_mermaid=1
            diagram_count=$((diagram_count + 1))
            # Add image reference
            output_content="${output_content}![Diagram ${diagram_count}](${DIAGRAMS_DIR}/diagram-${diagram_count}.png)"$'\n\n'
            continue
        fi

        if [[ $in_mermaid -eq 1 ]]; then
            if [[ "$line" =~ ^\`\`\`$ ]]; then
                in_mermaid=0
            fi
            continue
        fi

        output_content="${output_content}${line}"$'\n'
    done < "$INPUT_FILE"

    echo "$output_content" > "$TEMP_MD"
    echo -e "${GREEN}Processed markdown file with ${diagram_count} diagram references${NC}"
}

# Alternative: Create HTML with embedded diagrams (if mermaid-cli not available)
create_html_with_mermaid() {
    echo -e "${BLUE}Creating HTML with Mermaid rendering...${NC}"

    local html_file="$TEMP_DIR/document.html"

    cat > "$html_file" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>GitHub-ServiceNow Data Integration in ARC</title>
    <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true });
    </script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; border-bottom: 2px solid #95a5a6; padding-bottom: 8px; margin-top: 30px; }
        h3 { color: #34495e; margin-top: 20px; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: 'Courier New', monospace; }
        pre { background: #f8f8f8; border: 1px solid #ddd; border-radius: 5px; padding: 15px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background: #3498db; color: white; font-weight: bold; }
        tr:nth-child(even) { background: #f9f9f9; }
        blockquote { border-left: 4px solid #3498db; margin: 20px 0; padding-left: 20px; color: #555; }
        .mermaid { background: white; padding: 20px; margin: 20px 0; border: 1px solid #e0e0e0; border-radius: 5px; }
    </style>
</head>
<body>
EOF

    # Convert markdown to HTML and append
    pandoc "$INPUT_FILE" -f markdown -t html >> "$html_file"

    cat >> "$html_file" <<'EOF'
</body>
</html>
EOF

    echo -e "${GREEN}HTML file created: $html_file${NC}"
    echo -e "${YELLOW}Note: Open this HTML file in a browser to view rendered diagrams${NC}"
    echo -e "${YELLOW}You can then print to PDF or use browser tools to convert to Word${NC}"

    # Copy HTML to docs directory
    cp "$html_file" "$DOCS_DIR/GITHUB-SERVICENOW-DATA-Integration-in-ARC.html"
    echo -e "${GREEN}HTML file saved to: $DOCS_DIR/GITHUB-SERVICENOW-DATA-Integration-in-ARC.html${NC}"
}

# Convert to Word document using pandoc
convert_to_docx() {
    echo -e "${BLUE}Converting to Word document...${NC}"

    # Create reference docx with custom styling (optional)
    pandoc "$TEMP_MD" \
        -f markdown \
        -t docx \
        -o "$OUTPUT_FILE" \
        --toc \
        --toc-depth=3 \
        --reference-doc="$DOCS_DIR/reference.docx" 2>/dev/null || \
    pandoc "$TEMP_MD" \
        -f markdown \
        -t docx \
        -o "$OUTPUT_FILE" \
        --toc \
        --toc-depth=3

    if [ -f "$OUTPUT_FILE" ]; then
        echo -e "${GREEN}✓ Word document created: $OUTPUT_FILE${NC}"

        # Get file size
        local file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo -e "${GREEN}  File size: $file_size${NC}"

        return 0
    else
        echo -e "${RED}ERROR: Failed to create Word document${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Export Markdown to Word with Diagrams${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Check if input file exists
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}ERROR: Input file not found: $INPUT_FILE${NC}"
        exit 1
    fi

    echo -e "${GREEN}Input file: $INPUT_FILE${NC}"
    echo -e "${GREEN}Output file: $OUTPUT_FILE${NC}"
    echo ""

    # Check dependencies
    if ! check_dependencies; then
        echo ""
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}Alternative: Creating HTML with Mermaid${NC}"
        echo -e "${YELLOW}========================================${NC}"
        echo ""

        create_html_with_mermaid

        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}Next Steps:${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "1. Open the HTML file in a web browser"
        echo -e "2. Wait for diagrams to render"
        echo -e "3. Use browser 'Print' or 'Save as PDF'"
        echo -e "4. Convert PDF to Word using online tools or MS Word"
        echo ""
        echo -e "${GREEN}HTML file location:${NC}"
        echo -e "  $DOCS_DIR/GITHUB-SERVICENOW-DATA-Integration-in-ARC.html"

        exit 0
    fi

    echo ""

    # Extract and render diagrams
    if extract_and_render_diagrams; then
        # Replace mermaid blocks with image references
        replace_mermaid_with_images

        # Convert to Word
        if convert_to_docx; then
            echo ""
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}✓ Export completed successfully!${NC}"
            echo -e "${GREEN}========================================${NC}"
            echo ""
            echo -e "${GREEN}Output file: $OUTPUT_FILE${NC}"
            echo ""
            echo -e "${BLUE}You can open this file with:${NC}"
            echo -e "  - Microsoft Word"
            echo -e "  - LibreOffice Writer"
            echo -e "  - Google Docs (upload)"
        fi
    else
        echo -e "${YELLOW}No diagrams to render, proceeding with markdown conversion...${NC}"
        cp "$INPUT_FILE" "$TEMP_MD"
        convert_to_docx
    fi
}

# Run main function
main "$@"

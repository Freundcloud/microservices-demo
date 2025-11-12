#!/usr/bin/env python3

"""
Render Mermaid diagrams from KARC document to PNG images using mermaid.ink API

This script extracts Mermaid diagrams from the KARC markdown file and renders them
as PNG images using the mermaid.ink service (no local installation required).
"""

import re
import os
import sys
import base64
import urllib.parse
import urllib.request
from pathlib import Path

def extract_mermaid_diagrams(markdown_file):
    """Extract all Mermaid diagram code blocks from markdown file"""
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all mermaid code blocks
    pattern = r'```mermaid\n(.*?)```'
    diagrams = re.findall(pattern, content, re.DOTALL)

    return diagrams

def render_diagram_via_mermaid_ink(mermaid_code, output_file):
    """
    Render Mermaid diagram using mermaid.ink API

    This service converts Mermaid code to PNG without requiring local installation.
    """
    try:
        # Encode the mermaid code for URL
        encoded = base64.urlsafe_b64encode(mermaid_code.encode('utf-8')).decode('utf-8')

        # mermaid.ink API endpoint
        url = f"https://mermaid.ink/img/{encoded}?type=png"

        print(f"  Fetching diagram from mermaid.ink...")

        # Download the image
        with urllib.request.urlopen(url, timeout=30) as response:
            image_data = response.read()

        # Save the image
        with open(output_file, 'wb') as f:
            f.write(image_data)

        print(f"  ✓ Saved to {output_file}")
        return True

    except Exception as e:
        print(f"  ✗ Failed to render diagram: {e}")
        return False

def main():
    # Paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    docs_dir = project_root / 'docs'
    diagrams_dir = docs_dir / 'diagrams-karc'

    input_file = docs_dir / 'GITHUB-SERVICENOW-DATA-Integration-in-KARC.md'

    print("=" * 70)
    print("KARC Mermaid Diagram Renderer")
    print("=" * 70)
    print()

    # Check if input file exists
    if not input_file.exists():
        print(f"ERROR: Input file not found: {input_file}")
        sys.exit(1)

    # Create diagrams directory
    diagrams_dir.mkdir(exist_ok=True)
    print(f"Output directory: {diagrams_dir}")
    print()

    # Extract diagrams
    print("Extracting Mermaid diagrams...")
    diagrams = extract_mermaid_diagrams(input_file)
    print(f"Found {len(diagrams)} diagrams")
    print()

    # Render each diagram
    success_count = 0
    for i, diagram_code in enumerate(diagrams, 1):
        print(f"Rendering diagram {i}/{len(diagrams)}...")
        output_file = diagrams_dir / f"diagram-{i}.png"

        if render_diagram_via_mermaid_ink(diagram_code, output_file):
            success_count += 1

        print()

    # Summary
    print("=" * 70)
    print(f"✓ Successfully rendered {success_count}/{len(diagrams)} diagrams")
    print("=" * 70)
    print()
    print(f"Diagram files saved in: {diagrams_dir}")
    print()
    print("Next steps:")
    print("1. Run: bash scripts/create_karc_docx_with_diagrams.sh")
    print("2. Or manually insert images into the Word document")

    if success_count < len(diagrams):
        sys.exit(1)

if __name__ == '__main__':
    main()

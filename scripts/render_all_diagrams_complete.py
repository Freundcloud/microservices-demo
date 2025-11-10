#!/usr/bin/env python3

"""
Complete Mermaid Diagram Renderer with Multiple Fallback Methods

This script tries multiple rendering services to ensure all diagrams are rendered.
"""

import re
import os
import sys
import base64
import urllib.parse
import urllib.request
import json
import time
from pathlib import Path

def extract_mermaid_diagrams(markdown_file):
    """Extract all Mermaid diagram code blocks from markdown file"""
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = r'```mermaid\n(.*?)```'
    diagrams = re.findall(pattern, content, re.DOTALL)

    return diagrams

def render_via_mermaid_ink(mermaid_code, output_file):
    """Method 1: mermaid.ink API"""
    try:
        encoded = base64.urlsafe_b64encode(mermaid_code.encode('utf-8')).decode('utf-8')
        url = f"https://mermaid.ink/img/{encoded}?type=png"

        with urllib.request.urlopen(url, timeout=30) as response:
            image_data = response.read()

        # Check if it's actually an image (not error text)
        if len(image_data) > 100 and image_data[:4] == b'\x89PNG':
            with open(output_file, 'wb') as f:
                f.write(image_data)
            return True
    except Exception as e:
        print(f"    mermaid.ink failed: {e}")
    return False

def render_via_kroki(mermaid_code, output_file):
    """Method 2: kroki.io API"""
    try:
        url = "https://kroki.io/mermaid/png"
        headers = {'Content-Type': 'text/plain'}

        req = urllib.request.Request(url, data=mermaid_code.encode('utf-8'), headers=headers, method='POST')

        with urllib.request.urlopen(req, timeout=30) as response:
            image_data = response.read()

        # Check if it's actually an image
        if len(image_data) > 100 and image_data[:4] == b'\x89PNG':
            with open(output_file, 'wb') as f:
                f.write(image_data)
            return True
    except Exception as e:
        print(f"    kroki.io failed: {e}")
    return False

def render_via_quickchart(mermaid_code, output_file):
    """Method 3: quickchart.io API"""
    try:
        # Encode the mermaid diagram
        encoded = urllib.parse.quote(mermaid_code)
        url = f"https://quickchart.io/mermaid?c={encoded}"

        with urllib.request.urlopen(url, timeout=30) as response:
            image_data = response.read()

        # Check if it's actually an image
        if len(image_data) > 100 and image_data[:4] == b'\x89PNG':
            with open(output_file, 'wb') as f:
                f.write(image_data)
            return True
    except Exception as e:
        print(f"    quickchart.io failed: {e}")
    return False

def simplify_diagram(mermaid_code):
    """Simplify complex diagrams for better rendering"""
    # Remove style directives that might cause issues
    simplified = re.sub(r'style\s+\w+\s+fill:#[a-fA-F0-9]+', '', mermaid_code)

    # Remove comments
    simplified = re.sub(r'%%.*?\n', '', simplified)

    return simplified.strip()

def render_diagram(mermaid_code, output_file, diagram_num):
    """Try multiple methods to render a diagram"""
    print(f"\nRendering diagram {diagram_num}...")

    methods = [
        ("mermaid.ink", render_via_mermaid_ink),
        ("kroki.io", render_via_kroki),
        ("quickchart.io", render_via_quickchart),
    ]

    # Try original code first
    for method_name, method_func in methods:
        print(f"  Trying {method_name}...")
        if method_func(mermaid_code, output_file):
            print(f"  ✓ Success with {method_name}")
            return True
        time.sleep(1)  # Rate limiting

    # If original failed, try simplified version
    print("  Trying simplified version...")
    simplified = simplify_diagram(mermaid_code)

    for method_name, method_func in methods:
        print(f"  Trying {method_name} (simplified)...")
        if method_func(simplified, output_file):
            print(f"  ✓ Success with {method_name} (simplified)")
            return True
        time.sleep(1)

    print(f"  ✗ All methods failed for diagram {diagram_num}")
    return False

def main():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    docs_dir = project_root / 'docs'
    diagrams_dir = docs_dir / 'diagrams'

    input_file = docs_dir / 'GITHUB-SERVICENOW-DATA-Integration-in-ARC.md'

    print("=" * 70)
    print("Complete Mermaid Diagram Renderer")
    print("=" * 70)

    if not input_file.exists():
        print(f"ERROR: Input file not found: {input_file}")
        sys.exit(1)

    diagrams_dir.mkdir(exist_ok=True)
    print(f"Output directory: {diagrams_dir}\n")

    # Extract diagrams
    print("Extracting Mermaid diagrams...")
    diagrams = extract_mermaid_diagrams(input_file)
    print(f"Found {len(diagrams)} diagrams\n")

    # Render each diagram
    success_count = 0
    for i, diagram_code in enumerate(diagrams, 1):
        output_file = diagrams_dir / f"diagram-{i}.png"

        # Skip if already exists and is valid
        if output_file.exists():
            if output_file.stat().st_size > 1000:  # At least 1KB
                print(f"\n✓ Diagram {i} already exists and looks valid")
                success_count += 1
                continue
            else:
                print(f"\n⚠ Diagram {i} exists but may be invalid, re-rendering...")

        if render_diagram(diagram_code, output_file, i):
            success_count += 1

    # Summary
    print("\n" + "=" * 70)
    print(f"Rendered {success_count}/{len(diagrams)} diagrams")
    print("=" * 70)

    if success_count == len(diagrams):
        print("\n✓ All diagrams rendered successfully!")
        return 0
    else:
        print(f"\n⚠ {len(diagrams) - success_count} diagram(s) failed to render")
        print("\nFailed diagrams can be rendered manually at:")
        print("  https://mermaid.live/")
        return 1

if __name__ == '__main__':
    sys.exit(main())

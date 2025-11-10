# Export Documentation to Word Format

This guide explains how to export the GitHub-ServiceNow integration documentation to Microsoft Word format (.docx) with rendered Mermaid diagrams.

## Quick Start

### Option 1: Python Script (Recommended)

The Python script provides the best results with proper formatting and diagram rendering.

**Step 1: Install Python Dependencies**

```bash
pip install python-docx markdown beautifulsoup4 pillow
```

**Step 2: Install Mermaid CLI (for diagram rendering)**

```bash
npm install -g @mermaid-js/mermaid-cli
```

**Step 3: Run the Conversion**

```bash
cd /home/olafkfreund/Source/Calitti/ARC/microservices-demo
python3 scripts/export_to_word.py
```

**Output:** `docs/GITHUB-SERVICENOW-DATA-Integration-in-ARC.docx`

---

### Option 2: Bash Script

The bash script uses pandoc and can create both Word documents and HTML files.

**Step 1: Install Dependencies**

```bash
# Ubuntu/Debian
sudo apt-get install pandoc

# For diagram rendering
npm install -g @mermaid-js/mermaid-cli
```

**Step 2: Run the Conversion**

```bash
cd /home/olafkfreund/Source/Calitti/ARC/microservices-demo
./scripts/export-doc-to-word.sh
```

**Output:** `docs/GITHUB-SERVICENOW-DATA-Integration-in-ARC.docx`

---

### Option 3: Manual Conversion (No Installation Required)

If you don't want to install dependencies, you can use online tools:

**Step 1: Generate HTML with Diagrams**

1. Open the markdown file in a text editor
2. Copy all content
3. Go to https://mermaid.live/
4. Paste each Mermaid diagram (between \`\`\`mermaid and \`\`\`) into Mermaid Live Editor
5. Export each diagram as PNG
6. Replace Mermaid code blocks in markdown with image references

**Step 2: Convert Markdown to Word**

Use one of these online converters:
- https://cloudconvert.com/md-to-docx
- https://www.zamzar.com/convert/md-to-docx/
- https://products.aspose.app/words/conversion/md-to-docx

---

## What Gets Converted

The conversion process handles:

- **Text Formatting:** Headings, paragraphs, bold, italic, code
- **Tables:** All markdown tables converted to Word tables
- **Code Blocks:** Formatted with monospace font and gray background
- **Diagrams:** Mermaid diagrams rendered as PNG images (if mermaid-cli installed)
- **Blockquotes:** Styled as emphasized text
- **Lists:** Bullet and numbered lists

## Expected Output

**File Details:**
- Format: Microsoft Word (.docx)
- Size: ~500KB - 2MB (depending on diagram count)
- Diagrams: 6 high-resolution PNG images embedded
- Pages: ~40-50 pages
- Compatible with: Word 2007+, LibreOffice Writer, Google Docs

**Document Structure:**
1. Title Page
2. Table of Contents (if using pandoc)
3. Main Content with:
   - Executive Summary
   - Architecture Diagrams
   - Technical Implementation Details
   - Database Schema
   - API Reference
   - Troubleshooting Guide
4. Appendices

## Troubleshooting

### Issue: "mmdc: command not found"

**Solution:** Mermaid CLI is not installed. Diagrams won't be rendered.

```bash
# Install Node.js first if needed
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli
```

### Issue: "ModuleNotFoundError: No module named 'docx'"

**Solution:** Python dependencies not installed.

```bash
pip install python-docx markdown beautifulsoup4 pillow
```

### Issue: Diagrams not rendering in Word

**Possible causes:**
1. Mermaid CLI not installed - Install it per instructions above
2. Mermaid syntax errors - Check diagram syntax in [Mermaid Live Editor](https://mermaid.live/)
3. Image path issues - Ensure temp directory has write permissions

### Issue: Tables not formatting correctly

**Solution:** The Python script uses Word's built-in table styles. You can manually adjust:
1. Open the Word document
2. Click on any table
3. Go to "Table Design" ribbon
4. Select a different table style

### Issue: Font sizes too small/large

**Solution:** Adjust in the Python script:

```python
# In export_to_word.py, modify _setup_styles() method
h1.font.size = Pt(20)  # Change to desired size
h2.font.size = Pt(16)  # Change to desired size
```

## Customization

### Change Diagram Size

Edit `export_to_word.py`:

```python
# Find this line:
self.document.add_picture(image_path, width=Inches(6.0))

# Change to:
self.document.add_picture(image_path, width=Inches(5.0))  # Smaller
# or
self.document.add_picture(image_path, width=Inches(7.0))  # Larger
```

### Change Document Margins

After conversion, in Microsoft Word:
1. Go to Layout > Margins
2. Select "Normal" or "Narrow"
3. Save the document

### Add Header/Footer

In the Python script, add after `self._setup_styles()`:

```python
# Add header
section = self.document.sections[0]
header = section.header
header_para = header.paragraphs[0]
header_para.text = "GitHub-ServiceNow Integration - ARC Documentation"
header_para.alignment = WD_ALIGN_PARAGRAPH.CENTER

# Add footer with page numbers
footer = section.footer
footer_para = footer.paragraphs[0]
footer_para.text = "Page "
footer_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
```

## Advanced: Export to PDF

**Option 1: Via LibreOffice (Linux)**

```bash
# Convert Word to PDF
libreoffice --headless --convert-to pdf \
  docs/GITHUB-SERVICENOW-DATA-Integration-in-ARC.docx \
  --outdir docs/
```

**Option 2: Via Microsoft Word (Windows/Mac)**

1. Open the .docx file in Microsoft Word
2. File > Save As
3. Select "PDF" as format
4. Click "Save"

**Option 3: Via Python (using docx2pdf)**

```bash
pip install docx2pdf

python3 -c "
from docx2pdf import convert
convert('docs/GITHUB-SERVICENOW-DATA-Integration-in-ARC.docx',
        'docs/GITHUB-SERVICENOW-DATA-Integration-in-ARC.pdf')
"
```

## Verification

After conversion, verify the document:

1. **Open the file** in Microsoft Word or LibreOffice
2. **Check page count** - Should be 40-50 pages
3. **Verify diagrams** - All 6 diagrams should be visible as images
4. **Check tables** - All tables should be properly formatted
5. **Test navigation** - Table of contents links should work (if generated)
6. **Review formatting** - Headers, code blocks, and emphasis should be styled correctly

## Support

If you encounter issues not covered here:

1. Check the script output for error messages
2. Verify all dependencies are installed correctly
3. Test with a simple markdown file first
4. Check the [python-docx documentation](https://python-docx.readthedocs.io/)
5. Report issues in the project repository

---

**Created:** 2025-11-10
**Last Updated:** 2025-11-10
**Script Versions:**
- export_to_word.py: v1.0
- export-doc-to-word.sh: v1.0

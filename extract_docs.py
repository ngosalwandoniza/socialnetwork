import zipfile
import xml.etree.ElementTree as ET
import os

def extract_text(docx_path, out_path):
    try:
        with zipfile.ZipFile(docx_path, 'r') as zip_ref:
            if 'word/document.xml' not in zip_ref.namelist():
                print(f"No word/document.xml in {docx_path}")
                return
            xml_content = zip_ref.read('word/document.xml')
            tree = ET.fromstring(xml_content)
            namespace = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
            paragraphs = []
            for p in tree.findall('.//w:p', namespace):
                texts = [t.text for t in p.findall('.//w:t', namespace) if t.text]
                if texts:
                    paragraphs.append(''.join(texts))
            with open(out_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(paragraphs))
            print(f"Extracted {docx_path} to {out_path}")
    except Exception as e:
        print(f"Failed to extract {docx_path}: {e}")

if __name__ == "__main__":
    extract_text('algosocial.docx', 'algosocial_text.txt')
    extract_text('social2.docx', 'social2_text.txt')
    extract_text('wetrysocial.docx', 'wetrysocial_text.txt')

#!/usr/bin/env python3
"""Extract embedded images and nearby Word captions from a local Character Bible DOCX.

Read-only with respect to Supabase and GitHub. Creates a local extraction report
and files for manual visual review. No automatic character-to-image approvals.
Usage:
  python3 scripts/extract_character_bible_media.py path/to/Character_Bible.docx --out /tmp/atlas-media
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile, BadZipFile

WORD = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
DRAW = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PKG = "{http://schemas.openxmlformats.org/package/2006/relationships}"
CHARACTERS = ("Damien Wayne", "Audrey Quin", "Iris Wayne", "Omar", "Amon Dimano", "Maria", "Maya", "Z")

def extract(source: Path, out: Path) -> dict:
    if not source.is_file() or source.suffix.lower() != ".docx":
        raise ValueError("Source must be an existing .docx file")
    out.mkdir(parents=True, exist_ok=True)
    with ZipFile(source) as z:
        names = set(z.namelist())
        if "word/document.xml" not in names or "word/_rels/document.xml.rels" not in names:
            raise ValueError("DOCX missing Word document or relationships")
        rel_root = ET.fromstring(z.read("word/_rels/document.xml.rels"))
        rels = {}
        for rel in rel_root.findall(f"{PKG}Relationship"):
            target = rel.attrib.get("Target", "")
            if rel.attrib.get("Type", "").endswith("/image") and not rel.attrib.get("TargetMode"):
                # Reject traversal, external links and non-media paths.
                parts = target.replace("\\", "/").split("/")
                if ".." in parts or target.startswith("/"):
                    continue
                path = target if target.startswith("word/") else "word/" + target
                if path.startswith("word/media/") and path in names:
                    rels[rel.attrib["Id"]] = path
        root = ET.fromstring(z.read("word/document.xml"))
        paragraphs = []
        for para in root.iter(f"{WORD}p"):
            text = "".join(t.text or "" for t in para.iter(f"{WORD}t")).strip()
            images = [el.attrib.get(f"{REL}embed") for el in para.iter(f"{DRAW}blip")]
            paragraphs.append((text, [rid for rid in images if rid in rels]))
        entries = []
        for idx, (caption, image_ids) in enumerate(paragraphs):
            for rid in image_ids:
                media = rels[rid]
                data = z.read(media)
                digest = hashlib.sha256(data).hexdigest()
                suffix = Path(media).suffix.lower()
                if suffix not in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff"):
                    continue
                name = f"{len(entries)+1:03d}_{digest[:12]}{suffix}"
                (out / name).write_bytes(data)
                nearby = [t for t, _ in paragraphs[max(0, idx-3):min(len(paragraphs), idx+4)] if t]
                matches = [person for person in CHARACTERS if any(re.search(r"\b" + re.escape(person) + r"\b", t, re.I) for t in nearby)]
                entries.append({
                    "file": name, "sha256": digest, "sourcePart": media,
                    "relationshipId": rid, "paragraphIndex": idx,
                    "nearbyText": nearby[:6],
                    "possibleCharacters": matches,
                    "reviewStatus": "unassigned_requires_human_review",
                    "approved": False
                })
        report = {
            "source": source.name,
            "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "extractionVersion": 1,
            "images": entries,
            "note": "Character matches are caption proximity hints only. Never auto-approve or replace canonical portraits."
        }
        (out / "extraction-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = extract(args.source, args.out)
    except (ValueError, BadZipFile, ET.ParseError) as error:
        parser.error(str(error))
    print(f"Extracted {len(result['images'])} images into {args.out}; all require manual mapping.")

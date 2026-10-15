#!/usr/bin/env python3
"""Build, validate and select traceable HIPAA knowledge inputs without model calls."""
import argparse
from collections import Counter
import gzip
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "hipaa-documents"
DEMO = ROOT / "hipaa-demo-knowledge"
LOCAL = ROOT / "contest/data/knowledge"
SCHEMA = 2
KIND_SCOPES = {
    "regulation_snapshot": "normative",
    "official_guidance": "normative",
    "technical_guidance": "technical",
    "llm_synthesis": "orientation",
    "demo_policy": "organization_policy",
    "historical_final_rule": "historical",
    "archived_pdf": "unreviewed",
    "archived_template": "unreviewed",
    "archived_text": "unreviewed",
    "unreviewed_archived_page": "unreviewed",
}
DEFAULT_SCOPES = ["normative", "technical", "orientation", "organization_policy"]
BACKGROUND_SCOPES = ["historical", "unreviewed"]
HISTORICAL_PDFS = {
    "prdecember2000all8parts.pdf": "2000-12-28",
    "privrulepd.pdf": "2002-08-14",
    "securityrulepdf.pdf": "2003-02-20",
}
USEFUL_HHS_PDFS = {
    "rafinalguidancepdf.pdf": "HHS guidance on HIPAA Security Rule risk analysis",
    "techsafeguards.pdf": "HHS guidance on technical safeguards; corroborate dated implementation examples",
}
REQUIRED_URLS = {
    "https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/minimum-necessary-requirement/index.html",
    "https://www.hhs.gov/hipaa/for-professionals/privacy/special-topics/de-identification/index.html",
    "https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/business-associates/index.html",
    "https://www.hhs.gov/hipaa/for-professionals/special-topics/health-information-technology/cloud-computing/index.html",
    "https://www.hhs.gov/hipaa/for-professionals/security/laws-regulations/index.html",
    "https://www.hhs.gov/hipaa/for-professionals/breach-notification/index.html",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def normalize(text):
    return "\n".join(re.sub(r"\s+", " ", line).strip()
                     for line in text.splitlines() if line.strip())


class Article(HTMLParser):
    def __init__(self, container="article"):
        super().__init__(convert_charrefs=True)
        self.container = container
        self.depth = 0
        self.suppressed = 0
        self.text = []

    def handle_starttag(self, tag, attrs):
        if tag == self.container:
            self.depth += 1
        if tag in ("script", "style"):
            self.suppressed += 1
        if self.depth and tag in ("p", "li", "h1", "h2", "h3", "h4", "br", "tr", "td", "th"):
            self.text.append("\n")

    def handle_endtag(self, tag):
        if tag == self.container:
            self.depth -= 1
        if tag in ("script", "style"):
            self.suppressed -= 1
        if self.depth and tag in ("p", "li", "h1", "h2", "h3", "h4", "tr", "td", "th"):
            self.text.append("\n")

    def handle_data(self, data):
        if self.depth and not self.suppressed:
            self.text.append(data)


def document(url, title, text, kind, source_hash, source_locator, **metadata):
    text = normalize(text)
    if not text:
        raise ValueError("Empty knowledge document: " + url)
    return {
        "id": digest((url + "#" + source_locator).encode())[:24],
        "title": title, "text": text, "kind": kind, "source_url": url,
        "source_sha256": source_hash, "source_locator": source_locator,
        "content_sha256": digest(text.encode()), "retrieved_on": "2026-10-15",
        "source_version": "archive snapshot 2026-10-15; publication date not verified",
        "retrieval_scope": "unreviewed",
        "legal_status": "snapshot_not_independently_verified",
        "permitted_use": "reference_requires_context",
        **metadata,
    }


def demo_html(url, title):
    if url in REQUIRED_URLS:
        return True
    lower = (url + " " + title).lower()
    if any(word in lower for word in (
        "/ocr/", "language=", "nprm", "proposed", "reproductive", "covid",
        "coronavirus", "waiver", "enforcement-discretion", "/compliance-enforcement/",
        "regulation-history", "regulation-initiatives", "regulatory-initiatives",
        "hipaa-online-tracking",
    )):
        return False
    return any(part in url for part in (
        "/privacy/guidance/", "/privacy/special-topics/", "/security/guidance/",
        "/faq/", "/breach-notification/", "/special-topics/health-information-technology/",
        "/covered-entities/",
    ))


def selected_pdf(url):
    filename = url.split("?")[0].rsplit("/", 1)[-1]
    return filename in USEFUL_HHS_PDFS or url in {
        source["url"] for source in json.loads(
            (DEMO / "supplemental-sources.json").read_text())["sources"]
    }


def fetch_supplemental():
    specifications = json.loads((DEMO / "supplemental-sources.json").read_text())["sources"]
    directory = ARCHIVE / "sources/supplemental"
    directory.mkdir(parents=True, exist_ok=True)
    files = []
    for specification in specifications:
        filename = specification["filename"]
        if Path(filename).name != filename:
            raise ValueError("Supplemental filename must not contain directories")
        path = directory / filename
        if not path.is_file() or digest(path.read_bytes()) != specification["sha256"]:
            temporary = path.with_suffix(".download")
            try:
                subprocess.run([
                    "curl", "--fail", "--location", "--retry", "2", "--max-time", "120",
                    "--output", str(temporary), specification["url"],
                ], check=True)
                if digest(temporary.read_bytes()) != specification["sha256"]:
                    raise ValueError("Supplemental source checksum mismatch: " + filename)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
        files.append({
            "path": str(path.relative_to(ARCHIVE)), "source_url": specification["url"],
            "landing_url": specification["landing_url"], "published": specification["published"],
            "retrieved_on": "2026-10-15", "bytes": path.stat().st_size,
            "sha256": specification["sha256"],
        })
    atomic_write(directory / "manifest.json",
                 (json.dumps({"files": files}, indent=2) + "\n").encode())
    print("Verified supplemental official source PDFs:", len(files))


def source_documents(profile):
    manifest_path = ARCHIVE / "sources/hhs/manifest.json"
    if not manifest_path.is_file():
        raise ValueError("Local archive is missing; full sources are not distributed in Git")
    manifest = json.loads(manifest_path.read_text())
    if manifest["pending"]:
        raise ValueError("Archive crawl has pending URLs; inspect the source manifest")
    inputs = []
    for url, record in manifest["records"].items():
        inputs.append((url, {**record, "relative_source": "sources/hhs/" + record.get("path", "")}))
    regulation_manifest = json.loads((ARCHIVE / "manifest.json").read_text())
    expected_regulation_hashes = {entry["path"]: entry["sha256"]
                                 for entry in regulation_manifest["files"]}
    supplemental = json.loads((ARCHIVE / "sources/supplemental/manifest.json").read_text())
    specifications = {
        entry["url"]: entry for entry in json.loads(
            (DEMO / "supplemental-sources.json").read_text())["sources"]
    }
    for entry in supplemental["files"]:
        if entry["sha256"] != specifications[entry["source_url"]]["sha256"]:
            raise ValueError("Supplemental manifest does not match pinned source")
        inputs.append((entry["source_url"], {
            "status": 200, "relative_source": entry["path"],
            "path": Path(entry["path"]).name, "sha256": entry["sha256"],
            "title": specifications[entry["source_url"]]["title"],
            "content_type": "application/pdf",
        }))
    if profile in ("demo", "full"):
        for record in regulation_manifest["files"]:
            if record["path"].endswith(".pdf"):
                inputs.append((record["source_url"], {
                    "status": 200, "relative_source": record["path"],
                    "path": Path(record["path"]).name, "sha256": record["sha256"],
                    "content_type": "application/pdf",
                }))
    failures = [{"url": u, "status": r["status"], "error": r.get("error")}
                for u, r in manifest["records"].items() if r["status"] != 200]
    extraction_gaps = []
    exclusions = []
    records = []
    # Prefer modern URLs over legacy redirects when exact extracted text matches.
    ordered = sorted(inputs,
                     key=lambda item: (item[0] not in REQUIRED_URLS, "/ocr/" in item[0], item[0]))
    for url, source in ordered:
        if source["status"] != 200:
            continue
        mime = source.get("content_type", "").split(";")[0]
        title = source.get("title", url.rsplit("/", 1)[-1])
        path = ARCHIVE / source["relative_source"]
        raw = path.read_bytes()
        data = gzip.decompress(raw) if source.get("encoding") == "gzip" else raw
        if digest(data) != source["sha256"]:
            raise ValueError("Source hash mismatch: " + url)
        if mime == "text/html":
            article = Article()
            article.feed(data.decode("utf-8", errors="strict"))
            text = normalize("".join(article.text))
            if not text:
                article = Article("main")
                article.feed(data.decode("utf-8", errors="strict"))
                text = normalize("".join(article.text))
                if not text:
                    raise ValueError("No article or main body: " + url)
                extraction_gaps.append({"url": url, "note": "Main container used; may include navigation"})
            curated = demo_html(url, title)
            records.append(document(url, title, text,
                                    "official_guidance" if curated else "unreviewed_archived_page",
                                    source["sha256"], "HTML article",
                                    source_version="HHS page snapshot 2026-10-15",
                                    legal_status="guidance_or_faq_not_binding_regulation" if curated
                                    else "unreviewed_may_include_proposals_and_history"))
        elif mime == "application/pdf":
            extracted = ARCHIVE / "prepared/pdf-text" / (source["path"] + ".json")
            if not extracted.is_file():
                raise ValueError("PDF text missing; run extract_pdfs.swift first: " + url)
            pdf = json.loads(extracted.read_text())
            if pdf["source_sha256"] != source["sha256"]:
                raise ValueError("Stale PDF extraction: " + url)
            if pdf["pages_without_text"]:
                extraction_gaps.append({"url": url, "pages_without_text": pdf["pages_without_text"]})
            filename = url.split("?")[0].rsplit("/", 1)[-1]
            published = HISTORICAL_PDFS.get(filename)
            useful = selected_pdf(url)
            specification = specifications.get(url, {})
            for start in range(0, len(pdf["pages"]), 8):
                end = min(start + 8, len(pdf["pages"]))
                text = "\n\n".join(pdf["pages"][start:end])
                if not text.strip():
                    continue
                records.append(document(
                    url, title, text,
                    "historical_final_rule" if published else
                    "technical_guidance" if useful else "archived_pdf",
                    source["sha256"], f"PDF pages {start + 1}-{end}",
                    source_version=published or specification.get("published")
                    or "HHS guidance snapshot 2026-10-15; see publication text",
                    legal_status="historical_not_current_authority" if published else
                    "supporting_guidance_not_regulation" if useful else "unreviewed_archive",
                    permitted_use="historical_explanation_only" if published else
                    "technical_evidence_requires_context" if useful else "reference_requires_review",
                    selection_reason=specification.get("purpose") or USEFUL_HHS_PDFS.get(filename),
                    pages=[start + 1, end],
                ))
        elif mime == "text/plain":
            records.append(document(url, title, data.decode("utf-8-sig"), "archived_text",
                                    source["sha256"], "complete text"))
        elif mime.endswith("wordprocessingml.document"):
            with zipfile.ZipFile(path) as archive:
                tree = ET.fromstring(archive.read("word/document.xml"))
            ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
            text = "\n".join("".join(p.itertext()) for p in tree.findall(".//w:p", ns))
            records.append(document(url, title, text, "archived_template",
                                    source["sha256"], "DOCX paragraphs"))
        else:
            raise ValueError("Unsupported successful source type: " + mime)
    for part in ("160", "162", "164"):
        path = ARCHIVE / f"45-CFR-{part}-2026-10-13.xml"
        if digest(path.read_bytes()) != expected_regulation_hashes[path.name]:
            raise ValueError("Regulation source hash mismatch: " + path.name)
        tree = ET.parse(path).getroot()
        for section in tree.iter():
            if section.get("TYPE") != "SECTION":
                continue
            number = section.get("N")
            records.append(document(
                "https://www.ecfr.gov/on/2026-10-13/title-45/section-" + number,
                normalize(" ".join(section.find("HEAD").itertext())),
                "\n".join("".join(child.itertext()) for child in section),
                "regulation_snapshot", digest(path.read_bytes()), "45 CFR " + number,
                source_version="eCFR 2026-10-13", part=part,
            ))
    for path in sorted((DEMO / "briefs").glob("*.md")):
        text = path.read_text()
        records.append(document(
            "project:hipaa-demo-knowledge/briefs/" + path.name,
            text.splitlines()[0].lstrip("# "), text,
            "demo_policy" if "example-organization-policy" in path.name else "llm_synthesis",
            digest(path.read_bytes()), path.name,
            legal_status="synthetic_not_legal_authority",
            permitted_use="local_demo_policy" if "example-organization-policy" in path.name
            else "search_orientation_not_legal_authority",
            source_version="demo-v1", generation="coding-assistant synthesis; no external model call",
        ))
    unique = {}
    for record in records:
        record["retrieval_scope"] = KIND_SCOPES[record["kind"]]
        key = (record["kind"], record["content_sha256"])
        if key in unique:
            unique[key].setdefault("duplicate_source_urls", []).append(record["source_url"])
        else:
            unique[key] = record
    return sorted(unique.values(), key=lambda r: r["id"]), failures, extraction_gaps, exclusions


def atomic_write(path, data):
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def build(profile):
    records, failures, gaps, exclusions = source_documents(profile)
    output = DEMO if profile == "demo" else ARCHIVE / "prepared/full"
    output.mkdir(parents=True, exist_ok=True)
    data = b"".join((json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n").encode()
                    for r in records)
    text_bytes = sum(len(r["text"].encode()) for r in records)
    urls = {r["source_url"] for r in records}
    missing = REQUIRED_URLS - urls
    if missing:
        raise ValueError("Missing essential guidance: " + repr(sorted(missing)))
    manifest = {
        "schema_version": SCHEMA, "profile": profile, "corpus_id": digest(data),
        "documents": len(records), "text_bytes": text_bytes, "file_bytes": len(data),
        "document_kinds": dict(sorted(Counter(r["kind"] for r in records).items())),
        "knowledge_file": "documents.jsonl", "snapshot": "2026-10-13",
        "collected_on": "2026-10-15",
        "preparation": "LLM-authored briefs plus deterministic source selection, article extraction and exact-text deduplication; original evidence is not LLM-rewritten",
        "authority": "No legal review; historical and synthetic records are not current legal authority",
        "failed_archive_urls": failures, "extraction_notes": gaps,
        "selection_exclusions": exclusions,
        "distribution": "Complete prepared text; original binary archive is not distributed",
        "retrieval_scopes": dict(sorted(Counter(r["retrieval_scope"] for r in records).items())),
        "default_retrieval_scopes": DEFAULT_SCOPES,
        "excluded_by_default": BACKGROUND_SCOPES,
        "full_profile_meaning": "All successfully archived HHS article and PDF/DOCX/plain-text content, original Act and annual CFR PDFs, Parts 160/162/164 XML and the same demo briefs; not every HIPAA publication or OCR of image-only pages",
    }
    atomic_write(output / "documents.jsonl", data)
    atomic_write(output / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    catalogue = [{k: record[k] for k in (
        "id", "title", "kind", "source_url", "source_locator",
        "legal_status", "permitted_use", "retrieval_scope",
    )} for record in records]
    atomic_write(output / "catalogue.json", (json.dumps(catalogue, indent=2) + "\n").encode())
    verify(output, profile)
    print(json.dumps({k: manifest[k] for k in (
        "profile", "corpus_id", "documents", "text_bytes", "file_bytes", "document_kinds",
        "retrieval_scopes")}, indent=2))
    return output


def verify(path, expected_profile=None):
    manifest = json.loads((path / "manifest.json").read_text())
    if manifest["schema_version"] != SCHEMA:
        raise ValueError("Unsupported corpus schema")
    if expected_profile and manifest["profile"] != expected_profile:
        raise ValueError("Knowledge profile mismatch")
    data = (path / manifest["knowledge_file"]).read_bytes()
    if len(data) != manifest["file_bytes"] or digest(data) != manifest["corpus_id"]:
        raise ValueError("Corpus checksum or byte length mismatch")
    records = [json.loads(line) for line in data.splitlines()]
    if len(records) != manifest["documents"] or not records:
        raise ValueError("Corpus document count mismatch")
    if len({r["id"] for r in records}) != len(records):
        raise ValueError("Duplicate document IDs")
    if len({(r["kind"], r["content_sha256"]) for r in records}) != len(records):
        raise ValueError("Duplicate document content")
    for record in records:
        if not record["text"] or digest(record["text"].encode()) != record["content_sha256"]:
            raise ValueError("Document hash mismatch: " + record["id"])
        for field in ("source_url", "source_sha256", "source_locator",
                      "legal_status", "permitted_use", "source_version", "retrieval_scope"):
            if not record.get(field):
                raise ValueError("Missing provenance field: " + field)
    size = sum(len(r["text"].encode()) for r in records)
    if size != manifest["text_bytes"]:
        raise ValueError("Corpus text-size mismatch")
    if manifest.get("retrieval_scopes") != dict(sorted(Counter(
            r["retrieval_scope"] for r in records).items())):
        raise ValueError("Retrieval scope counts mismatch")
    if (manifest.get("default_retrieval_scopes") != DEFAULT_SCOPES
            or manifest.get("excluded_by_default") != BACKGROUND_SCOPES):
        raise ValueError("Unsafe retrieval scope policy")
    for record in records:
        if (record["kind"] not in KIND_SCOPES
                or record["retrieval_scope"] != KIND_SCOPES[record["kind"]]):
            raise ValueError("Invalid retrieval scope for document kind: " + record["id"])
    if REQUIRED_URLS - {r["source_url"] for r in records}:
        raise ValueError("Essential guidance missing")
    return manifest


def select(profile):
    source = DEMO if profile == "demo" else ARCHIVE / "prepared/full"
    manifest = verify(source, profile)
    LOCAL.mkdir(parents=True, exist_ok=True)
    # Pin both path and digest. Selection does not silently import or erase an IRIS index.
    selection = {
        "schema_version": SCHEMA, "profile": profile,
        "corpus_id": manifest["corpus_id"], "documents": manifest["documents"],
        "manifest": str((source / "manifest.json").relative_to(ROOT)),
        "documents_path": str((source / "documents.jsonl").relative_to(ROOT)),
        "index_key": "HIPAA_" + profile + "_" + manifest["corpus_id"][:12],
        "index_status": "not_imported",
    }
    atomic_write(LOCAL / "selection.json", (json.dumps(selection, indent=2) + "\n").encode())
    print(json.dumps(selection, indent=2))
    return selection


def selected():
    selection = json.loads((LOCAL / "selection.json").read_text())
    manifest_path = ROOT / selection["manifest"]
    manifest = verify(manifest_path.parent, selection["profile"])
    if manifest["corpus_id"] != selection["corpus_id"]:
        raise ValueError("Selected corpus changed; explicitly select the rebuilt corpus")
    if selection["documents_path"] != str(
            (manifest_path.parent / manifest["knowledge_file"]).relative_to(ROOT)):
        raise ValueError("Selected document path does not match the verified manifest")
    return selection


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=(
        "build", "verify", "select", "status", "release-check", "fetch-supplemental", "export"))
    parser.add_argument("--profile", choices=("demo", "full"), default="demo")
    parser.add_argument("--scope", choices=("default", "historical", "unreviewed"), default="default")
    parser.add_argument("--output", type=Path, help="New output path for scope-filtered JSONL")
    args = parser.parse_args()
    if args.command == "fetch-supplemental":
        fetch_supplemental()
    elif args.command == "build":
        build(args.profile)
    elif args.command == "verify":
        path = DEMO if args.profile == "demo" else ARCHIVE / "prepared/full"
        result = verify(path, args.profile)
        print(f"Verified {result['profile']}: {result['documents']} documents, "
              f"{result['text_bytes']:,} UTF-8 text bytes; corpus={result['corpus_id']}")
    elif args.command == "export":
        if args.output is None:
            raise ValueError("export requires --output")
        path = DEMO if args.profile == "demo" else ARCHIVE / "prepared/full"
        manifest = verify(path, args.profile)
        scopes = manifest["default_retrieval_scopes"] if args.scope == "default" else [args.scope]
        records = [json.loads(line) for line in
                   (path / manifest["knowledge_file"]).read_text().splitlines()]
        records = [r for r in records if r["retrieval_scope"] in scopes]
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as stream:
            for record in records:
                stream.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
        print(f"Exported {len(records)} records in scopes {scopes}; not imported into AI Hub")
    elif args.command == "select":
        select(args.profile)
    elif args.command == "release-check":
        verify(DEMO, "demo")
        selection = selected()
        if selection["profile"] != "demo":
            raise ValueError("Release requires explicit demo selection, not a full local corpus")
        print("Release knowledge inputs verified: demo selected. AI Hub indexing is a separate step.")
    else:
        print(json.dumps(selected(), indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, ET.ParseError, zipfile.BadZipFile,
            subprocess.CalledProcessError) as error:
        print("Knowledge preparation failed: " + str(error), file=sys.stderr)
        sys.exit(1)

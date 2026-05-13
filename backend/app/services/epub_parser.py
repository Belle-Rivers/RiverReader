import os
import re
import shutil
import zipfile
import hashlib
from uuid import UUID
from xml.etree import ElementTree as ET
from fastapi import UploadFile

from app.schemas import BookCreate, BookChapterCreate

# XML Namespaces used in EPUB
NS = {
    "container": "urn:oasis:names:tc:opendocument:xmlns:container",
    "opf": "http://www.idpf.org/2007/opf",
    "dc": "http://purl.org/dc/elements/1.1/",
    "ncx": "http://www.daisy.org/z3986/2005/ncx/"
}


def _clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = " ".join(value.split()).strip()
    return normalized or None


def _extract_chapter_title_from_html(content_html: str) -> str | None:
    title_match = re.search(r"<title[^>]*>(.*?)</title>", content_html, flags=re.IGNORECASE | re.DOTALL)
    if title_match:
        title_text = re.sub(r"<[^>]+>", " ", title_match.group(1))
        cleaned = _clean_text(title_text)
        if cleaned:
            return cleaned
    heading_match = re.search(r"<h1[^>]*>(.*?)</h1>", content_html, flags=re.IGNORECASE | re.DOTALL)
    if heading_match:
        heading_text = re.sub(r"<[^>]+>", " ", heading_match.group(1))
        cleaned = _clean_text(heading_text)
        if cleaned:
            return cleaned
    return None


def _extract_plain_text_from_html(content_html: str) -> str:
    without_scripts = re.sub(r"<script[^>]*>.*?</script>", " ", content_html, flags=re.IGNORECASE | re.DOTALL)
    without_styles = re.sub(r"<style[^>]*>.*?</style>", " ", without_scripts, flags=re.IGNORECASE | re.DOTALL)
    without_tags = re.sub(r"<[^>]+>", " ", without_styles)
    return _clean_text(without_tags) or ""


def _resolve_chapter_path(opf_dir: str, chapter_href: str) -> str:
    chapter_path = os.path.normpath(
        os.path.join(opf_dir, chapter_href) if opf_dir else chapter_href
    )
    return chapter_path.replace("\\", "/")


def _read_opf_tree(archive: zipfile.ZipFile) -> tuple[ET.Element, str]:
    container_xml = archive.read('META-INF/container.xml')
    container_tree = ET.fromstring(container_xml)
    rootfile = container_tree.find('.//container:rootfile', NS)
    if rootfile is None:
        raise ValueError("Invalid EPUB: no rootfile found in container.xml")
    opf_path = rootfile.get('full-path')
    if not opf_path:
        raise ValueError("Invalid EPUB: rootfile missing full-path")
    opf_data = archive.read(opf_path)
    opf_tree = ET.fromstring(opf_data)
    return opf_tree, opf_path

def parse_epub_file(file_path: str, user_id: UUID) -> BookCreate:
    with zipfile.ZipFile(file_path, 'r') as archive:
        opf_tree, opf_path = _read_opf_tree(archive)
        opf_dir = os.path.dirname(opf_path)
        
        metadata = opf_tree.find('opf:metadata', NS)
        title = metadata.find('dc:title', NS).text if metadata is not None and metadata.find('dc:title', NS) is not None else "Unknown Title"
        author = metadata.find('dc:creator', NS).text if metadata is not None and metadata.find('dc:creator', NS) is not None else None
        language = metadata.find('dc:language', NS).text if metadata is not None and metadata.find('dc:language', NS) is not None else None

        manifest = opf_tree.find('opf:manifest', NS)
        spine = opf_tree.find('opf:spine', NS)

        items: dict[str, str | None] = {}
        if manifest is not None:
            for item in manifest.findall('opf:item', NS):
                item_id = item.get('id')
                if item_id is not None:
                    items[item_id] = item.get('href')

        chapters = []
        if spine is not None:
            for idx, itemref in enumerate(spine.findall('opf:itemref', NS)):
                item_id = itemref.get('idref')
                href = items.get(item_id)
                if href:
                    chapter_path = _resolve_chapter_path(opf_dir, href)
                    chapter_title = None
                    try:
                        chapter_html = archive.read(chapter_path).decode("utf-8", errors="ignore")
                        chapter_title = _extract_chapter_title_from_html(chapter_html)
                    except Exception:
                        chapter_title = None
                    chapters.append(BookChapterCreate(
                        chapter_index=idx,
                        title=chapter_title or f"Chapter {idx + 1}",
                        href=href
                    ))

        # Calculate file hash
        hasher = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hasher.update(chunk)
        file_hash = hasher.hexdigest()

        return BookCreate(
            user_id=user_id,
            title=title,
            author=author,
            language=language,
            file_hash=file_hash,
            chapters=chapters
        )

async def save_upload_file(upload_file: UploadFile, destination: str) -> None:
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    with open(destination, "wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)


def extract_chapter_content(file_path: str, chapter_href: str) -> str:
    with zipfile.ZipFile(file_path, 'r') as archive:
        _, opf_path = _read_opf_tree(archive)
        opf_dir = os.path.dirname(opf_path)
        chapter_path = _resolve_chapter_path(opf_dir, chapter_href)
        chapter_data = archive.read(chapter_path)
        return chapter_data.decode("utf-8", errors="ignore")


def extract_chapter_text(file_path: str, chapter_href: str) -> str:
    chapter_html = extract_chapter_content(file_path, chapter_href)
    return _extract_plain_text_from_html(chapter_html)

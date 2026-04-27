"""Knowledge graph generator — ingests files and extracts entities/relations into Kuzu."""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

from kuzu_kb.graph import KuzuGraph

_TEXT_EXTENSIONS = {
    ".md", ".txt", ".py", ".js", ".ts", ".java", ".go", ".rs", ".rb",
    ".c", ".cpp", ".h", ".hpp", ".json", ".yaml", ".yml", ".toml",
    ".html", ".css", ".sh", ".bash", ".zsh", ".sql", ".r", ".swift",
}

_CHUNK_SIZE = 800  # chars per chunk (overlap-free for simplicity)

# --- Generic extraction patterns ---
_CAPITALIZED_PHRASE = re.compile(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b")
_BACKTICK_TERM = re.compile(r"`([^`]{2,60})`")
_HEADING = re.compile(r"^#{1,4}\s+(.+)$", re.MULTILINE)
_LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")

# --- SQL-specific extraction patterns ---
_SQL_CREATE_TABLE = re.compile(r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)", re.I)
_SQL_COLUMN = re.compile(r"^\s+(\w+)\s+(VARCHAR2|NUMBER|DATE|TIMESTAMP|CLOB|BLOB|CHAR|INTEGER|INT64|BOOLEAN|RAW)\b", re.I | re.M)
_SQL_FK = re.compile(r"FOREIGN\s+KEY\s*\((\w+)\)\s*REFERENCES\s+(\w+)\s*\((\w+)\)", re.I)
_SQL_CREATE_INDEX = re.compile(r"CREATE\s+(?:UNIQUE\s+)?INDEX\s+(\w+)\s+ON\s+(\w+)", re.I)
_SQL_CREATE_VIEW = re.compile(r"CREATE\s+(?:OR\s+REPLACE\s+)?(?:MATERIALIZED\s+)?VIEW\s+(\w+)", re.I)
_SQL_VIEW_FROM = re.compile(r"\bFROM\s+(\w+)\b", re.I)
_SQL_VIEW_JOIN = re.compile(r"\bJOIN\s+(\w+)\b", re.I)
_SQL_CREATE_SEQ = re.compile(r"CREATE\s+SEQUENCE\s+(\w+)", re.I)
_SQL_CREATE_PROC = re.compile(r"CREATE\s+(?:OR\s+REPLACE\s+)?PROCEDURE\s+(\w+)", re.I)
_SQL_CREATE_FUNC = re.compile(r"CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(\w+)", re.I)
_SQL_CREATE_PKG = re.compile(r"CREATE\s+(?:OR\s+REPLACE\s+)?PACKAGE\s+(?:BODY\s+)?(\w+)", re.I)
_SQL_CREATE_TRIGGER = re.compile(r"CREATE\s+(?:OR\s+REPLACE\s+)?TRIGGER\s+(\w+)", re.I)
_SQL_TRIGGER_ON = re.compile(r"ON\s+(\w+)\s*$", re.I | re.M)
_SQL_CREATE_TYPE = re.compile(r"CREATE\s+(?:OR\s+REPLACE\s+)?TYPE\s+(?:BODY\s+)?(\w+)", re.I)
_SQL_GRANT = re.compile(r"GRANT\s+\w+\s+ON\s+(\w+)\s+TO\s+(\w+)", re.I)
_SQL_INSERT = re.compile(r"INSERT\s+INTO\s+(\w+)", re.I)


def _chunk_text(text: str, size: int = _CHUNK_SIZE) -> list[str]:
    """Split text into chunks by paragraph boundaries, respecting size limit."""
    paragraphs = text.split("\n\n")
    chunks, current = [], ""
    for para in paragraphs:
        if len(current) + len(para) > size and current:
            chunks.append(current.strip())
            current = para
        else:
            current = f"{current}\n\n{para}" if current else para
    if current.strip():
        chunks.append(current.strip())
    return chunks or [text[:size]]


def _is_sql_file(path: str) -> bool:
    return path.lower().endswith(".sql")


def _extract_sql_entities(text: str) -> tuple[list[tuple[str, str]], list[tuple[str, str, str]]]:
    """Extract SQL-specific entities and relationships from the full file text."""
    entities = set()
    relations = []

    # Tables
    for m in _SQL_CREATE_TABLE.finditer(text):
        entities.add((m.group(1).lower(), "table"))

    # Columns — find them within CREATE TABLE blocks
    table_blocks = re.split(r"(?=CREATE\s+TABLE)", text, flags=re.I)
    for block in table_blocks:
        tm = _SQL_CREATE_TABLE.search(block)
        if not tm:
            continue
        tname = tm.group(1).lower()
        for cm in _SQL_COLUMN.finditer(block):
            col_name = cm.group(1).lower()
            col_type = cm.group(2).upper()
            full_name = f"{tname}.{col_name}"
            entities.add((full_name, "column"))
            relations.append((full_name, tname, "belongs_to"))

        # Foreign keys
        for fk in _SQL_FK.finditer(block):
            fk_col = fk.group(1).lower()
            ref_table = fk.group(2).lower()
            ref_col = fk.group(3).lower()
            entities.add((ref_table, "table"))
            relations.append((tname, ref_table, "references"))
            relations.append((f"{tname}.{fk_col}", f"{ref_table}.{ref_col}", "foreign_key"))

    # Indexes
    for m in _SQL_CREATE_INDEX.finditer(text):
        idx_name = m.group(1).lower()
        tbl_name = m.group(2).lower()
        entities.add((idx_name, "index"))
        relations.append((idx_name, tbl_name, "indexes"))

    # Views
    for m in _SQL_CREATE_VIEW.finditer(text):
        vname = m.group(1).lower()
        vtype = "materialized_view" if "MATERIALIZED" in text[max(0,m.start()-20):m.start()+20].upper() else "view"
        entities.add((vname, vtype))
        # Find source tables in the view body (rough: next 2000 chars)
        view_body = text[m.end():m.end()+3000]
        for ft in _SQL_VIEW_FROM.finditer(view_body):
            src = ft.group(1).lower()
            if src not in ("dual", "select", "case", "when", "null"):
                relations.append((vname, src, "reads_from"))
        for jt in _SQL_VIEW_JOIN.finditer(view_body):
            src = jt.group(1).lower()
            if src not in ("dual", "select", "case", "when", "null"):
                relations.append((vname, src, "reads_from"))

    # Sequences
    for m in _SQL_CREATE_SEQ.finditer(text):
        entities.add((m.group(1).lower(), "sequence"))

    # Procedures
    for m in _SQL_CREATE_PROC.finditer(text):
        entities.add((m.group(1).lower(), "procedure"))

    # Functions
    for m in _SQL_CREATE_FUNC.finditer(text):
        entities.add((m.group(1).lower(), "function"))

    # Packages
    seen_pkgs = set()
    for m in _SQL_CREATE_PKG.finditer(text):
        pname = m.group(1).lower()
        if pname not in seen_pkgs:
            entities.add((pname, "package"))
            seen_pkgs.add(pname)

    # Triggers
    trigger_blocks = re.split(r"(?=CREATE\s+(?:OR\s+REPLACE\s+)?TRIGGER)", text, flags=re.I)
    for block in trigger_blocks:
        tm = _SQL_CREATE_TRIGGER.search(block)
        if not tm:
            continue
        trig_name = tm.group(1).lower()
        entities.add((trig_name, "trigger"))
        on_match = _SQL_TRIGGER_ON.search(block[:500])
        if on_match:
            tbl = on_match.group(1).lower()
            relations.append((trig_name, tbl, "fires_on"))

    # Types
    for m in _SQL_CREATE_TYPE.finditer(text):
        entities.add((m.group(1).lower(), "type"))

    # Grants
    for m in _SQL_GRANT.finditer(text):
        obj = m.group(1).lower()
        role = m.group(2).lower()
        entities.add((role, "role"))
        relations.append((role, obj, "granted_access_to"))

    # Inserts (track which tables have data)
    for m in _SQL_INSERT.finditer(text):
        tbl = m.group(1).lower()
        entities.add((tbl, "table"))

    return list(entities), relations


def _extract_entities(text: str) -> list[tuple[str, str]]:
    """Extract (name, type) pairs from text using heuristics."""
    entities = set()
    for m in _HEADING.finditer(text):
        entities.add((m.group(1).strip(), "topic"))
    for m in _BACKTICK_TERM.finditer(text):
        entities.add((m.group(1).strip(), "code_term"))
    for m in _CAPITALIZED_PHRASE.finditer(text):
        name = m.group(1).strip()
        if len(name) > 3:
            entities.add((name, "concept"))
    for m in _LINK.finditer(text):
        entities.add((m.group(1).strip(), "reference"))
    return list(entities)


def _extract_relations(entities: list[tuple[str, str]], text: str) -> list[tuple[str, str, str]]:
    """Extract co-occurrence relations between entities found in the same chunk."""
    names = [e[0] for e in entities]
    relations = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if a != b:
                relations.append((a, b, "co_occurs_with"))
    return relations


def ingest_directory(directory: str | Path, db_path: str | Path = "./kuzu_db") -> dict:
    """Ingest all text files from a directory into the knowledge graph."""
    graph = KuzuGraph(db_path)
    directory = Path(directory)
    stats = {"files": 0, "chunks": 0, "entities": 0, "relations": 0}

    for fpath in sorted(directory.rglob("*")):
        if not fpath.is_file() or fpath.suffix.lower() not in _TEXT_EXTENSIONS:
            continue
        if any(p.startswith(".") for p in fpath.parts):
            continue

        try:
            text = fpath.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        rel_path = str(fpath.relative_to(directory))
        graph.upsert_document(rel_path, fpath.stem, fpath.suffix.lstrip("."))
        stats["files"] += 1

        # SQL files: extract structured entities from the full file first
        if _is_sql_file(rel_path):
            sql_entities, sql_relations = _extract_sql_entities(text)
            sql_entity_names = {name for name, _ in sql_entities}
            for name, etype in sql_entities:
                graph.upsert_entity(name, etype)
                stats["entities"] += 1
            for a, b, rel in sql_relations:
                # Ensure both endpoints exist, but don't overwrite known types
                if a not in sql_entity_names:
                    graph.upsert_entity(a, "unknown")
                if b not in sql_entity_names:
                    graph.upsert_entity(b, "unknown")
                graph.add_relation(a, b, rel)
                stats["relations"] += 1

        # Chunk and do generic extraction
        chunks = _chunk_text(text)
        for idx, chunk in enumerate(chunks):
            chunk_id = hashlib.md5(f"{rel_path}:{idx}".encode()).hexdigest()[:12]
            graph.upsert_chunk(chunk_id, chunk, rel_path, idx)
            stats["chunks"] += 1

            entities = _extract_entities(chunk)
            for name, etype in entities:
                graph.upsert_entity(name, etype)
                graph.add_mention(chunk_id, name)
                stats["entities"] += 1

            for a, b, rel in _extract_relations(entities, chunk):
                graph.add_relation(a, b, rel)
                stats["relations"] += 1

            # For SQL chunks, also link SQL entities mentioned in this chunk
            if _is_sql_file(rel_path):
                chunk_lower = chunk.lower()
                for name, etype in sql_entities:
                    if name in chunk_lower:
                        graph.add_mention(chunk_id, name)

    return stats


def main():
    if len(sys.argv) < 2:
        print("Usage: kuzu-kb-ingest <directory> [db_path]")
        sys.exit(1)
    directory = sys.argv[1]
    db_path = sys.argv[2] if len(sys.argv) > 2 else "./kuzu_db"
    print(f"Ingesting {directory} → {db_path}")
    stats = ingest_directory(directory, db_path)
    print(f"Done: {stats}")


if __name__ == "__main__":
    main()

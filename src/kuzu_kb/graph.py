"""Kuzu graph database layer for the knowledge base."""
from __future__ import annotations

import kuzu
from pathlib import Path

_SCHEMA_STATEMENTS = [
    # Node tables
    "CREATE NODE TABLE IF NOT EXISTS Document(path STRING, title STRING, doc_type STRING, PRIMARY KEY(path))",
    "CREATE NODE TABLE IF NOT EXISTS Chunk(id STRING, text STRING, doc_path STRING, chunk_index INT64, PRIMARY KEY(id))",
    "CREATE NODE TABLE IF NOT EXISTS Entity(name STRING, entity_type STRING, PRIMARY KEY(name))",
    # Relationship tables
    "CREATE REL TABLE IF NOT EXISTS HAS_CHUNK(FROM Document TO Chunk)",
    "CREATE REL TABLE IF NOT EXISTS MENTIONS(FROM Chunk TO Entity)",
    "CREATE REL TABLE IF NOT EXISTS RELATES_TO(FROM Entity TO Entity, relation STRING)",
]


class KuzuGraph:
    def __init__(self, db_path: str | Path = "./kuzu_db"):
        self.db = kuzu.Database(str(db_path))
        self.conn = kuzu.Connection(self.db)
        self._init_schema()

    def _init_schema(self):
        for stmt in _SCHEMA_STATEMENTS:
            self.conn.execute(stmt)

    def _execute(self, query: str, params: dict | None = None):
        return self.conn.execute(query, params or {})

    # --- Document CRUD ---
    def upsert_document(self, path: str, title: str, doc_type: str):
        self._execute(
            "MERGE (d:Document {path: $path}) SET d.title = $title, d.doc_type = $doc_type",
            {"path": path, "title": title, "doc_type": doc_type},
        )

    def upsert_chunk(self, chunk_id: str, text: str, doc_path: str, chunk_index: int):
        self._execute(
            "MERGE (c:Chunk {id: $id}) SET c.text = $text, c.doc_path = $doc_path, c.chunk_index = $idx",
            {"id": chunk_id, "text": text, "doc_path": doc_path, "idx": chunk_index},
        )
        self._execute(
            "MATCH (d:Document {path: $dp}), (c:Chunk {id: $cid}) MERGE (d)-[:HAS_CHUNK]->(c)",
            {"dp": doc_path, "cid": chunk_id},
        )

    def upsert_entity(self, name: str, entity_type: str):
        self._execute(
            "MERGE (e:Entity {name: $name}) SET e.entity_type = $etype",
            {"name": name, "etype": entity_type},
        )

    def add_mention(self, chunk_id: str, entity_name: str):
        self._execute(
            "MATCH (c:Chunk {id: $cid}), (e:Entity {name: $en}) MERGE (c)-[:MENTIONS]->(e)",
            {"cid": chunk_id, "en": entity_name},
        )

    def add_relation(self, from_entity: str, to_entity: str, relation: str):
        self._execute(
            "MATCH (a:Entity {name: $a}), (b:Entity {name: $b}) MERGE (a)-[:RELATES_TO {relation: $r}]->(b)",
            {"a": from_entity, "b": to_entity, "r": relation},
        )

    # --- Helpers ---
    @staticmethod
    def _rows(result) -> list[list]:
        rows = []
        while result.has_next():
            rows.append(result.get_next())
        return rows

    # --- Queries ---
    def search_entities(self, query: str, limit: int = 20) -> list[dict]:
        if query:
            result = self._execute(
                "MATCH (e:Entity) WHERE lower(e.name) CONTAINS $q RETURN e.name, e.entity_type LIMIT $lim",
                {"q": query.lower(), "lim": limit},
            )
        else:
            result = self._execute("MATCH (e:Entity) RETURN e.name, e.entity_type LIMIT $lim", {"lim": limit})
        return [{"name": r[0], "type": r[1]} for r in self._rows(result)]

    def search_chunks(self, query: str, limit: int = 10) -> list[dict]:
        if query:
            result = self._execute(
                "MATCH (c:Chunk) WHERE lower(c.text) CONTAINS $q RETURN c.id, c.text, c.doc_path LIMIT $lim",
                {"q": query.lower(), "lim": limit},
            )
        else:
            result = self._execute("MATCH (c:Chunk) RETURN c.id, c.text, c.doc_path LIMIT $lim", {"lim": limit})
        return [{"id": r[0], "text": r[1], "doc_path": r[2]} for r in self._rows(result)]

    def get_entity_context(self, entity_name: str) -> dict:
        """Get an entity with its relationships and mentions."""
        rels = self._rows(self._execute(
            "MATCH (a:Entity)-[r:RELATES_TO]->(b:Entity) WHERE lower(a.name) = $n RETURN b.name, r.relation",
            {"n": entity_name.lower()},
        ))
        mentions = self._rows(self._execute(
            "MATCH (c:Chunk)-[:MENTIONS]->(e:Entity) WHERE lower(e.name) = $n RETURN c.text, c.doc_path LIMIT 5",
            {"n": entity_name.lower()},
        ))
        return {
            "entity": entity_name,
            "relations": [{"target": r[0], "relation": r[1]} for r in rels],
            "mentioned_in": [{"text": r[0], "doc": r[1]} for r in mentions],
        }

    def get_neighbors(self, entity_name: str, hops: int = 2) -> list[dict]:
        result = self._execute(
            f"MATCH (a:Entity)-[r:RELATES_TO*1..{hops}]->(b:Entity) WHERE lower(a.name) = $n "
            "RETURN DISTINCT b.name, b.entity_type",
            {"n": entity_name.lower()},
        )
        return [{"name": r[0], "type": r[1]} for r in self._rows(result)]

    def run_cypher(self, query: str) -> list[dict]:
        result = self._execute(query)
        cols = result.get_column_names()
        return [dict(zip(cols, r)) for r in self._rows(result)]

    def stats(self) -> dict:
        docs = self._rows(self._execute("MATCH (d:Document) RETURN count(d)"))[0][0]
        chunks = self._rows(self._execute("MATCH (c:Chunk) RETURN count(c)"))[0][0]
        entities = self._rows(self._execute("MATCH (e:Entity) RETURN count(e)"))[0][0]
        return {"documents": int(docs), "chunks": int(chunks), "entities": int(entities)}

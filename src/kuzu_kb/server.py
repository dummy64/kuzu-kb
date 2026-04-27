"""MCP server exposing Kuzu knowledge base search tools."""
from __future__ import annotations

import os
from fastmcp import FastMCP
from kuzu_kb.graph import KuzuGraph
from kuzu_kb.generator import ingest_directory
from kuzu_kb.visualize import generate_html

_DB_PATH = os.environ.get("KUZU_DB_PATH", "./kuzu_db")

mcp = FastMCP("kuzu-kb", instructions="Search and query a local knowledge graph built from your documents.")


def _graph() -> KuzuGraph:
    return KuzuGraph(_DB_PATH)


@mcp.tool()
def search_entities(query: str, limit: int = 20) -> list[dict]:
    """Search for entities in the knowledge graph by name substring match."""
    return _graph().search_entities(query, limit)


@mcp.tool()
def search_chunks(query: str, limit: int = 10) -> list[dict]:
    """Full-text search across document chunks. Returns matching text with source document path."""
    return _graph().search_chunks(query, limit)


@mcp.tool()
def get_entity_context(entity_name: str) -> dict:
    """Get an entity's relationships and the document chunks where it is mentioned."""
    return _graph().get_entity_context(entity_name)


@mcp.tool()
def get_neighbors(entity_name: str, hops: int = 2) -> list[dict]:
    """Get entities connected to the given entity within N hops in the graph."""
    return _graph().get_neighbors(entity_name, hops)


@mcp.tool()
def ingest(directory: str, db_path: str | None = None) -> dict:
    """Ingest all text files from a directory into the knowledge graph. Returns ingestion stats."""
    return ingest_directory(directory, db_path or _DB_PATH)


@mcp.tool()
def graph_stats() -> dict:
    """Get counts of documents, chunks, and entities in the knowledge graph."""
    return _graph().stats()


@mcp.tool()
def cypher_query(query: str) -> list[dict]:
    """Run a raw Cypher query against the knowledge graph. Use for advanced queries."""
    return _graph().run_cypher(query)


@mcp.tool()
def visualize(output_path: str = "knowledge_graph.html", exclude_columns: bool = False) -> str:
    """Generate an interactive HTML visualization of the knowledge graph. Returns the file path."""
    return generate_html(_DB_PATH, output_path, exclude_columns)


def main():
    mcp.run()


if __name__ == "__main__":
    main()

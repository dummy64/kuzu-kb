# kuzu-kb

Local knowledge base generator powered by [Kuzu](https://kuzudb.com/) graph database, exposed as an MCP server.

Ingests source code, SQL schemas, markdown, and other text files — extracts entities and relationships into a property graph you can query via Cypher or MCP tools.

## Requirements

- Python 3.10+
- pip

## Installation

```bash
# Clone / navigate to the project
cd kuzu-kb

# Create a virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install
pip install -e .
```

## Indexing a Repository

### CLI

```bash
# Index any directory into a Kuzu database
kuzu-kb-ingest /path/to/your/repo ./my_kb

# Examples
kuzu-kb-ingest ~/projects/my-app ./my_app_kb
kuzu-kb-ingest ./sample_data ./sql_kb
```

The first argument is the directory to scan, the second is where the Kuzu database will be stored.

### What gets indexed

**Supported file types:** `.py`, `.js`, `.ts`, `.java`, `.go`, `.rs`, `.rb`, `.c`, `.cpp`, `.h`, `.sql`, `.md`, `.txt`, `.json`, `.yaml`, `.yml`, `.toml`, `.html`, `.css`, `.sh`, `.swift`, `.r`

**Generic extraction (all files):**
- Markdown headings → `topic` entities
- Backtick terms → `code_term` entities
- Capitalized phrases → `concept` entities
- Markdown links → `reference` entities
- Co-occurrence relations between entities in the same chunk

**SQL-specific extraction (`.sql` files):**
- Tables, columns, and column-to-table `belongs_to` relations
- Foreign key `references` and column-level `foreign_key` links
- Views / materialized views and their `reads_from` source tables
- Procedures, functions, packages
- Triggers and their `fires_on` target tables
- Indexes and their `indexes` target tables
- Sequences, custom types
- Roles and `granted_access_to` relations from GRANT statements

### Re-indexing

To re-index, delete the database directory and run again:

```bash
rm -rf ./my_kb
kuzu-kb-ingest /path/to/repo ./my_kb
```

## Visualizing the Knowledge Graph

Generate an interactive HTML graph you can open in any browser:

```bash
# Full graph (all entities including columns)
kuzu-kb-visualize ./my_kb graph.html

# Without columns (cleaner for large SQL schemas)
kuzu-kb-visualize ./my_kb graph.html --no-columns
```

The HTML file is self-contained (uses a CDN for the force-graph library) and features:
- Force-directed graph layout
- Color-coded nodes by entity type
- Click any node to see its relationships
- Search box to filter entities by name
- Legend to filter by entity type
- Node count and edge count stats

This is also available as an MCP tool (`visualize`) so an AI assistant can generate it on demand.

## MCP Server

### Running standalone

```bash
# Set the database path and run
KUZU_DB_PATH=./my_kb kuzu-kb-server
```

### Adding to an MCP client

Add to your MCP client config (e.g. `~/.kiro/settings.json`, Claude Desktop, Cursor, etc.):

```json
{
  "mcpServers": {
    "kuzu-kb": {
      "command": "/absolute/path/to/kuzu-kb/.venv/bin/python",
      "args": ["-m", "kuzu_kb.server"],
      "env": {
        "KUZU_DB_PATH": "/absolute/path/to/my_kb"
      }
    }
  }
}
```

Or using the installed script:

```json
{
  "mcpServers": {
    "kuzu-kb": {
      "command": "/absolute/path/to/kuzu-kb/.venv/bin/kuzu-kb-server",
      "env": {
        "KUZU_DB_PATH": "/absolute/path/to/my_kb"
      }
    }
  }
}
```

### Available MCP Tools

| Tool | Description |
|---|---|
| `ingest` | Ingest a directory of files into the knowledge graph |
| `search_entities` | Find entities by name (substring match) |
| `search_chunks` | Full-text search across document chunks |
| `get_entity_context` | Get an entity's relationships and source chunks |
| `get_neighbors` | Multi-hop graph traversal from an entity |
| `graph_stats` | Get document, chunk, and entity counts |
| `cypher_query` | Run raw Cypher queries for advanced use |
| `visualize` | Generate an interactive HTML graph visualization |

### Example MCP queries

```
"Search for all tables in the knowledge graph"
→ search_entities(query="", limit=100) then filter by type, or:
→ cypher_query("MATCH (e:Entity {entity_type: 'table'}) RETURN e.name")

"What does the orders table reference?"
→ cypher_query("MATCH (a:Entity {name: 'orders'})-[r:RELATES_TO {relation: 'references'}]->(b:Entity) RETURN b.name")

"Which views read from the customers table?"
→ cypher_query("MATCH (v:Entity)-[r:RELATES_TO {relation: 'reads_from'}]->(t:Entity {name: 'customers'}) RETURN v.name")

"Find all triggers"
→ cypher_query("MATCH (e:Entity {entity_type: 'trigger'}) RETURN e.name")
```

## Graph Schema

```
Node tables:
  Document  (path, title, doc_type)
  Chunk     (id, text, doc_path, chunk_index)
  Entity    (name, entity_type)

Relationship tables:
  HAS_CHUNK    Document → Chunk
  MENTIONS     Chunk → Entity
  RELATES_TO   Entity → Entity  (with 'relation' property)
```

Relation types on `RELATES_TO`: `references`, `belongs_to`, `foreign_key`, `reads_from`, `fires_on`, `indexes`, `granted_access_to`, `co_occurs_with`.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `KUZU_DB_PATH` | `./kuzu_db` | Path to the Kuzu database directory |

## License

MIT

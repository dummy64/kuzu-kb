"""Generate an interactive HTML visualization of the knowledge graph."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from kuzu_kb.graph import KuzuGraph

_TYPE_COLORS = {
    "table": "#4CAF50",
    "column": "#90CAF9",
    "view": "#FF9800",
    "materialized_view": "#FF5722",
    "procedure": "#9C27B0",
    "function": "#E91E63",
    "package": "#673AB7",
    "trigger": "#F44336",
    "index": "#607D8B",
    "sequence": "#795548",
    "type": "#009688",
    "role": "#FFC107",
    "topic": "#2196F3",
    "concept": "#03A9F4",
    "code_term": "#00BCD4",
    "reference": "#8BC34A",
    "unknown": "#BDBDBD",
}

_HTML_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Knowledge Graph — {title}</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0d1117; color: #c9d1d9; overflow: hidden; }}
  #container {{ width: 100vw; height: 100vh; }}
  #controls {{ position: fixed; top: 12px; left: 12px; z-index: 10; background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 12px; max-width: 280px; }}
  #controls h3 {{ margin-bottom: 8px; font-size: 14px; color: #58a6ff; }}
  #search {{ width: 100%; padding: 6px 8px; background: #0d1117; border: 1px solid #30363d; border-radius: 4px; color: #c9d1d9; font-size: 13px; margin-bottom: 8px; }}
  #legend {{ display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 8px; }}
  .legend-item {{ font-size: 11px; padding: 2px 6px; border-radius: 3px; cursor: pointer; opacity: 0.85; }}
  .legend-item:hover {{ opacity: 1; }}
  .legend-item.dimmed {{ opacity: 0.3; }}
  #info {{ position: fixed; bottom: 12px; left: 12px; z-index: 10; background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 10px; font-size: 12px; max-width: 350px; max-height: 250px; overflow-y: auto; display: none; }}
  #info h4 {{ color: #58a6ff; margin-bottom: 4px; }}
  #info .rel {{ color: #8b949e; }}
  #stats {{ position: fixed; top: 12px; right: 12px; z-index: 10; background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 10px; font-size: 12px; }}
</style>
</head>
<body>
<div id="container"></div>
<div id="controls">
  <h3>🔍 Knowledge Graph</h3>
  <input id="search" type="text" placeholder="Search entities...">
  <div id="legend"></div>
</div>
<div id="info"></div>
<div id="stats"></div>
<script src="https://unpkg.com/force-graph@1.47.4/dist/force-graph.min.js"></script>
<script>
const data = {graph_json};

// Build legend
const types = [...new Set(data.nodes.map(n => n.type))].sort();
const colors = {colors_json};
const legendEl = document.getElementById('legend');
let activeFilter = null;
types.forEach(t => {{
  const el = document.createElement('span');
  el.className = 'legend-item';
  el.style.background = colors[t] || '#666';
  el.style.color = '#fff';
  el.textContent = t + ' (' + data.nodes.filter(n => n.type === t).length + ')';
  el.onclick = () => {{
    if (activeFilter === t) {{ activeFilter = null; }} else {{ activeFilter = t; }}
    document.querySelectorAll('.legend-item').forEach(e => e.classList.toggle('dimmed', activeFilter && !e.textContent.startsWith(activeFilter)));
    graph.nodeVisibility(n => !activeFilter || n.type === activeFilter);
    graph.linkVisibility(l => {{
      if (!activeFilter) return true;
      const s = typeof l.source === 'object' ? l.source : data.nodes.find(n => n.id === l.source);
      const t2 = typeof l.target === 'object' ? l.target : data.nodes.find(n => n.id === l.target);
      return s && t2 && (s.type === activeFilter || t2.type === activeFilter);
    }});
  }};
  legendEl.appendChild(el);
}});

// Stats
document.getElementById('stats').innerHTML = `Nodes: ${{data.nodes.length}} &nbsp;|&nbsp; Edges: ${{data.links.length}}`;

// Graph
const graph = ForceGraph()(document.getElementById('container'))
  .graphData(data)
  .nodeId('id')
  .nodeLabel(n => `${{n.id}} (${{n.type}})`)
  .nodeColor(n => colors[n.type] || '#666')
  .nodeVal(n => n.type === 'table' ? 6 : n.type === 'column' ? 1 : 3)
  .nodeCanvasObject((node, ctx, globalScale) => {{
    const label = node.id;
    const size = node.type === 'table' ? 6 : node.type === 'column' ? 2 : 4;
    const fontSize = Math.max(10 / globalScale, 2);
    const color = colors[node.type] || '#666';

    // Draw node circle
    ctx.beginPath();
    ctx.arc(node.x, node.y, size, 0, 2 * Math.PI);
    ctx.fillStyle = color;
    ctx.fill();

    // Draw label
    ctx.font = `${{fontSize}}px Sans-Serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillStyle = '#c9d1d9';
    ctx.fillText(label, node.x, node.y + size + 1);
  }})
  .nodePointerAreaPaint((node, color, ctx) => {{
    const size = node.type === 'table' ? 6 : node.type === 'column' ? 2 : 4;
    ctx.beginPath();
    ctx.arc(node.x, node.y, size + 4, 0, 2 * Math.PI);
    ctx.fillStyle = color;
    ctx.fill();
  }})
  .linkLabel(l => l.relation)
  .linkColor(() => '#30363d')
  .linkDirectionalArrowLength(3)
  .linkDirectionalArrowRelPos(1)
  .backgroundColor('#0d1117')
  .onNodeClick(node => {{
    const info = document.getElementById('info');
    const rels = data.links.filter(l => {{
      const sid = typeof l.source === 'object' ? l.source.id : l.source;
      const tid = typeof l.target === 'object' ? l.target.id : l.target;
      return sid === node.id || tid === node.id;
    }});
    let html = `<h4>${{node.id}}</h4><div>Type: ${{node.type}}</div><br>`;
    if (rels.length) {{
      html += '<div class="rel"><b>Relations:</b></div>';
      rels.slice(0, 30).forEach(l => {{
        const sid = typeof l.source === 'object' ? l.source.id : l.source;
        const tid = typeof l.target === 'object' ? l.target.id : l.target;
        html += `<div class="rel">${{sid}} —<i>${{l.relation}}</i>→ ${{tid}}</div>`;
      }});
      if (rels.length > 30) html += `<div class="rel">... and ${{rels.length - 30}} more</div>`;
    }}
    info.innerHTML = html;
    info.style.display = 'block';
  }});

// Search
document.getElementById('search').addEventListener('input', e => {{
  const q = e.target.value.toLowerCase();
  if (!q) {{ graph.nodeVisibility(() => true); graph.linkVisibility(() => true); return; }}
  graph.nodeVisibility(n => n.id.toLowerCase().includes(q));
  graph.linkVisibility(l => {{
    const s = typeof l.source === 'object' ? l.source : data.nodes.find(n => n.id === l.source);
    const t = typeof l.target === 'object' ? l.target : data.nodes.find(n => n.id === l.target);
    return s && t && (s.id.toLowerCase().includes(q) || t.id.toLowerCase().includes(q));
  }});
}});
</script>
</body>
</html>
"""


def generate_html(db_path: str | Path, output: str | Path = "knowledge_graph.html", exclude_columns: bool = False) -> str:
    """Generate an interactive HTML visualization from a Kuzu knowledge graph."""
    g = KuzuGraph(db_path)

    # Fetch entities
    type_filter = "AND e.entity_type <> 'column'" if exclude_columns else ""
    nodes_raw = g.run_cypher(f"MATCH (e:Entity) WHERE e.name IS NOT NULL {type_filter} RETURN e.name, e.entity_type")
    nodes = [{"id": r["e.name"], "type": r["e.entity_type"]} for r in nodes_raw]
    node_ids = {n["id"] for n in nodes}

    # Fetch relations
    links_raw = g.run_cypher(
        "MATCH (a:Entity)-[r:RELATES_TO]->(b:Entity) RETURN a.name, b.name, r.relation"
    )
    links = [
        {"source": r["a.name"], "target": r["b.name"], "relation": r["r.relation"]}
        for r in links_raw
        if r["a.name"] in node_ids and r["b.name"] in node_ids
    ]

    stats = g.stats()
    title = f"{stats['entities']} entities, {stats['documents']} docs"

    html = _HTML_TEMPLATE.format(
        title=title,
        graph_json=json.dumps({"nodes": nodes, "links": links}),
        colors_json=json.dumps(_TYPE_COLORS),
    )

    output = Path(output)
    output.write_text(html, encoding="utf-8")
    return str(output.resolve())


def main():
    if len(sys.argv) < 2:
        print("Usage: kuzu-kb-visualize <db_path> [output.html] [--no-columns]")
        sys.exit(1)
    db_path = sys.argv[1]
    output = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("-") else "knowledge_graph.html"
    exclude_columns = "--no-columns" in sys.argv
    path = generate_html(db_path, output, exclude_columns)
    print(f"Generated: {path}")


if __name__ == "__main__":
    main()

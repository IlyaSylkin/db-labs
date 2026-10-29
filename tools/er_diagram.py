#!/usr/bin/env python3
"""ER-диаграмма текущей базы с линиями от столбца FK к столбцу, на который он ссылается.

Структура читается из каталога PostgreSQL (контейнер из docker-compose.yml),
диаграмма рисуется Graphviz.

    python3 tools/er_diagram.py lab2/er-diagram     # → lab2/er-diagram.dot и .png
"""
import subprocess
import sys
from collections import defaultdict
from html import escape
from pathlib import Path

COLUMNS_SQL = """
SELECT c.relname, a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull
FROM pg_attribute a
JOIN pg_class c     ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY c.relname, a.attnum
"""

# Столбцы ограничения в порядке объявления: для составных FK пары (conkey[i], confkey[i]).
CONSTRAINTS_SQL = """
SELECT con.contype, con.conname, src.relname,
       (SELECT string_agg(a.attname, ',' ORDER BY k.ord)
        FROM unnest(con.conkey) WITH ORDINALITY AS k (num, ord)
        JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.num),
       COALESCE(dst.relname, ''),
       COALESCE((SELECT string_agg(a.attname, ',' ORDER BY k.ord)
                 FROM unnest(con.confkey) WITH ORDINALITY AS k (num, ord)
                 JOIN pg_attribute a ON a.attrelid = con.confrelid AND a.attnum = k.num), '')
FROM pg_constraint con
JOIN pg_class src     ON src.oid = con.conrelid
JOIN pg_namespace n   ON n.oid = src.relnamespace
LEFT JOIN pg_class dst ON dst.oid = con.confrelid
WHERE n.nspname = 'public' AND con.contype IN ('p', 'f', 'u')
ORDER BY src.relname, con.conname
"""

EDGE_COLORS = ["#2b6cb0", "#c05621", "#2f855a", "#9b2c2c", "#6b46c1",
               "#b7791f", "#2c7a7b", "#b83280", "#4a5568"]


def short_type(col_type):
    return (col_type.replace("character varying", "varchar")
                    .replace("timestamp with time zone", "timestamptz"))


def query(sql):
    out = subprocess.run(
        ["docker", "compose", "exec", "-T", "db",
         "psql", "-U", "student", "-d", "labs", "-At", "-F", "\t", "-c", sql],
        check=True, capture_output=True, text=True,
    ).stdout
    return [line.split("\t") for line in out.splitlines() if line]


def build_dot():
    columns = defaultdict(list)
    for table, name, col_type, not_null in query(COLUMNS_SQL):
        columns[table].append((name, col_type, not_null == "t"))

    marks = defaultdict(set)   # (таблица, столбец) → {PK, FK, UK}
    fks = []
    for kind, name, table, cols, ref_table, ref_cols in query(CONSTRAINTS_SQL):
        cols = cols.split(",")
        if kind == "p":
            for c in cols:
                marks[table, c].add("PK")
        elif kind == "u" and len(cols) == 1:
            marks[table, cols[0]].add("UK")
        elif kind == "f":
            for c in cols:
                marks[table, c].add("FK")
            fks.append((name, table, cols, ref_table, ref_cols.split(",")))

    lines = [
        "digraph er {",
        "  graph [rankdir=LR, splines=spline, nodesep=0.5, ranksep=1.4, fontname=Arial];",
        "  node  [shape=plain, fontname=Arial, fontsize=11];",
        "  edge  [dir=both, penwidth=1.3, arrowsize=0.8];",
    ]
    for table, cols in columns.items():
        rows = [f'<TR><TD COLSPAN="3" BGCOLOR="#ebf4ff"><B>{table}</B></TD></TR>']
        for name, col_type, not_null in cols:
            key = ", ".join(m for m in ("PK", "FK", "UK") if m in marks[table, name])
            label = f"<B>{escape(name)}</B>" if "PK" in marks[table, name] else escape(name)
            star = "* " if not_null else ""
            key = f'<FONT COLOR="#718096">{key}</FONT>' if key else " "  # пустой FONT Graphviz не принимает
            # Порты на крайних ячейках: линия FK выходит справа, в PK входит слева.
            rows.append(
                f'<TR><TD ALIGN="LEFT" PORT="{name}_w">{key}</TD>'
                f'<TD ALIGN="LEFT">{star}{label}</TD>'
                f'<TD ALIGN="LEFT" PORT="{name}_e"><FONT COLOR="#718096">{escape(short_type(col_type))}</FONT></TD></TR>'
            )
        lines.append(
            f'  {table} [label=<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" '
            f'CELLPADDING="4" COLOR="#2b6cb0">{"".join(rows)}</TABLE>>];'
        )

    not_null = {(t, n) for t, cols in columns.items() for n, _, nn in cols if nn}
    for i, (name, table, cols, ref_table, ref_cols) in enumerate(fks):
        color = EDGE_COLORS[i % len(EDGE_COLORS)]
        # Crow's Foot: у FK «много» (может быть ноль), у PK «ровно один» или «ноль или один»
        optional = any((table, c) not in not_null for c in cols)
        head = "teeodot" if optional else "teetee"
        for c, rc in zip(cols, ref_cols):
            lines.append(
                f'  {table}:{c}_e:e -> {ref_table}:{rc}_w:w '
                f'[color="{color}", arrowtail=crowodot, arrowhead={head}, tooltip="{name}"];'
            )
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "er-diagram")
    dot_file = out.with_suffix(".dot")
    dot_file.write_text(build_dot(), encoding="utf-8")
    subprocess.run(["dot", "-Tpng", "-Gdpi=110", str(dot_file), "-o", str(out.with_suffix(".png"))],
                   check=True)
    print(f"{dot_file}, {out.with_suffix('.png')}")


if __name__ == "__main__":
    main()

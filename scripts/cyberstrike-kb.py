#!/opt/toolchains/python-apps/cyberstrike-kb/bin/python
"""Build and query local hybrid vector knowledge bases for Hermes."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator, Sequence


DEFAULT_MODEL = "BAAI/bge-small-en-v1.5"
DEFAULT_LIMIT = 6
MAX_CHUNK_CHARS = 1800
OVERLAP_LINES = 4
SCHEMA_VERSION = "1"
PROGRAM_NAME = Path(sys.argv[0]).name
DEFAULT_CORPUS = "all" if PROGRAM_NAME == "workstation-kb" else "cyberstrike"


@dataclass(frozen=True)
class Chunk:
    path: str
    start_line: int
    end_line: int
    heading: str
    content: str
    authority: int
    authority_label: str


def fail(message: str) -> "NoReturn":
    print(f"{PROGRAM_NAME}: {message}", file=sys.stderr)
    raise SystemExit(1)


def resolve_skill_root(explicit: str | None) -> Path:
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("CYBERSTRIKE_KB_SKILL_ROOT"):
        candidates.append(Path(os.environ["CYBERSTRIKE_KB_SKILL_ROOT"]))
    candidates.extend(
        [
            Path("/opt/data/skills/cybersecurity/offensive-workstation"),
            Path(
                "/usr/local/share/hermes/skills/cybersecurity/"
                "offensive-workstation"
            ),
            Path(__file__).resolve().parents[1]
            / "knowledge/skills/offensive-workstation-pentesting",
        ]
    )
    for candidate in candidates:
        if (candidate / "SKILL.md").is_file():
            return candidate.resolve()
    fail("could not locate the offensive-workstation Hermes skill")


def resolve_database(explicit: str | None, corpus: str) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    if corpus == "all" and os.environ.get("WORKSTATION_KB_DB"):
        return Path(os.environ["WORKSTATION_KB_DB"]).expanduser().resolve()
    if corpus == "cyberstrike" and os.environ.get("CYBERSTRIKE_KB_DB"):
        return Path(os.environ["CYBERSTRIKE_KB_DB"]).expanduser().resolve()
    hermes_home = Path(
        os.environ.get("HERMES_HOME", str(Path.home() / ".hermes"))
    )
    if corpus == "all":
        return (
            hermes_home / "knowledge/offensive-workstation/workstation-kb.sqlite3"
        ).resolve()
    return (
        hermes_home / "knowledge/cyberstrike/cyberstrike-kb.sqlite3"
    ).resolve()


def authority_for(relative: str) -> tuple[int, str]:
    if relative.startswith("references/cli-help/"):
        return 1, "installed-cli-help"
    if relative.startswith("references/cyberstrike/source-library/user/"):
        return 4, "user-supplied-unverified"
    if relative.startswith("references/cyberstrike/source-library/"):
        return 3, "upstream-documentation-snapshot"
    return 2, "curated-workstation-guidance"


def discover_sources(skill_root: Path, corpus: str) -> list[Path]:
    if corpus == "all":
        return sorted(
            path
            for path in skill_root.rglob("*")
            if path.is_file()
            and path.suffix.lower() in {".md", ".txt"}
            and path.name not in {"llms-ctx.txt", "llms.txt"}
        )

    selected: set[Path] = set()
    cyberstrike_root = skill_root / "references/cyberstrike"
    for path in cyberstrike_root.glob("*.md"):
        selected.add(path)
    for path in (cyberstrike_root / "source-library").rglob("*"):
        if (
            path.is_file()
            and path.suffix.lower() in {".md", ".txt"}
            and path.name not in {"llms-ctx.txt", "llms.txt"}
        ):
            selected.add(path)
    for relative in (
        "references/cli-help/cyberstrike.md",
        "references/workflows/cyberstrike-orchestration.md",
    ):
        path = skill_root / relative
        if path.is_file():
            selected.add(path)
    return sorted(selected)


def chunks_from_file(path: Path, skill_root: Path) -> Iterator[Chunk]:
    relative = path.relative_to(skill_root).as_posix()
    authority, label = authority_for(relative)
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    latest_heading = path.stem
    chunk_heading = path.stem
    current: list[tuple[int, str]] = []
    current_chars = 0

    def emit(items: Sequence[tuple[int, str]], title: str) -> Chunk | None:
        content = "\n".join(text for _, text in items).strip()
        if not content:
            return None
        return Chunk(
            path=relative,
            start_line=items[0][0],
            end_line=items[-1][0],
            heading=title,
            content=content,
            authority=authority,
            authority_label=label,
        )

    for number, text in enumerate(lines, 1):
        stripped = text.strip()
        if stripped.startswith("#"):
            latest_heading = (
                stripped.lstrip("#").strip() or latest_heading
            )
            if not current:
                chunk_heading = latest_heading
        projected = current_chars + len(text) + 1
        if current and projected > MAX_CHUNK_CHARS:
            chunk = emit(current, chunk_heading)
            if chunk:
                yield chunk
            current = current[-OVERLAP_LINES:]
            current_chars = sum(len(item[1]) + 1 for item in current)
            chunk_heading = latest_heading
        current.append((number, text))
        current_chars += len(text) + 1

    chunk = emit(current, chunk_heading)
    if chunk:
        yield chunk


def source_digest(paths: Sequence[Path], skill_root: Path) -> str:
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(skill_root).as_posix().encode())
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


class Embedder:
    def __init__(self, model_name: str, cache_dir: str | None):
        try:
            from fastembed import TextEmbedding
        except ImportError:
            fail(
                "fastembed is not installed; rebuild the workstation or run "
                "'/opt/toolchains/python-apps/cyberstrike-kb/bin/pip install fastembed'"
            )
        kwargs = {"model_name": model_name}
        if cache_dir:
            kwargs["cache_dir"] = cache_dir
        self.model_name = model_name
        self.model = TextEmbedding(**kwargs)

    def passages(self, texts: Sequence[str]) -> list[list[float]]:
        inputs = [f"passage: {text}" for text in texts]
        return [
            vector.astype("float32").tolist()
            for vector in self.model.embed(inputs, batch_size=32)
        ]

    def query(self, text: str) -> list[float]:
        vector = next(
            iter(self.model.embed([f"query: {text}"], batch_size=1))
        )
        return vector.astype("float32").tolist()


def connect(path: Path, *, must_exist: bool = False) -> sqlite3.Connection:
    if must_exist and not path.is_file():
        fail(
            f"knowledge database is missing: {path}; "
            f"run '{PROGRAM_NAME} index'"
        )
    try:
        import sqlite_vec
    except ImportError:
        fail(
            "sqlite-vec is not installed; rebuild the workstation or run "
            "'/opt/toolchains/python-apps/cyberstrike-kb/bin/pip install sqlite-vec'"
        )
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    connection.enable_load_extension(True)
    sqlite_vec.load(connection)
    connection.enable_load_extension(False)
    return connection


def serialize(vector: Sequence[float]) -> bytes:
    from sqlite_vec import serialize_float32

    return serialize_float32(vector)


def create_schema(connection: sqlite3.Connection, dimensions: int) -> None:
    connection.executescript(
        f"""
        PRAGMA journal_mode=DELETE;
        PRAGMA synchronous=FULL;
        CREATE TABLE metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
        CREATE TABLE chunks (
          id INTEGER PRIMARY KEY,
          path TEXT NOT NULL,
          start_line INTEGER NOT NULL,
          end_line INTEGER NOT NULL,
          heading TEXT NOT NULL,
          content TEXT NOT NULL,
          authority INTEGER NOT NULL,
          authority_label TEXT NOT NULL
        );
        CREATE VIRTUAL TABLE chunks_fts USING fts5(
          path UNINDEXED,
          heading,
          content,
          tokenize='porter unicode61'
        );
        CREATE VIRTUAL TABLE vec_chunks USING vec0(
          embedding float[{dimensions}]
        );
        """
    )


def index_database(args: argparse.Namespace) -> None:
    skill_root = resolve_skill_root(args.skill_root)
    database = resolve_database(args.database, args.corpus)
    sources = discover_sources(skill_root, args.corpus)
    minimum_files = 100 if args.corpus == "all" else 20
    minimum_chunks = 200 if args.corpus == "all" else 40
    if len(sources) < minimum_files:
        fail(
            f"{args.corpus} corpus is unexpectedly small: "
            f"{len(sources)} files (expected at least {minimum_files})"
        )

    chunks: list[Chunk] = []
    seen: set[str] = set()
    for source in sources:
        for chunk in chunks_from_file(source, skill_root):
            fingerprint = hashlib.sha256(
                " ".join(chunk.content.split()).encode()
            ).hexdigest()
            if fingerprint in seen:
                continue
            seen.add(fingerprint)
            chunks.append(chunk)
    if len(chunks) < minimum_chunks:
        fail(
            f"{args.corpus} corpus produced too few chunks: "
            f"{len(chunks)} (expected at least {minimum_chunks})"
        )

    cache_dir = args.cache_dir or os.environ.get("FASTEMBED_CACHE_PATH")
    embedder = Embedder(args.model, cache_dir)
    passage_texts = [
        f"{chunk.heading}\n{chunk.content}" for chunk in chunks
    ]
    embeddings = embedder.passages(passage_texts)
    if not embeddings or len(embeddings) != len(chunks):
        fail("embedding count does not match chunk count")
    dimensions = len(embeddings[0])
    if dimensions < 128:
        fail(f"embedding dimension is unexpectedly small: {dimensions}")

    database.parent.mkdir(parents=True, exist_ok=True)
    temporary = database.with_name(f".{database.name}.tmp-{os.getpid()}")
    if temporary.exists():
        temporary.unlink()
    connection = connect(temporary)
    try:
        create_schema(connection, dimensions)
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        metadata = {
            "schema_version": SCHEMA_VERSION,
            "corpus": args.corpus,
            "embedding_model": args.model,
            "embedding_dimensions": str(dimensions),
            "source_digest": source_digest(sources, skill_root),
            "source_files": str(len(sources)),
            "chunks": str(len(chunks)),
            "created_utc": now,
            "skill_root_at_build": str(skill_root),
            "retrieval": "sqlite-vec cosine + SQLite FTS5 BM25 + RRF",
        }
        connection.executemany(
            "INSERT INTO metadata(key, value) VALUES (?, ?)",
            metadata.items(),
        )
        for identifier, (chunk, vector) in enumerate(
            zip(chunks, embeddings, strict=True), 1
        ):
            connection.execute(
                """
                INSERT INTO chunks(
                  id, path, start_line, end_line, heading, content,
                  authority, authority_label
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    identifier,
                    chunk.path,
                    chunk.start_line,
                    chunk.end_line,
                    chunk.heading,
                    chunk.content,
                    chunk.authority,
                    chunk.authority_label,
                ),
            )
            connection.execute(
                """
                INSERT INTO chunks_fts(rowid, path, heading, content)
                VALUES (?, ?, ?, ?)
                """,
                (
                    identifier,
                    chunk.path,
                    chunk.heading,
                    chunk.content,
                ),
            )
            connection.execute(
                "INSERT INTO vec_chunks(rowid, embedding) VALUES (?, ?)",
                (identifier, serialize(vector)),
            )
        connection.commit()
        connection.execute("PRAGMA integrity_check").fetchone()
    finally:
        connection.close()
    os.chmod(temporary, 0o640)
    os.replace(temporary, database)
    print(
        json.dumps(
            {
                "database": str(database),
                "files": len(sources),
                "chunks": len(chunks),
                "model": args.model,
                "dimensions": dimensions,
            },
            indent=2,
        )
    )


def metadata(connection: sqlite3.Connection) -> dict[str, str]:
    return {
        row["key"]: row["value"]
        for row in connection.execute("SELECT key, value FROM metadata")
    }


def fts_query(text: str) -> str:
    tokens = [
        token
        for token in (
            "".join(character if character.isalnum() else " " for character in text)
        ).split()
        if len(token) > 1
    ]
    if not tokens:
        return '""'
    return " OR ".join(f'"{token}"' for token in tokens[:24])


def search_database(args: argparse.Namespace) -> None:
    database = resolve_database(args.database, args.corpus)
    connection = connect(database, must_exist=True)
    try:
        meta = metadata(connection)
        if meta.get("schema_version") != SCHEMA_VERSION:
            fail(
                "knowledge database schema is stale; "
                f"run '{PROGRAM_NAME} index'"
            )
        embedder = Embedder(
            meta["embedding_model"],
            args.cache_dir or os.environ.get("FASTEMBED_CACHE_PATH"),
        )
        query_vector = embedder.query(args.query)
        candidate_count = max(args.limit * 8, 32)
        vector_rows = connection.execute(
            """
            SELECT rowid, distance
            FROM vec_chunks
            WHERE embedding MATCH ? AND k = ?
            ORDER BY distance
            """,
            (serialize(query_vector), candidate_count),
        ).fetchall()
        keyword_rows = connection.execute(
            """
            SELECT rowid, bm25(chunks_fts) AS distance
            FROM chunks_fts
            WHERE chunks_fts MATCH ?
            ORDER BY distance
            LIMIT ?
            """,
            (fts_query(args.query), candidate_count),
        ).fetchall()

        scores: dict[int, float] = {}
        for rank, row in enumerate(vector_rows, 1):
            scores[row["rowid"]] = scores.get(row["rowid"], 0.0) + (
                0.70 / (60 + rank)
            )
        for rank, row in enumerate(keyword_rows, 1):
            scores[row["rowid"]] = scores.get(row["rowid"], 0.0) + (
                0.30 / (60 + rank)
            )

        rows = []
        for identifier, score in scores.items():
            row = connection.execute(
                "SELECT * FROM chunks WHERE id = ?", (identifier,)
            ).fetchone()
            authority_boost = {
                1: 1.30,
                2: 1.18,
                3: 1.00,
                4: 0.82,
            }[row["authority"]]
            rows.append((score * authority_boost, row))
        rows.sort(key=lambda item: item[0], reverse=True)
        rows = rows[: args.limit]

        if args.json:
            print(
                json.dumps(
                    [
                        {
                            "score": round(score, 8),
                            "source": row["path"],
                            "lines": [row["start_line"], row["end_line"]],
                            "heading": row["heading"],
                            "authority": row["authority_label"],
                            "content": row["content"],
                        }
                        for score, row in rows
                    ],
                    indent=2,
                )
            )
            return

        for position, (score, row) in enumerate(rows, 1):
            print(
                f"## Result {position} — {row['heading']}\n"
                f"Source: {row['path']}:{row['start_line']}-"
                f"{row['end_line']}\n"
                f"Authority: {row['authority_label']}\n"
                f"Score: {score:.8f}\n\n"
                f"{row['content']}\n"
            )
    finally:
        connection.close()


def status_database(args: argparse.Namespace) -> None:
    database = resolve_database(args.database, args.corpus)
    connection = connect(database, must_exist=True)
    try:
        result = metadata(connection)
        result["database"] = str(database)
        result["sqlite_version"] = sqlite3.sqlite_version
        result["sqlite_vec_version"] = connection.execute(
            "SELECT vec_version()"
        ).fetchone()[0]
        print(json.dumps(result, indent=2, sort_keys=True))
    finally:
        connection.close()


def verify_database(args: argparse.Namespace) -> None:
    database = resolve_database(args.database, args.corpus)
    connection = connect(database, must_exist=True)
    try:
        meta = metadata(connection)
        checks = {
            "schema": meta.get("schema_version") == SCHEMA_VERSION,
            "integrity": connection.execute("PRAGMA integrity_check").fetchone()[0]
            == "ok",
            "chunks": connection.execute("SELECT count(*) FROM chunks").fetchone()[0],
            "fts": connection.execute("SELECT count(*) FROM chunks_fts").fetchone()[0],
            "vectors": connection.execute("SELECT count(*) FROM vec_chunks").fetchone()[0],
        }
        minimum_chunks = 200 if args.corpus == "all" else 40
        if (
            checks["chunks"] < minimum_chunks
            or checks["chunks"] != checks["fts"]
            or checks["chunks"] != checks["vectors"]
            or not checks["schema"]
            or not checks["integrity"]
        ):
            fail(f"knowledge database verification failed: {checks}")
        print(json.dumps(checks, indent=2))
    finally:
        connection.close()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description=(
            "Index and search a local Hermes knowledge corpus using "
            "FastEmbed, sqlite-vec, FTS5, and hybrid rank fusion."
        )
    )
    result.add_argument("--database", help="override the SQLite index path")
    result.add_argument("--cache-dir", help="override the FastEmbed model cache")
    result.add_argument(
        "--corpus",
        choices=("cyberstrike", "all"),
        default=DEFAULT_CORPUS,
        help=(
            "index CyberStrike-only or the complete ethical-hacking skill "
            f"(default: {DEFAULT_CORPUS})"
        ),
    )
    subcommands = result.add_subparsers(dest="command", required=True)

    index = subcommands.add_parser("index", help="rebuild the vector index")
    index.add_argument("--skill-root", help="offensive-workstation skill root")
    index.add_argument("--model", default=DEFAULT_MODEL)
    index.set_defaults(handler=index_database)

    search = subcommands.add_parser("search", help="hybrid-search the index")
    search.add_argument("query")
    search.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    search.add_argument("--json", action="store_true")
    search.set_defaults(handler=search_database)

    status = subcommands.add_parser("status", help="show index metadata")
    status.set_defaults(handler=status_database)

    verify = subcommands.add_parser("verify", help="verify index integrity")
    verify.set_defaults(handler=verify_database)
    return result


def main() -> int:
    args = parser().parse_args()
    if getattr(args, "limit", 1) < 1 or getattr(args, "limit", 1) > 20:
        fail("--limit must be between 1 and 20")
    args.handler(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

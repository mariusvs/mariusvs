# PostgresPad

A native macOS database tool for PostgreSQL, built with SwiftUI. Runs natively
on Apple Silicon (arm64) — no Electron, no web views.

## Layout

- **Left** — sidebar tree of registered servers; expand a server to see its
  databases (server → database).
- **Centre** — SQL console: a monospaced editor on top, a results grid below,
  with a status bar showing statement count, row count and timing.
- **Right** — inspector panel, intentionally empty for now (reserved for
  table structure, query plans, etc.).

## Features

- Register any number of Postgres servers (host, port, user, password,
  maintenance database, optional TLS).
- Server list persists across launches
  (`~/Library/Application Support/PostgresPad/servers.json`).
- Expanding a server connects lazily and lists its non-template databases.
- Console runs against the selected database (or the server's maintenance
  database when the server row is selected). ⌘↩ to execute.
- Multi-statement scripts: statements are split on `;` (quote-, comment- and
  dollar-quote-aware) and executed sequentially; execution stops at the first
  error.
- Results grid handles arbitrary column sets, with type-aware rendering for
  text, integers, floats, numerics, booleans, UUIDs, timestamps and JSONB.
- Connections are pooled per server + database and reused between queries.

## Requirements

- macOS 14 (Sonoma) or later, Apple Silicon or Intel
- Xcode 15.3+ (or Swift 5.9+ toolchain)

Postgres connectivity uses [PostgresNIO](https://github.com/vapor/postgres-nio),
a pure-Swift driver — no `libpq` or Homebrew dependencies required.

## Building & running

From a terminal:

```sh
swift run
```

Or open the package in Xcode and hit Run:

```sh
open Package.swift
```

The first build resolves and compiles PostgresNIO, which takes a couple of
minutes; subsequent builds are fast.

## Usage

1. Click **+** in the toolbar and register a server.
2. Expand the server in the sidebar — it connects and lists its databases.
3. Select a database, type SQL in the console, press **⌘↩** (or click Run).

## Known limitations / roadmap

- Passwords are stored in plain text in the servers file for now; Keychain
  integration is planned.
- The right-hand inspector panel is an empty placeholder by design.
- No cancel button for long-running queries yet.
- Command tag info (e.g. rows affected by `UPDATE`) isn't surfaced; statements
  without a result set report "Statement Executed".

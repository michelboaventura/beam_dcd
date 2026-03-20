# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BEAM Dead Code Detector (`beam_dcd`) — a static analysis tool that finds unused public functions by analyzing
compiled BEAM bytecode. Language-agnostic: works with Elixir, Erlang, Gleam, or any BEAM-targeting language.

## Common Commands

```bash
# Run all tests
mix test

# Run a single test file
mix test test/beam_dcd/analyzer_test.exs

# Run a specific test by line number
mix test test/beam_dcd/analyzer_test.exs:42

# Watch mode
mix test.watch

# Format code
mix format

# Check formatting (CI)
mix format --check-formatted

# Lint
mix credo --strict

# Type check
mix dialyzer

# Build escript binary
mix escript.build

# Run via Mix task
mix unused_functions

# Run via escript
./beam_dcd /path/to/ebin
```

## Code Style

- Max line length: 120 characters (enforced by both formatter and credo)
- Credo runs in strict mode

## Architecture

The tool implements a **three-phase analysis pipeline**:

### Phase 1: Collect Exports (`ChunkParser`)

Reads BEAM files via `:beam_lib.chunks/2` and extracts export tables (public `{module, function, arity}`
tuples).

### Phase 2: Collect References (`ReferenceCollector`)

Three independent detection layers merged into a unified used-function set:

- **Import tables** (`ChunkParser.parse_imports/1`) — direct cross-module calls
- **Bytecode disassembly** (`Disassembler`) — scans `:beam_disasm` output for call opcodes (`call_ext`,
  `make_fun2`, BIF calls, etc.)
- **Abstract code** (`AbstractAnalyzer`) — best-effort walk of Erlang abstract forms (requires debug info);
  also detects `apply/3` dynamic dispatch

### Phase 3: Compute Unused (`Analyzer`)

Subtracts used functions from exports, then filters out:

- Compiler-generated functions (`module_info`, `__info__`, `__struct__`, `MACRO-*`, etc.)
- Behaviour callbacks (GenServer, Supervisor, Application, Phoenix, Plug, Ecto, Mix.Task)
- Explicit `extra_entrypoints` from config

This filtering logic lives in `EntrypointDetector`.

### Supporting Modules

- **Config** — loads `.beam_unused.exs`, merges CLI flags. Precedence: defaults < config file < CLI flags
- **SourceMapper** — maps BEAM modules back to source files via `:compile_info` chunk
- **Formatter** — output in text (tree view), JSON, GitHub Actions annotations, or SARIF 2.1.0
- **CLI** (`BeamDcd.CLI`) — escript entry point
- **Mix.Tasks.UnusedFunctions** — Mix task entry point, auto-compiles project

### Key Erlang APIs Used

- `:beam_lib` — chunk parsing (exports, imports, attributes, abstract_code, compile_info)
- `:beam_disasm` — bytecode disassembly
- `:code` — code path utilities

## Testing

Test fixtures in `test/support/fixtures.ex` are compiled into `_build/test/lib/beam_dcd/ebin` and used as real
BEAM files for analysis. The `elixirc_paths` config includes `test/support/` during test compilation.

No runtime dependencies — all deps (credo, dialyxir, mix_test_watch) are dev/test only.

# Tests

Tests use the standalone `mini.test` runner with an isolated `.tests/` dependency directory.

```sh
# Run the suite
./scripts/test tests

# Run one spec
./scripts/test tests/toggleterm/cache_spec.lua
```

Place specs under `tests/` and name them `*_spec.lua`. The generated `.tests/` directory is intentionally ignored.

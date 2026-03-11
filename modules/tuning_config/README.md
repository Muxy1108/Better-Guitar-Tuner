# Tuning Config

JSON-based tuning preset definitions for the application.

Current scope:

- canonical preset bundle: `presets/tuning_presets.json`
- preset objects contain `id`, `name`, `instrument`, and ordered `notes`
- notes are listed from lowest string to highest string
- the shared C++ tuning engine loads this JSON at runtime and resolves note
  names into target frequencies

Current tunings in the canonical bundle:

- Standard
- Drop D
- D Standard
- Half Step Down
- Open G
- Open D
- DADGAD
- Double Drop D

Notes:

- the older per-preset JSON files remain as simple examples
- no standalone schema validator is implemented yet

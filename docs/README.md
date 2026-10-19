# Oh My QEMU Documentation

Choose a language / 选择语言:

| Language | Index |
| --- | --- |
| **简体中文** | [docs/zh/README.md](zh/README.md) |
| **English** | [docs/en/README.md](en/README.md) |

Both versions cover the same design:

- **Architecture** — layers, 19 skill responsibilities, data flow, audit workspace, gates, boundaries.
- **Modeling workflow** — P0-P8, round loop, independent review, stop conditions, commands.
- **RS-IR and translation** — Trigger / Condition / Transition, observe/placeholder, RegisterInfo and Unimplemented Device targets.

Diagrams are kept beside each language: `zh/assets/` and `en/assets/`.
The installable skill definitions remain the source of truth in
[`skills/`](../skills/); the repository entry is [README.md](../README.md).

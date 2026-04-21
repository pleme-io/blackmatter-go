# blackmatter-go — Claude Orientation

One-sentence purpose: from-source Go toolchain overlay + `mkGoTool` builder,
consumed by every repo that builds Go binaries in pleme-io.

## Classification

- **Archetype:** `blackmatter-component-custom-overlay`
- **Flake shape:** **custom** (does NOT go through mkBlackmatterFlake)
- **Reason:** Exposes `lib.{overlay,toolBuilder,toolchain,bootstrap}` as direct
  import paths so downstream flakes consume the `.nix` files without
  evaluating flake outputs. `mkBlackmatterFlake` doesn't model that surface.

## Where to look

| Intent | File |
|--------|------|
| Overlay definition | `lib/overlay.nix` |
| Go toolchain build | `lib/go/toolchain.nix` |
| Bootstrap chain | `lib/go/bootstrap.nix` |
| Tool builder (consumed by kubernetes/kikai/etc.) | `lib/tool.nix` |

## Upstream origin

Canonical source is **substrate** (`substrate/lib/go-overlay.nix`,
`substrate/lib/go-tool.nix`). This repo pins and re-exports.

## What NOT to do

- Don't drift from substrate's Go overlay. Keep `lib/overlay.nix` as a thin
  wrapper; substrate owns the patches.

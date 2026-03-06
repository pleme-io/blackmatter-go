# blackmatter-go

From-source Go toolchain overlay and tool builder, re-exported from substrate.

## Overview

Provides a Nix overlay that builds Go from upstream source with a bootstrap binary. Overrides `pkgs.go` and `pkgs.buildGoModule`, and exposes `pkgs.goToolchain`. The canonical implementation lives in substrate; this repo re-exports it as a standalone flake input.

## Flake Outputs

- `overlays.default` -- Go toolchain overlay (`pkgs.go`, `pkgs.goToolchain`, `pkgs.buildGoModule`)
- `packages.<system>.go` -- Go toolchain package
- `lib` -- standalone import paths for overlay, tool builder, toolchain, bootstrap

## Usage

```nix
{
  inputs.blackmatter-go = {
    url = "github:pleme-io/blackmatter-go";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.substrate.follows = "substrate";
  };
}
```

Apply the overlay:

```nix
overlays = [ blackmatter-go.overlays.default ];
```

Build Go tools from source:

```nix
mkGoTool = (import "${blackmatter-go}/lib/tool.nix").mkGoTool;
myTool = mkGoTool pkgs { pname = "foo"; version = "1.0"; src = ...; vendorHash = "..."; };
```

## Structure

- `lib/overlay.nix` -- overlay factory (synced from substrate)
- `lib/tool.nix` -- `mkGoTool` builder (synced from substrate)
- `lib/go/` -- toolchain and bootstrap derivations

# blackmatter-go

From-source Go toolchain for the pleme-io Nix ecosystem. Builds Go 1.25.6 directly from upstream source tarballs with a prebuilt bootstrap binary from go.dev (Go 1.24.11). Provides a Nix overlay that replaces `pkgs.go` and `pkgs.buildGoModule` with the custom toolchain, ensuring every Go service in the stack uses the exact same compiler version. Also exports `mkGoTool`, a reusable builder for packaging Go CLI tools from source with automatic version injection and shell completion generation.

## Architecture

```
blackmatter-go
├── flake.nix              ← overlay + packages + lib exports
└── lib/
    ├── overlay.nix        ← mkGoOverlay: creates the Nix overlay
    ├── tool.nix           ← mkGoTool / mkGoToolOverlay: builds Go CLI tools
    └── go/
        ├── bootstrap.nix  ← prebuilt Go 1.24.11 from go.dev (bootstrap compiler)
        ├── toolchain.nix  ← Go 1.25.6 built from source with NixOS patches
        └── patches/       ← 6 NixOS-compatibility patches
```

**Build chain:**

1. **Bootstrap** -- Prebuilt Go 1.24.11 binary downloaded from go.dev (the only binary artifact)
2. **Toolchain** -- Go 1.25.6 source compiled using the bootstrap binary, with patches for NixOS compatibility
3. **Overlay** -- Replaces `pkgs.go`, `pkgs.go_1_25`, `pkgs.buildGoModule`, and `pkgs.buildGo125Module` to use the from-source toolchain

All source files are synced copies from the canonical source at [substrate](https://github.com/pleme-io/substrate). Comments in each file note `CANONICAL SOURCE: substrate`.

## Features

- **From-source Go 1.25.6** -- no reliance on nixpkgs Go version
- **Prebuilt bootstrap** -- Go 1.24.11 binary from go.dev, supporting 6 platform variants (darwin-amd64, darwin-arm64, linux-386, linux-amd64, linux-arm64, linux-armv6l)
- **NixOS-compatibility patches** -- timezone (tzdata), MIME types (mailcap), network databases (iana-etc), dynamic linker, and vendor check fixes
- **Cross-compilation support** -- proper handling of `CC_FOR_TARGET`, `GOOS`, `GOARCH`, and `CGO_ENABLED`
- **`mkGoTool` builder** -- package any Go CLI tool from source with version ldflags injection, shell completion generation (bash/zsh/fish), and standard Nix meta attributes
- **`mkGoToolOverlay`** -- batch multiple Go tools into a single overlay with `blackmatter-` prefixed package names

## Installation

### As a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    blackmatter-go = {
      url = "github:pleme-io/blackmatter-go";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, blackmatter-go, ... }: {
    # Apply the overlay to get pkgs.go, pkgs.goToolchain, pkgs.buildGoModule
    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ blackmatter-go.overlays.default ];
      };
    in pkgs.mkShell {
      packages = [ pkgs.go ];
    };
  };
}
```

### Standalone package

```bash
# Run the Go compiler directly
nix run github:pleme-io/blackmatter-go

# Build the toolchain
nix build github:pleme-io/blackmatter-go
```

## Usage

### Overlay

The overlay replaces these nixpkgs attributes:

| Attribute | Description |
|-----------|-------------|
| `pkgs.goToolchain` | The from-source Go 1.25.6 binary |
| `pkgs.go` | Overridden to `goToolchain` |
| `pkgs.go_1_25` | Overridden to `goToolchain` |
| `pkgs.buildGoModule` | Uses our Go toolchain instead of nixpkgs Go |
| `pkgs.buildGo125Module` | Uses our Go toolchain instead of nixpkgs Go |

### Building Go CLI tools with `mkGoTool`

```nix
let
  mkGoTool = (import "${blackmatter-go}/lib/tool.nix").mkGoTool;
in
mkGoTool pkgs {
  pname = "kubectl-tree";
  version = "0.4.6";
  src = pkgs.fetchFromGitHub {
    owner = "ahmetb";
    repo = "kubectl-tree";
    rev = "v0.4.6";
    hash = "sha256-...";
  };
  vendorHash = "sha256-...";

  # Optional: inject version info via ldflags
  versionLdflags = {
    "main.version" = "0.4.6";
    "main.commit" = "abc123";
  };

  # Optional: generate shell completions
  completions = {
    install = true;
    command = "kubectl-tree";  # binary that supports `completion {bash,zsh,fish}`
  };

  description = "kubectl plugin to browse resources in a tree view";
  homepage = "https://github.com/ahmetb/kubectl-tree";
}
```

### `mkGoTool` parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `pname` | yes | Package name |
| `version` | yes | Version string (without `v` prefix) |
| `src` | yes | Source derivation (`fetchFromGitHub`, etc.) |
| `vendorHash` | yes | Hash for Go module deps (`null` if vendored in-tree) |
| `subPackages` | no | List of Go packages to build |
| `ldflags` | no | Explicit ldflags list (overrides `versionLdflags`) |
| `versionLdflags` | no | Attrset of `-X` ldflags for version injection |
| `tags` | no | Go build tags (e.g., `["netcgo"]`) |
| `proxyVendor` | no | Use proxy vendor mode (default: `false`) |
| `modRoot` | no | Go module root within source (for monorepos) |
| `doCheck` | no | Run tests (default: `false`) |
| `completions` | no | Shell completion config (`{install, command}` or `{install, fromSource}`) |
| `extraBuildInputs` | no | Additional `nativeBuildInputs` |
| `extraPostInstall` | no | Additional `postInstall` script |
| `extraAttrs` | no | Extra attrs passed through to `buildGoModule` |

### Batch overlay with `mkGoToolOverlay`

```nix
let
  goToolBuilder = import "${blackmatter-go}/lib/tool.nix";
in
goToolBuilder.mkGoToolOverlay {
  blackmatter-stern = { pname = "stern"; version = "1.30.0"; src = ...; vendorHash = ...; };
  blackmatter-k9s = { pname = "k9s"; version = "0.32.0"; src = ...; vendorHash = ...; };
}
```

## NixOS Compatibility Patches

Six patches are applied to the Go source for NixOS compatibility:

| Patch | Purpose |
|-------|---------|
| `iana-etc-1.25.patch` | Resolves `/etc/services` and `/etc/protocols` from the Nix store |
| `mailcap-1.17.patch` | Resolves MIME type database from the Nix store |
| `tzdata-1.19.patch` | Resolves timezone database from the Nix store |
| `go-env-go_ldso.patch` | Sets dynamic linker path from `$GO_LDSO` environment variable |
| `go_no_vendor_checks-1.23.patch` | Disables vendor consistency checks (Nix handles vendoring) |
| `remove-tools-1.11.patch` | Removes unnecessary tool binaries from the install |

## Project Structure

```
blackmatter-go/
├── flake.nix                         # Flake: overlay, packages, lib exports
├── flake.lock                        # Pinned dependencies
└── lib/
    ├── overlay.nix                   # mkGoOverlay — creates the nixpkgs overlay
    ├── tool.nix                      # mkGoTool / mkGoToolOverlay — Go CLI tool builder
    └── go/
        ├── bootstrap.nix             # Prebuilt Go 1.24.11 bootstrap binary
        ├── toolchain.nix             # Go 1.25.6 from-source build
        └── patches/
            ├── iana-etc-1.25.patch   # Network database paths
            ├── mailcap-1.17.patch    # MIME type database path
            ├── tzdata-1.19.patch     # Timezone database path
            ├── go-env-go_ldso.patch  # Dynamic linker path
            ├── go_no_vendor_checks-1.23.patch  # Disable vendor checks
            └── remove-tools-1.11.patch         # Remove extra tools
```

## Supported Platforms

| Platform | Bootstrap | Toolchain |
|----------|-----------|-----------|
| `x86_64-linux` | yes | yes |
| `aarch64-linux` | yes | yes |
| `x86_64-darwin` | yes | yes |
| `aarch64-darwin` | yes | yes |
| `i686-linux` (linux-386) | yes | yes |
| `armv6l-linux` | yes | yes |

## Related Projects

- [substrate](https://github.com/pleme-io/substrate) -- canonical source for the Go overlay, toolchain, and tool builder
- [blackmatter-kubernetes](https://github.com/pleme-io/blackmatter-kubernetes) -- primary consumer; builds 22+ K8s CLI tools using `mkGoTool`
- [blackmatter](https://github.com/pleme-io/blackmatter) -- home-manager module aggregator that pulls in this overlay
- [blackmatter-zig](https://github.com/pleme-io/blackmatter-zig) -- sister project for the Zig toolchain overlay

## License

BSD 3-Clause (matching the Go project license).

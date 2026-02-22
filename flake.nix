{
  description = "Blackmatter Go — from-source Go toolchain, overlay, and tool builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/d6c71932130818840fc8fe9509cf50be8c64634f";
  };

  outputs = { self, nixpkgs }:
  let
    allSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    forEachSystem = f: nixpkgs.lib.genAttrs allSystems (system: f {
      inherit system;
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    });
  in {
    # ── Overlay ─────────────────────────────────────────────────────
    # Applies our from-source Go toolchain. Overrides pkgs.go,
    # pkgs.buildGoModule, and provides pkgs.goToolchain.
    overlays.default = (import ./lib/overlay.nix).mkGoOverlay {};

    # ── Packages ────────────────────────────────────────────────────
    packages = forEachSystem ({ pkgs, ... }: {
      default = pkgs.goToolchain;
      go = pkgs.goToolchain;
    });

    # ── Lib exports (standalone import paths) ───────────────────────
    # These are importable without evaluating the flake:
    #   goOverlay = import "${blackmatter-go}/lib/overlay.nix";
    #   mkGoTool = (import "${blackmatter-go}/lib/tool.nix").mkGoTool;
    lib = {
      overlay = ./lib/overlay.nix;
      toolBuilder = ./lib/tool.nix;
      toolchain = ./lib/go/toolchain.nix;
      bootstrap = ./lib/go/bootstrap.nix;
    };
  };
}

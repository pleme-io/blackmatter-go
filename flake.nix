{
  description = "Blackmatter Go — from-source Go toolchain, overlay, and tool builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, substrate }:
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
    overlays.default = (import "${substrate}/lib/go-overlay.nix").mkGoOverlay {};

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

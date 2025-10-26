{
  description = "Rust devshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              openssl
              pkg-config
              libxkbcommon
              fontconfig
              pam
              freetype
              (rust-bin.stable.latest.default.override { extensions = [ "rust-src" ]; })
            ];

            LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${
              with pkgs;
              lib.makeLibraryPath [
                wayland
                libxkbcommon
                fontconfig
                libGL
                udev
                libinput
                libgbm
                freetype
                libxkbcommon
              ]
            }";
          };
      }
    );
}

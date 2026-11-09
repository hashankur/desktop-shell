{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    devShells = forAll (pkgs: {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
          rust-analyzer
          pkg-config
        ];

        buildInputs = with pkgs; [
          fontconfig
          freetype
          libpulseaudio
          libxkbcommon
          linux-pam # amane's lock screen links it, so cargo test does too
          wayland
          vulkan-loader
        ];

        # runtime tools the shell shells out to
        packages = with pkgs; [
          ffmpeg
          imagemagick
          pulseaudio # pactl
        ];

        RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

        # wgpu / wayland / xkbcommon are dlopen'd at runtime
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
          wayland
          vulkan-loader
          libxkbcommon
          libpulseaudio
        ]);
      };
    });
  };
}

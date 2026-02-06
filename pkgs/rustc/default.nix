# Based on https://github.com/nix-community/fenix/tree/1ad578f
# and https://github.com/openmoto-org/kontroller/blob/73a26ae/nix/rust-esp.nix
{
  platform ? {
    x86_64-linux = "x86_64-unknown-linux-gnu";
    aarch64-linux = "aarch64-unknown-linux-gnu";
    aarch64-darwin = "aarch64-apple-darwin";
  }.${stdenv.hostPlatform.system} or (throw "unsupported system ${stdenv.hostPlatform.system}"),

  version ? "1.93.0.0",
  url ? "https://github.com/esp-rs/rust-build/releases/download/v${version}/rust-${version}-${platform}.tar.xz",
  hash ? {
    x86_64-linux = "sha256-a25Gq2TJItoO3q17Oq6pY/DmvTxuT3KiTTpMKv36rWo=";
    aarch64-linux = "sha256-uaP66+smb+jpBqMUSNGfzzUOukGLT4DvkY3wj7iB5uI=";
    aarch64-darwin = "sha256-r3wW/ZlojzXkxfYUapvSf6sOpYRo7+I10rfsFzPAsZU=";
  }.${stdenv.hostPlatform.system},

  lib,
  stdenv,
  fetchurl,
  zlib,
}:
let
  # Why does the espressif build need stdenv.cc.cc.lib everywhere? Fenix does not have it.
  rpath = "${stdenv.cc.cc.lib}/lib:${zlib}/lib:$out/lib";
in
stdenv.mkDerivation {
  pname = "esp-rustc";
  inherit version;

  src = fetchurl {
    inherit url hash;
  };

  installPhase = ''
    patchShebangs install.sh
    CFG_DISABLE_LDCONFIG=1 ./install.sh --prefix=$out --components=rustc,rust-std-${platform},clippy-preview

    rm $out/lib/rustlib/{components,install.log,manifest-*,rust-installer-version,uninstall.sh} || true

    ${lib.optionalString stdenv.isLinux ''
      if [ -d $out/bin ]; then
        for file in $(find $out/bin -type f); do
          if isELF "$file"; then
            patchelf \
              --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
              --set-rpath ${rpath} \
              "$file" || true
          fi
        done
      fi

      if [ -d $out/lib ]; then
        for file in $(find $out/lib -type f); do
          if isELF "$file"; then
            patchelf --set-rpath ${rpath} "$file" || true
          fi
        done

        for file in $(find $out/lib -path '*/bin/*' -type f); do
          if isELF "$file"; then
            patchelf \
              --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
              --set-rpath ${rpath} \
              "$file" || true
          fi
        done
      fi

      if [ -d $out/libexec ]; then
        for file in $(find $out/libexec -type f); do
          if isELF "$file"; then
            patchelf \
              --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
              --set-rpath ${rpath} \
              "$file" || true
          fi
        done
      fi
    ''}
  '';
  dontStrip = true;
}

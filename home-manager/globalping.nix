# globalping CLI — not in nixpkgs.
# Mirrors the previous bash logic: fetch the GitHub release tarball and
# install the binary to $out/bin/globalping. Works on Linux + macOS for
# both arm64 and x86_64.
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, }:

let
  version = "1.5.2";

  # Map (os, arch) -> GitHub release asset suffix.
  srcInfo =
    let
      os = stdenv.hostPlatform.uname.system; # "Linux" | "Darwin"
      arch = stdenv.hostPlatform.uname.processor; # "x86_64" | "aarch64"
      archSuffix = if arch == "aarch64" then "arm64" else arch;
    in
    if os == "Linux" then
      { asset = "globalping_Linux_${archSuffix}.tar.gz"; }
    else if os == "Darwin" then
      { asset = "globalping_Darwin_${archSuffix}.tar.gz"; }
    else
      throw "globalping: unsupported platform ${os}-${arch}";

in
stdenv.mkDerivation {
  pname = "globalping";
  inherit version;

  src = fetchurl {
    url = "https://github.com/jsdelivr/globalping-cli/releases/download/v${version}/${srcInfo.asset}";
    # Hash will be filled by nix after first build attempt with fakeHash.
    hash = "sha256-1NpQkTavr1IvrnKNFy4/2pAPqBpIfu9QGdGPj5y+50M=";
  };

  # Linux binary may need auto-patching for interpreter/lib path; macOS is
  # typically self-contained.
  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m 0755 globalping $out/bin/globalping
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI for the Globalping network testing platform";
    homepage = "https://github.com/jsdelivr/globalping-cli";
    license = licenses.mit;
    mainProgram = "globalping";
    platforms = platforms.linux ++ platforms.darwin;
  };
}

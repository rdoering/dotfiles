# ccboard — Claude Code session/cost dashboard (TUI + web). Not in nixpkgs.
# Fetches the prebuilt GitHub release tarball and installs the binary to
# $out/bin/ccboard. No arm64 Linux release is published upstream.
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, }:

let
  version = "0.23.0";

  srcInfo =
    let
      os = stdenv.hostPlatform.uname.system; # "Linux" | "Darwin"
      arch = stdenv.hostPlatform.uname.processor; # "x86_64" | "aarch64"
    in
    if os == "Linux" && arch == "x86_64" then
      {
        asset = "ccboard-linux-x86_64.tar.gz";
        hash = "sha256-FlPHMcl8JS0GaYnUHzFkh2dZ8g3onUthlAbbGieOefQ=";
      }
    else if os == "Darwin" && (arch == "aarch64" || arch == "arm64") then
      {
        asset = "ccboard-macos-aarch64.tar.gz";
        hash = "sha256-jxAGjCjTlrpB722e004dU68s39by5EP1N2qIAQlJu1o=";
      }
    else if os == "Darwin" && arch == "x86_64" then
      {
        asset = "ccboard-macos-x86_64.tar.gz";
        hash = "sha256-oEvfvo20zXqRkMzmtrw7kDUReK1kKQzjF2IJ6C1dH08=";
      }
    else
      throw "ccboard: unsupported platform ${os}-${arch} (no upstream release published)";

in
stdenv.mkDerivation {
  pname = "ccboard";
  inherit version;

  src = fetchurl {
    url = "https://github.com/FlorianBruniaux/ccboard/releases/download/v${version}/${srcInfo.asset}";
    inherit (srcInfo) hash;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m 0755 ccboard $out/bin/ccboard
    runHook postInstall
  '';

  meta = with lib; {
    description = "Dashboard for monitoring Claude Code sessions, costs, and configuration";
    homepage = "https://github.com/FlorianBruniaux/ccboard";
    license = licenses.mit;
    mainProgram = "ccboard";
    platforms = platforms.linux ++ platforms.darwin;
  };
}

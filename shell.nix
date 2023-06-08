{ pkgs ? import <nixpkgs> {} }:

let myip = (import ./my-ip.nix) { inherit pkgs; };

in

pkgs.mkShell {
  packages = [
    pkgs.pandoc
    pkgs.texlive.combined.scheme-full
    myip
  ];
}

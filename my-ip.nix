{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "myip" ''
export PATH=${pkgs.lib.makeBinPath [ pkgs.curl pkgs.jq ]}

curl "https://httpbin.org/ip" | jq ".origin"
''

---
title:
- NixOS - ein Linux mit komischen Pfaden
author:
- Jan Heidbrink
theme:
- Copenhagen
date:
- 9. Juni 2023

---

# Überblick

- Nix ist ein Paketmanager und Buildsystem
  - Features:
      - Atomare Upgrades und Rollbacks
      - mehrere Versionen einer Software gleichzeitig installierbar
      - Reproducable builds über exaktes Pinning der Dependencies
- Nix ist eine Programmiersprache
  - Funktionale DSL für "Bauanleitungen für Software"
- nixpkgs ist das Nix Paket Repository
  - größtes existierendes Repository
  - sehr viele Contributors
  - relativ aktuelle Pakete
- NixOS nutzt Nix um das ganze Betriebssystem deklarativ und reproduzierbar aufzusetzen

# Wie funktioniert das?

- Pakete haben keine Pre- und Post-Install Skripte

- Pakete werden nicht nach /usr kopiert, sondern in den "Nix Store" (`/nix/store`)
```
~: ls -l /nix/store/ | head
total 13G
-r--r--r--     2 root    root   4,2K  1. Jan 1970  00012jg15gp88xdkd09xi4k7nzw5jb9g-python3.10-pep517-0.12.0.drv
-r--r--r--     2 root    root   3,0K  1. Jan 1970  0001x7jz6zwhvfgadhrc4z6i39jmx1wb-unit-accounts-daemon.service.drv
-r--r--r--     2 root    root   2,9K  1. Jan 1970  0003n8jvayi4gr4281s42s2zmq5fgrgb-zope.location-4.2.tar.gz.drv
dr-xr-xr-x     4 root    root   4,0K  1. Jan 1970  0008l9p6inwr416r70px34xjh46zj4qx-aws-c-http-0.6.10
-r--r--r--     2 root    root   1,8K  1. Jan 1970  0009r9fh8s0j5c25vy2ihalc5yzgh4dn-cargo-check-hook.sh.drv
-r--r--r--     2 root    root   4,2K  1. Jan 1970  000clnxd40qy0gyrlg9564l2ga0k26dg-gotags-20150803-be986a3.drv
dr-xr-xr-x     4 root    root   4,0K  1. Jan 1970  000dvmibiid0vbmay4mdnd8iasqycbk1-libmicrodns-0.2.0
-r--r--r--     2 root    root   3,4K  1. Jan 1970  000iv8q3v5c9ipvq3jx2hvibnp9i9vma-source.drv
-r--r--r--     2 root    root   2,1K  1. Jan 1970  000svv6f2r2jgfj4ir3vllz45mnkwy2c-python3.10-pylint-2.14.5_fish-completions.drv
```

- Nachteil: Häufig Sonderbehandlung nötig. Viele Programme suchen nach Abhängigkeiten in `/usr`

- Binaries werden so gepatcht, daß sie ihre libraries nicht in `/usr/lib` suchen, sondern
  an den exakt spezifizierten Pfaden

- Damit man in seiner Umgebung bestimmte Programme "sieht", wird die PATH Variable angepasst.


# Pakete schreiben kann einfach sein

```
$ cat my-ip.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "myip" ''
export PATH=${pkgs.lib.makeBinPath [ pkgs.curl pkgs.jq ]}

curl "https://httpbin.org/ip" | jq ".origin"
''

$ nix-build my-ip.nix

nix-build my-ip.nix                            [± master]
this derivation will be built:
  /nix/store/7wja9afxc5yzx02c67y93rg323rp7wjm-myip.drv
building '/nix/store/7wja9afxc5yzx02c67y93rg323rp7wjm-myip.drv'...
/nix/store/bf04ly63z7lxd88mmsgmdd2qr89irjxj-myip

$ tree /nix/store/bf04ly63z7lxd88mmsgmdd2qr89irjxj-myip/bin/myip
/nix/store/bf04ly63z7lxd88mmsgmdd2qr89irjxj-myip/bin/myip

$ cat /nix/store/bf04ly63z7lxd88mmsgmdd2qr89irjxj-myip/bin/myip

$ /nix/store/bf04ly63z7lxd88mmsgmdd2qr89irjxj-myip/bin/myip
```

# Exkurs: nix-shell

```
$ cat shell.nix
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
```

nix-shell starten:

```
$ nix-shell
[nix-shell]$ which myip
/nix/store/bf04ly63z7lxd88mmsgmdd2qr89irjxj-myip/bin/myip

[nix-shell]$ which pandoc
/nix/store/25xx4fxv2n7kvklc6sl0jn48mr796c3j-pandoc-2.17.1.1/bin/pandoc
```

Shell verlassen mit ctrl+d

```
$ which myip
myip not found

$ which pandoc
pandoc not found
```

# Die komischen Pfade

```
$ nix-store --query --graph /nix/store/bf04ly63z7lxd88mmsgmdd2qr89irjxj-myip/bin/myip > myip-dependencies.dot
dot -Tpng myip-dependencies.dot > myip-dependencies.png
![myip dependency graph](myip-dependencies.png)
```
- Die Hashes im Store Path sind nicht content-addressed, sondern input-addressed
  - wenn sich der Hash einer Abhängigkeit ändert, ändert sich auch der eigene Hash
  - die Hashes steht schon fest bevor das Paket gebaut wird

# Ein echtes Beispielpaket: bazel-remote
[Link to source](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/build-managers/bazel/bazel-remote/default.nix)
```
{ buildGoModule
, fetchFromGitHub
, lib
}:

buildGoModule rec {
  pname = "bazel-remote";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "buchgr";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-aC1I+33jEmgjtidA5CQXpwePsavwlx97abpsc68RkBI=";
  };

  vendorHash = "sha256-4vNRtFqtzoDHjDQwPe1/sJNzcCU+b7XHgQ5YqEzNhjI=";

  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/buchgr/bazel-remote";
    description = "A remote HTTP/1.1 cache for Bazel";
    license = licenses.asl20;
    maintainers = lib.teams.bazel.members;
    platforms = platforms.darwin ++ platforms.linux;
  };
}
```


# nixpkgs

- Wenn Ihr irgendwo  auf `import <nixpkgs>` stößt, wird <nixpkgs> auf einen lokalen Checkout von https://github.com/NixOS/nixpkgs aufgelöst.
  - Anders als z.B. `apt` arbeitet der nix Paketmanager direkt mit dem Quellcode der Paketdefinitionen
  - Die Pfade im Store dienen als Cache Key - gebaut wird nur was nicht aus dem Remote Store runtergeladen werden kann


# NixOS

- Verwendet Nix um nicht nur Pakete, sondern ganze Systemkonfigurationen zu bauen
  - damit bekommen wir atomare Upgrades und Rollbacks für das komplette System

```
readlink /run/current-system
/nix/store/z8l66l5sw5lg5vack0w27rg5b654jfii-nixos-system-petrosilia-22.11.4484.d83945caa76
```

![example-bootscreen-screenshot](example-nixos-bootscreen.png)


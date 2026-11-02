#!/bin/bash

set -euo pipefail

# Usage: https://github.com/DOMjudge/domjudge/blob/main/misc-tools/dj_make_chroot.in#L58-L87
/opt/domjudge/judgehost/bin/dj_make_chroot -i rustc,mono-mcs,ruby

install -D -m 644 /opt/golfscript.rb /chroot/domjudge/usr/local/lib/golfscript/golfscript.rb

node_root=/chroot/domjudge/usr/local/lib/node-v24.22.2
kotlin_root=/chroot/domjudge/usr/local/lib/kotlin-2.2.20
install -d "$node_root" "$kotlin_root" /chroot/domjudge/usr/local/bin
tar -xzf /opt/node-v24.22.2-linux-x64.tar.gz -C "$node_root" --strip-components=1 --no-same-owner
unzip -q /opt/kotlin-compiler.zip -d "$kotlin_root"
chmod 755 "$kotlin_root"/kotlinc/bin/{kotlin,kotlinc,kotlinc-jvm}
ln -s /usr/local/lib/node-v24.22.2/bin/node /chroot/domjudge/usr/local/bin/node
ln -s /usr/local/lib/node-v24.22.2/bin/node /chroot/domjudge/usr/local/bin/nodejs
ln -s /usr/local/lib/kotlin-2.2.20/kotlinc/bin/kotlin /chroot/domjudge/usr/local/bin/kotlin
ln -s /usr/local/lib/kotlin-2.2.20/kotlinc/bin/kotlinc /chroot/domjudge/usr/local/bin/kotlinc

cd /
echo "[..] Compressing chroot"
tar -czpf /chroot.tar.gz --exclude=/chroot/tmp --exclude=/chroot/proc --exclude=/chroot/sys --exclude=/chroot/mnt --exclude=/chroot/media --exclude=/chroot/dev --one-file-system /chroot
echo "[..] Compressing judge"
tar -czpf /judgehost.tar.gz /opt/domjudge/judgehost

#!/bin/sh
zig build -Drelease-small=true && \
cp zig-out/lib/cart.wasm dist/one-slime-army.wasm && \
w4 bundle --title "One Slime Army" zig-out/lib/cart.wasm \
--html dist/one-slime-army.html \
--windows dist/one-slime-army.exe \
--mac dist/one-slime-army-mac \
--linux dist/one-slime-army-linux

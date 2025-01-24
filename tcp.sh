#!/bin/bash
clun_download() {
cd ~
sleep 1 && curl -sS -o clun_tcp.sh https://raw.githubusercontent.com/cluntop/cluntop.github.io/main/tcp.sh && chmod +x clun_tcp.sh
} && clun_download

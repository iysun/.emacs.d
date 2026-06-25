#!/usr/bin/env sh
# emacs-dump.sh — 用 portable dump 映像启动 Emacs（加速启动）
# 用法：./emacs-dump.sh [额外参数]  或把此脚本加入 PATH / 设为桌面快捷方式
#
# dump 映像（emacs.pdmp）必须与当前 emacs 二进制匹配。
# 装/删包或升级 emacs 后须先 make dump 重建。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PDMP="$SCRIPT_DIR/emacs.pdmp"

if [ -f "$PDMP" ]; then
    exec emacs --dump-file="$PDMP" "$@"
else
    echo "[emacs-dump] emacs.pdmp 不存在，回退到普通启动。先运行 make dump 生成映像。" >&2
    exec emacs "$@"
fi

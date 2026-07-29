#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""emacs-dump.py — 用 portable dump 映像启动 Emacs（加速启动）。

跨平台（Windows/Linux/macOS），取代原来重复的 emacs-dump.cmd（Windows）/
emacs-dump.sh（Linux/macOS）两份脚本。

用法：
    python emacs-dump.py [传给 emacs 的参数...]
    ./emacs-dump.py [...]              # Linux/macOS，已带可执行位，可直接跑
    py emacs-dump.py [...]             # Windows，用 py launcher

dump 映像（emacs.pdmp）必须与当前 emacs 二进制匹配。
装/删包或重编升级 emacs 后须先 make dump 重建。
「装/删包后忘了重建」这种静默失效由 init-full.el 的 my/check-pdmp-freshness
在启动时检查并告警（比在本脚本里比时间戳更准，也覆盖手动 --dump-file 启动）。
"""
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent
PDMP = REPO / "emacs.pdmp"
EMACS = "emacs"


def main():
    args = sys.argv[1:]
    if PDMP.exists():
        cmd = [EMACS, f"--dump-file={PDMP}", *args]
    else:
        print(
            "[emacs-dump] emacs.pdmp 不存在，回退到普通启动。先运行 make dump 生成映像。",
            file=sys.stderr,
        )
        cmd = [EMACS, *args]

    try:
        # execvp 用当前进程原地替换，行为等价于原 .cmd/.sh 里的直接调用/exec。
        os.execvp(EMACS, cmd)
    except FileNotFoundError:
        print(f"[emacs-dump] 找不到可执行文件 {EMACS!r}，确认它在 PATH 上。", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make-shortcuts.py — 在 Windows 开始菜单建 Emacs 快捷方式。

    python scripts\\make-shortcuts.py
    python scripts\\make-shortcuts.py --bin <scoop>\\apps\\msys2\\current\\ucrt64\\bin

建一个入口（当前用户，不需要管理员）：
    Emacs  →  runemacs.exe

为什么是 runemacs.exe：emacs.exe 是控制台子系统，双击必弹一个多余的终端窗口；
runemacs.exe 是 GUI 子系统，会把参数原样转交给 emacs.exe。

依赖：pywin32（建 .lnk 走 WScript.Shell COM 对象，标准库没有等价物）：
    pip install pywin32
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

if sys.platform != "win32":
    sys.exit("make-shortcuts.py 只支持 Windows（建的是开始菜单 .lnk 快捷方式）。")

try:
    import win32com.client
except ImportError:
    sys.exit("缺依赖 pywin32，先 `pip install pywin32` 再重跑。")


def find_bin(explicit_bin: str | None) -> Path:
    if explicit_bin:
        return Path(explicit_bin)
    # emacs 的 bin 目录；留空则按 scoop 里的 msys2 位置推断
    # （PATH 上的 emacs 是 scoop shim，shim 目录里没有 runemacs.exe，推不出来）
    try:
        result = subprocess.run(["scoop", "prefix", "msys2"], capture_output=True, text=True)
    except FileNotFoundError:
        return Path()
    prefix = result.stdout.strip()
    return Path(prefix) / "ucrt64" / "bin" if prefix else Path()


def make_lnk(shell, programs_dir: Path, runemacs: Path, name: str, argline: str, desc: str):
    path = programs_dir / f"{name}.lnk"
    s = shell.CreateShortcut(str(path))
    s.TargetPath = str(runemacs)
    s.Arguments = argline
    s.WorkingDirectory = os.environ["USERPROFILE"]
    s.IconLocation = f"{runemacs},0"
    s.Description = desc
    s.WindowStyle = 1
    s.Save()
    print(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", dest="bin_dir", default=None,
                         help="emacs 的 bin 目录；留空则按 scoop 里的 msys2 位置推断")
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parent.parent),
                         help="仓库根目录（默认：本脚本所在 scripts/ 的上级目录）")
    args = parser.parse_args()

    bin_dir = find_bin(args.bin_dir)
    runemacs = bin_dir / "runemacs.exe"
    if not runemacs.exists():
        sys.exit(
            f"找不到 {runemacs} —— 用 --bin 显式指定 emacs 的 bin 目录，"
            "例如 <scoop>\\apps\\msys2\\current\\ucrt64\\bin"
        )

    programs_dir = Path(os.environ["APPDATA"]) / "Microsoft" / "Windows" / "Start Menu" / "Programs"
    shell = win32com.client.Dispatch("WScript.Shell")

    make_lnk(shell, programs_dir, runemacs, "Emacs", "",
              "GNU Emacs (msys2/ucrt64 自编)")


if __name__ == "__main__":
    main()

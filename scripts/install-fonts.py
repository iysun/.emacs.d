#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""install-fonts.py — 把 assets/fonts/ 里 vendor 的字体装进当前用户（不需要管理员）。

    python scripts\\install-fonts.py
    python scripts\\install-fonts.py --force

复制到 %LOCALAPPDATA%\\Microsoft\\Windows\\Fonts\\，在
HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts 下登记（持久化，下次登录/开机
也生效），并当场对本会话调一次 AddFontResourceEx（非 private，全会话可见）+ 广播
WM_FONTCHANGE——只写注册表不够：GDI 的会话级字体表不会因为注册表多了一条就自动重新
扫描，得显式把字体资源加进当前会话，装完马上开新 Emacs 才能看到，不用重新登录。
等价于把字体文件拖进"设置 → 个性化 → 字体"，Win10 1809+ 支持，全程不用管理员权限。

幂等：注册表项已存在且指向的文件确实在目标目录里，就跳过；--force 强制重装
（更新 assets/fonts/ 下的字体文件后用）。

Windows-only：装字体走的是 Win32 API（gdi32/user32）+ 注册表，只用标准库
（ctypes + winreg），不需要额外装包。
"""
import argparse
import ctypes
import hashlib
import os
import sys
from pathlib import Path

if sys.platform != "win32":
    sys.exit("install-fonts.py 只支持 Windows（装字体走的是 Win32 API + 注册表）。")

import winreg  # noqa: E402  (只在 Windows 上可导入)

# 清单：assets/fonts/ 里的文件 -> 装好后 Windows/Emacs 认得的 family 名。
# 这几个 family 名已经用 System.Drawing.Text.PrivateFontCollection 实测确认过
# （字体内部 name table 里到底叫什么，不能只看文件名猜），必须跟
# lisp/init-ui.el 字体候选表里的字符串完全一致，装完才会被 find-font 命中：
#   - JetBrainsMonoNL NFM ——注意不是 "JetBrainsMono NFM"，NoLigatures 变体在
#     name table 里带 "NL" 后缀，是为了跟 Ligatures 变体共存不冲突而故意设计的。
#   - 更纱终端书呆黑体-简 ——Sarasa Term SC Nerd 这个补丁版构建把中文名当成主 family
#     名，不是仓库里原来那个候选表项 "Sarasa Term SC Nerd" 的英文名。
#   - 思源黑体 ——Source Han Sans SC 同理，主 family 名是中文名。
#   - Noto Color Emoji / Symbola ——这两个跟候选表里已有的英文名一致，不用改。
# 文件名特意保留上游原名（含 "NL" 标记），别改短——本机实测踩过坑：改成
# "JetBrainsMonoNerdFontMono-Regular.ttf"（去掉 NL）会跟官方 nerd-fonts 安装器/
# 官网下载包会用的 Ligatures 变体文件同名，装到同一个每用户字体目录时互相覆盖，
# 注册表项目录名对得上、内容却是另一个变体，装完 find-font 认出来的字体驴唇不对马嘴。
MANIFEST = [
    {"file": "JetBrainsMonoNLNerdFontMono-Regular.ttf", "name": "JetBrainsMonoNL NFM"},
    {"file": "JetBrainsMonoNLNerdFontMono-Bold.ttf", "name": "JetBrainsMonoNL NFM Bold"},
    {"file": "SarasaTermSCNerd-Regular.ttf", "name": "更纱终端书呆黑体-简"},
    {"file": "SourceHanSansSC-Regular.otf", "name": "思源黑体"},
    {"file": "NotoColorEmoji-WindowsCompatible.ttf", "name": "Noto Color Emoji"},
    {"file": "Symbola.ttf", "name": "Symbola"},
]

REG_KEY_PATH = r"Software\Microsoft\Windows NT\CurrentVersion\Fonts"
HWND_BROADCAST = 0xFFFF
WM_FONTCHANGE = 0x001D
SMTO_ABORTIFHUNG = 0x0002

gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32.AddFontResourceExW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_void_p]
gdi32.AddFontResourceExW.restype = ctypes.c_int
user32.SendMessageTimeoutW.argtypes = [
    ctypes.c_void_p, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_void_p,
    ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p),
]
user32.SendMessageTimeoutW.restype = ctypes.c_void_p


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def reg_get(key, value_name):
    try:
        val, _ = winreg.QueryValueEx(key, value_name)
        return val
    except FileNotFoundError:
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parent.parent),
                         help="仓库根目录（默认：本脚本所在 scripts/ 的上级目录）")
    parser.add_argument("--force", action="store_true", help="强制重装，忽略幂等跳过")
    args = parser.parse_args()

    repo = Path(args.repo)
    fonts_dir = Path(os.environ["LOCALAPPDATA"]) / "Microsoft" / "Windows" / "Fonts"
    fonts_dir.mkdir(parents=True, exist_ok=True)

    reg_key = winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, REG_KEY_PATH, 0, winreg.KEY_ALL_ACCESS)

    changed = False
    with reg_key:
        for entry in MANIFEST:
            src = repo / "assets" / "fonts" / entry["file"]
            if not src.exists():
                print(f"缺文件：{src} —— assets/fonts/ 是不是没拉全？", file=sys.stderr)
                continue

            dest_name = src.name
            dest = fonts_dir / dest_name
            ext = dest_name.rsplit(".", 1)[-1].upper()
            value_name = f"{entry['name']} ({ext})"

            existing_val = reg_get(reg_key, value_name)
            already_ok = (not args.force) and dest.exists() and existing_val == dest_name
            if already_ok:
                print(f"跳过（已装）：{value_name}")
                # 已装过的也当场加载一次，保证本次会话里可用（比如上次装完没重启过 Emacs）。
                gdi32.AddFontResourceExW(str(dest), 0, None)
                continue

            # 撞名保护：目标位置已经有同名文件、但不是本脚本注册表项指向的那个（既不是我们
            # 自己之前装的），说明是别的什么装过同名字体（比如官方 nerd-fonts 安装器）。
            # 字节比对：内容其实一样（比如那边装的就是同一份官方构建）就直接跳过复制——
            # 反正结果一致，还避开了"文件正被占用"的复制失败（已装好的字体文件会被 GDI
            # 一直开着，覆盖同内容的文件 Windows 也不让写）；内容不一样才是真正的冲突，
            # 报错跳过、不覆盖，不要把人家的字体文件静默换成我们的内容。
            need_copy = True
            if dest.exists() and existing_val != dest_name:
                if sha256(src) != sha256(dest):
                    print(
                        f"撞名但内容不同，跳过：{dest} 已存在（不是本脚本装的），不覆盖。"
                        "如果确认可以覆盖，先手动删掉这个文件再重跑。",
                        file=sys.stderr,
                    )
                    continue
                need_copy = False

            if need_copy:
                dest.write_bytes(src.read_bytes())
            winreg.SetValueEx(reg_key, value_name, 0, winreg.REG_SZ, dest_name)
            added = gdi32.AddFontResourceExW(str(dest), 0, None)
            if added == 0:
                print(
                    f"{value_name} 复制/注册表都写了，但 AddFontResourceEx 当场加载失败——"
                    "重启 Emacs 应该还是能生效（下次登录会从注册表重新扫描），只是这次会话内可能看不到。",
                    file=sys.stderr,
                )
            else:
                print(f"已装：{value_name} -> {dest}")
            changed = True

    if changed:
        result = ctypes.c_void_p()
        user32.SendMessageTimeoutW(
            ctypes.c_void_p(HWND_BROADCAST), WM_FONTCHANGE, None, None,
            SMTO_ABORTIFHUNG, 3000, ctypes.byref(result),
        )
        print()
        print("装完了。重启 Emacs 才能看到新字体（Emacs 自己的字体表是进程启动时读一次的）。")
    else:
        print("assets/fonts/ 里的字体都已经装好，无需操作。")


if __name__ == "__main__":
    main()

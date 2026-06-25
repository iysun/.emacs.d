#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""bench-startup.py — 跨平台(Windows/Linux/macOS)测量本机 Emacs 启动速度。

测三种场景的【真实 GUI】emacs-init-time —— dump 映像 / 普通全量 / 精简(minimal) ——
并采集机器信息，输出一段可粘进 docs/startup-benchmark.md 的「机器记录块」，用于多机对比排查。

关键点（踩过的坑，勿删）：
  * 必须用真实 GUI 启动测 emacs-init-time，--batch 测不到 GUI 开销
    （字体/主题/modeline/建帧），见 docs/notes/startup-performance.md。
  * 必须显式 `--init-directory=<repo>` 把配置目录钉到本仓库——否则不同 shell/平台下
    `~/.emacs.d` 可能解析到别处（Windows 上 HOME 与 %APPDATA% 不一致就会加载空配置）。
  * 每次启动校验 `(featurep 'evil)`：三种场景都应加载 evil，flag 非 ok 即视为
    init 中途崩溃/配置没加载，该次样本作废（见 *Warnings* 排查）。

用法:
    python scripts/bench-startup.py             # 打印记录块到 stdout
    python scripts/bench-startup.py -a          # 追加到 docs/startup-benchmark.md
    python scripts/bench-startup.py -n 8        # 每场景跑 8 次(默认 6)
    python scripts/bench-startup.py --emacs /path/to/emacs
"""
import argparse
import datetime
import os
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PDMP = REPO / "emacs.pdmp"
BENCH = REPO / "docs" / "startup-benchmark.md"  # 记录块追加目标
TIMEOUT = 60  # 单次启动超时(秒)；超时记为无效样本


def _run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


# ----------------------------------------------------------------------------
# 机器信息采集（各平台 best-effort，取不到则回退「未知」）
# ----------------------------------------------------------------------------
def cpu_name() -> str:
    sysname = platform.system()
    try:
        if sysname == "Windows":
            import winreg
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                r"HARDWARE\DESCRIPTION\System\CentralProcessor\0")
            return winreg.QueryValueEx(key, "ProcessorNameString")[0].strip()
        if sysname == "Linux":
            for line in Path("/proc/cpuinfo").read_text().splitlines():
                if line.lower().startswith("model name"):
                    return line.split(":", 1)[1].strip()
        if sysname == "Darwin":
            return _run(["sysctl", "-n", "machdep.cpu.brand_string"]).stdout.strip()
    except Exception:
        pass
    return platform.processor() or "未知"


def ram_gb() -> str:
    sysname = platform.system()
    try:
        if sysname == "Windows":
            import ctypes

            class MEMSTAT(ctypes.Structure):
                _fields_ = [("dwLength", ctypes.c_ulong),
                            ("dwMemoryLoad", ctypes.c_ulong),
                            ("ullTotalPhys", ctypes.c_ulonglong),
                            ("ullAvailPhys", ctypes.c_ulonglong),
                            ("ullTotalPageFile", ctypes.c_ulonglong),
                            ("ullAvailPageFile", ctypes.c_ulonglong),
                            ("ullTotalVirtual", ctypes.c_ulonglong),
                            ("ullAvailVirtual", ctypes.c_ulonglong),
                            ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
            m = MEMSTAT()
            m.dwLength = ctypes.sizeof(MEMSTAT)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
            return f"{m.ullTotalPhys / 1024**3:.1f} GB"
        if sysname == "Linux":
            for line in Path("/proc/meminfo").read_text().splitlines():
                if line.startswith("MemTotal"):
                    kb = int(line.split()[1])
                    return f"{kb / 1024**2:.1f} GB"
        if sysname == "Darwin":
            b = int(_run(["sysctl", "-n", "hw.memsize"]).stdout.strip())
            return f"{b / 1024**3:.1f} GB"
    except Exception:
        pass
    return "未知"


def disk_kind() -> str:
    """本仓库所在盘是 SSD 还是 HDD（best-effort）。"""
    sysname = platform.system()
    try:
        if sysname == "Windows":
            out = _run(["powershell", "-NoProfile", "-Command",
                        "(Get-PhysicalDisk | Select-Object -First 1 -ExpandProperty MediaType)"]).stdout.strip()
            return out or "未知"
        if sysname == "Linux":
            kinds = []
            for rot in Path("/sys/block").glob("*/queue/rotational"):
                dev = rot.parent.parent.name
                if dev.startswith(("loop", "ram", "sr")):
                    continue
                kinds.append("HDD" if rot.read_text().strip() == "1" else "SSD")
            if kinds:
                return "/".join(sorted(set(kinds)))
        if sysname == "Darwin":
            out = _run(["diskutil", "info", "/"]).stdout
            for line in out.splitlines():
                if "Solid State" in line:
                    return "SSD" if "Yes" in line else "HDD"
    except Exception:
        pass
    return "未知"


def os_name() -> str:
    sysname = platform.system()
    try:
        if sysname == "Windows":
            return f"Windows {platform.release()} ({platform.version()})"
        if sysname == "Linux":
            pretty = ""
            osr = Path("/etc/os-release")
            if osr.exists():
                for line in osr.read_text().splitlines():
                    if line.startswith("PRETTY_NAME="):
                        pretty = line.split("=", 1)[1].strip().strip('"')
            return f"{pretty or 'Linux'} (kernel {platform.release()})"
        if sysname == "Darwin":
            return f"macOS {platform.mac_ver()[0]}"
    except Exception:
        pass
    return platform.platform()


def emacs_version(emacs: str) -> str:
    try:
        line = _run([emacs, "--version"]).stdout.splitlines()[0].strip()
        return line or "未知"
    except Exception:
        return "未知"


def native_comp(emacs: str) -> str:
    try:
        out = _run([emacs, "-Q", "--batch", "--eval",
                    '(princ (if (and (fboundp (quote native-comp-available-p))'
                    ' (native-comp-available-p)) "yes" "no"))']).stdout.strip()
        return "✅ 可用" if out == "yes" else "❌ 不可用"
    except Exception:
        return "未知"


def pdmp_info() -> str:
    if not PDMP.exists():
        return "缺失"
    st = PDMP.stat()
    mtime = datetime.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M")
    return f"{st.st_size / 1024**2:.1f} MB（{mtime}）"


# ----------------------------------------------------------------------------
# 启动耗时测量
# ----------------------------------------------------------------------------
def make_hook(timef: Path) -> Path:
    """写一个 startup-hook：把 init-time 与 evil 加载标记写入文件后自杀。"""
    el = (
        "(add-hook 'emacs-startup-hook\n"
        "  (lambda ()\n"
        "    (write-region\n"
        '     (format "%.3f %s"\n'
        "             (float-time (time-subtract after-init-time before-init-time))\n"
        '             (if (featurep \'evil) "ok" "noevil"))\n'
        f'     nil "{str(timef).replace(chr(92), "/")}")\n'
        "    (kill-emacs)))\n"
    )
    fd, path = tempfile.mkstemp(suffix=".el", prefix="emacs-bench-hook-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(el)
    return Path(path)


def measure(emacs: str, extra_args, env_extra, runs: int):
    """返回样本列表，每项为 float 秒数或 None（崩溃/超时）。"""
    timef = Path(tempfile.gettempdir()) / "emacs-bench-time.txt"
    hook = make_hook(timef)
    env = dict(os.environ)
    env.update(env_extra)
    samples = []
    try:
        for _ in range(runs):
            if timef.exists():
                timef.unlink()
            cmd = [emacs, f"--init-directory={REPO}"] + extra_args + ["-l", str(hook)]
            try:
                subprocess.run(cmd, env=env, timeout=TIMEOUT,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except subprocess.TimeoutExpired:
                samples.append(None)
                continue
            if not timef.exists():
                samples.append(None)
                continue
            raw = timef.read_text().strip().split()
            # 校验 evil 已加载，否则视为 init 没正常加载 → 作废
            if len(raw) == 2 and raw[1] == "ok":
                samples.append(float(raw[0]))
            else:
                samples.append(None)
    finally:
        hook.unlink(missing_ok=True)
    return samples


def stats(samples):
    """丢首次预热，过滤无效样本，返回 (min, median, valid, total)。"""
    total = len(samples)
    body = samples[1:] if total > 1 else samples  # 去掉第一次预热
    valid = [s for s in body if s is not None]
    if not valid:
        return None, None, 0, total
    return min(valid), statistics.median(valid), len(valid), total


# ----------------------------------------------------------------------------
# 输出
# ----------------------------------------------------------------------------
def fmt(x):
    return f"{x:.3f}" if x is not None else "N/A"


def build_block(emacs: str, runs: int) -> str:
    host = platform.node() or "unknown-host"
    today = datetime.date.today().isoformat()

    scenarios = []
    if PDMP.exists():
        scenarios.append(("dump 映像", [f"--dump-file={PDMP}"], {}))
    else:
        scenarios.append(("dump 映像", None, {}))  # 缺映像 → 跳过
    scenarios.append(("普通全量", [], {}))
    scenarios.append(("精简 minimal", [], {"EMACS_MINIMAL": "1"}))

    rows = []
    for name, args, env_extra in scenarios:
        if args is None:
            rows.append(f"| {name} | — | — | 跳过(emacs.pdmp 缺失) |")
            continue
        print(f"  测量场景：{name} …", file=sys.stderr)
        lo, mid, valid, tot = stats(measure(emacs, args, env_extra, runs))
        note = f"{valid}/{tot}"
        if valid == 0:
            note += "（全部无效，见 *Warnings*）"
        rows.append(f"| {name} | {fmt(lo)} | {fmt(mid)} | {note} |")

    info = [
        ("OS", os_name()),
        ("CPU", f"{cpu_name()}（{os.cpu_count()} 逻辑核）"),
        ("内存", ram_gb()),
        ("磁盘", disk_kind()),
        ("Emacs", emacs_version(emacs)),
        ("native-comp", native_comp(emacs)),
        ("emacs.pdmp", pdmp_info()),
    ]

    lines = [f"### {host}（{today}）", "", "| 字段 | 值 |", "|---|---|"]
    lines += [f"| {k} | {v} |" for k, v in info]
    lines += ["", "| 场景 | min(s) | 中位数(s) | 有效/总次数 |", "|---|---|---|---|"]
    lines += rows
    lines += ["",
              f"> 测量：`scripts/bench-startup.py`（每场景 {runs} 次，去首次预热取 min/中位数；"
              "真实 GUI `emacs-init-time`，已 `--init-directory` 钉定本仓库）。",
              "> 备注："]
    return "\n".join(lines) + "\n"


def main():
    # Windows 控制台默认 GBK，输出含 emoji/中文会报 UnicodeEncodeError —— 强制 UTF-8
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except Exception:
            pass

    ap = argparse.ArgumentParser(description="测量本机 Emacs 启动速度并生成基准记录块")
    ap.add_argument("-n", "--runs", type=int, default=6, help="每场景运行次数(默认 6)")
    ap.add_argument("-a", "--append", action="store_true",
                    help="把记录块追加到 docs/startup-benchmark.md")
    ap.add_argument("--emacs", default=None, help="emacs 可执行文件路径(默认走 PATH)")
    args = ap.parse_args()

    emacs = args.emacs or shutil.which("emacs")
    if not emacs:
        sys.exit("找不到 emacs 可执行文件，请用 --emacs 指定路径。")

    block = build_block(emacs, args.runs)
    print("\n" + block)

    if args.append:
        with open(BENCH, "a", encoding="utf-8") as f:
            f.write("\n" + block)
        print(f"已追加到 {BENCH}", file=sys.stderr)


if __name__ == "__main__":
    main()

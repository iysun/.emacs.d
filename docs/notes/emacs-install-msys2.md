# Emacs 安装：msys2（mingw64），msys2 由 scoop 装

2026-07-27 起，本机 Emacs 不再用 `scoop install extras/emacs`，改为 **msys2 的 mingw64 包**，
msys2 本身仍由 scoop 安装。动机：msys2 那份带 **native-comp**（scoop 那份没有）。

## 装法

```powershell
scoop install msys2                      # msys2 装到 <scoop>\apps\msys2\current
```

```bash
# 在 msys2 shell 里（<scoop>\apps\msys2\current\usr\bin\bash.exe -l）
pacman -Syuu                             # 首次要跑两遍：第一遍升 msys2-runtime 会自杀退出
pacman -S mingw-w64-x86_64-emacs
# 图像支持（可选依赖，不装则 gif/jpeg/svg/tiff 用不了）
pacman -S mingw-w64-x86_64-{giflib,libjpeg-turbo,librsvg,libtiff}
```

包源已把 USTC 镜像置顶（`/etc/pacman.d/mirrorlist.{msys,mingw}` 第一行，原文件留了 `.bak`）。

## ⚠ 必须用 mingw64，不要用 ucrt64

msys2 有两套 Emacs：`mingw-w64-x86_64-emacs`（msvcrt）和 `mingw-w64-ucrt-x86_64-emacs`（UCRT）。
**ucrt64 那份的 `--batch` 完全没有控制台输出**——stdout / stderr / `message` /
`external-debugging-output` 四条通道全哑，但 `write-region` 写文件正常、退出码也正常传递。
（PE 头是 console 子系统，重定向到文件同样为空，不是终端附着问题。）

这会直接废掉本仓库的整条工具链：`make compile` 看不到编译告警、`/run` 看不到
`== LOADED OK ==`、`/build` 看不到「已激活 N/N 个包」这类静默失效的判据。
mingw64（msvcrt）那份一切正常，**就用它**。

## PATH：用 scoop shim 指过去，不要把 mingw64\bin 整个塞进 PATH

`mingw64\bin` 里有 gcc / python / curl 等一大堆东西，整目录进 PATH 会盖掉 scoop 的同名工具。
只给需要的几个建 shim：

```powershell
scoop uninstall emacs                    # 先卸掉 scoop 那份，否则 shim 冲突
$b = "D:\Applications\Scoop\apps\msys2\current\mingw64\bin"
foreach ($n in "emacs","emacsclient","emacsclientw","etags","ctags") { scoop shim add $n "$b\$n.exe" }
```

- 快捷方式仍应指向 `runemacs.exe`（GUI 子系统，无终端窗口）；mingw64 里有这个文件。
- 日常启动用仓库根的 `emacs-dump.cmd`（走 pdmp），它调用 PATH 上的 `emacs`。

## 换过来之后连带变了什么

- **native-comp 可用**了（`(native-comp-available-p)` => t）。`early-init.el` 里原先的
  `(setq native-comp-jit-compilation nil)` 在旧 emacs 上是空操作，在这份构建上会把包锁死在
  只有字节码的状态，已改成 `t` + `native-comp-async-report-warnings-errors` 设 `silent`。
  安装目录里只有 2 个预编译 `.eln`，其余靠 JIT 逐步编进仓库的 `eln-cache/`。
- **pdmp 必须重建**，且 `dump.el` 要禁 subr trampoline，否则映像起不来。见
  [pdump-startup.md](pdump-startup.md) 的「③ trampoline」。
- **升级方式变了**：不再是 `scoop update emacs`，而是 `pacman -Syu`（在 msys2 shell 里）。
  升完同样要 `make dump` 重建 pdmp。

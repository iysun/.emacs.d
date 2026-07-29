# Emacs 安装：msys2 UCRT64 环境 + 自己编译 Emacs 31

2026-07-27 起，本机 Emacs 是**在 msys2 的 UCRT64 环境里从上游源码自己编译的 Emacs 31.0.91**，
装在 `<scoop>\apps\msys2\current\ucrt64`；msys2 本身由 scoop 安装。

当天走过两轮，结论按顺序看：

1. 先从 scoop 的 `extras/emacs`（30.2，**无 native-comp**）换到 msys2 的 **mingw64** 包（30.2，有 native-comp）；
2. 再换成 **UCRT64 + 自编 Emacs 31**——因为 UCRT64 是 msys2 推荐的默认环境，而 msys2 打包的
   ucrt64 版有个致命缺陷（见下），自己编能绕开。

## ⚠ 不要用 pacman 装的 `mingw-w64-ucrt-x86_64-emacs`

那份包的 **`--batch` 没有控制台输出**：stdout / stderr / `message` /
`external-debugging-output` 四条通道全哑，只有 `--help` 这种极早期输出还在；
写文件和退出码都正常，所以失败得非常安静。

- 上游 issue：[msys2/MINGW-packages#23569](https://github.com/msys2/MINGW-packages/issues/23569)，
  2025-03-03 开，至今 open、无 workaround。
- 根因在 MSYS2 自己的 **`001-ucrt.patch`**：它给 `src/sysdep.c` 里 `close_stream(stdout)`
  失败时的 `perror` + `_exit` 加了 `#ifndef _UCRT`。PKGBUILD 注释里直说
  *"001-ucrt.patch breaks stdout, causing `make sanity-check` to fail"*，所以他们在 mingw 环境
  **跳过了 sanity-check**。
- 后果：本仓库靠读 batch 输出判成败的流程（`/run`、`/build`、`make compile`）会全部变成睁眼瞎。
  当天修掉的三个 dump 静默 bug，正是靠 `已激活 N/N 个包` 这种行才发现的。

**自己从上游编译（不打这个补丁）的 ucrt64 Emacs 没有此问题**，实测 stdout / stderr 都正常，
上游 `make sanity-check` 也能跑过。

## 怎么编

```powershell
scoop install msys2
```

```bash
# msys2 shell：<scoop>\apps\msys2\current\usr\bin\bash.exe -l  （MSYSTEM=UCRT64）
pacman -Syuu          # 首次跑两遍：第一遍升 msys2-runtime 会自杀退出
pacman -S --needed base-devel git autoconf automake texinfo \
  mingw-w64-ucrt-x86_64-toolchain \
  mingw-w64-ucrt-x86_64-{zlib,xpm-nox,freetype,harfbuzz,jansson,gnutls,libtree-sitter,libgccjit,giflib,libjpeg-turbo,libpng,librsvg,libtiff,libwebp,libxml2,sqlite3}

git clone --depth 1 --branch emacs-31 https://git.savannah.gnu.org/git/emacs.git /d/dev-cache/emacs31
cd /d/dev-cache/emacs31
./autogen.sh
./configure --prefix=/ucrt64 --host=x86_64-w64-mingw32 --build=x86_64-w64-mingw32 \
  --with-modules --without-dbus --without-compress-install --with-tree-sitter \
  --with-native-compilation=yes \
  CFLAGS="-O2 -pipe -Wno-incompatible-pointer-types"
make -j$(nproc)
```

参数对齐 MSYS2 的 PKGBUILD，两点差异：

- **不打任何 MSYS2 补丁**（`001-ucrt.patch` 正是要绕开的那个）。
- native-comp 用 `yes`（JIT）而非 `aot`。`aot` 会把整棵 lisp 树提前原生编译，构建时间高一个量级；
  本配置 `early-init.el` 已开 JIT，内置 lisp 会按需编进仓库的 `eln-cache/`。
  （注：`--with-native-compilation=jit` **不是**合法值，会报 `bad value jit`；合法值是 `yes|no|aot`。）

包源已把 USTC 镜像置顶（`/etc/pacman.d/mirrorlist.{msys,mingw}` 第一行，原文件留了 `.bak`）；
clone 走代理 `http://127.0.0.1:7897`。

## ⚠ `make install` 会挂死，用分步目标

整条 `make install` 在本机**必然卡住**：卡在 `install-arch-indep` 用 `tar -chf - . | tar -xvf -`
复制 `lisp/`、`etc/` 那一步之后，`make` 进程 CPU 归零、无任何子进程，能挂几十分钟不动。
（试过输出走管道和输出重定向到文件，都一样，不是管道阻塞。）

那一步的效果其实**已经做完了**（`share/emacs/31.0.91/{lisp,etc}` 都在），所以杀掉它、
用 `-o` 把已完成的目标标记为最新，只跑剩下的二进制安装即可：

```bash
pacman -R mingw-w64-ucrt-x86_64-emacs      # 先卸掉包版，给自编版腾出 /ucrt64 前缀
make -o install-arch-indep -o install-etcdoc install-arch-dep install-nt install-eln
```

这一步几十秒就完，装出 `bin/{emacs,emacs-31.0.91,emacsclient,emacsclientw,runemacs}.exe`、
`libexec/emacs/31.0.91/x86_64-w64-mingw32/`（含官方 `emacs-<fingerprint>.pdmp`、`cmdproxy.exe`）。

## PATH：用 scoop shim 指过去，别把 ucrt64\bin 整个塞进 PATH

`ucrt64\bin` 里有 gcc / python / curl 等一大堆东西，整目录进 PATH 会盖掉 scoop 的同名工具。
只给需要的几个建 shim：

```powershell
$b = "D:\Applications\Scoop\apps\msys2\current\ucrt64\bin"
foreach ($n in "emacs","emacsclient","emacsclientw","etags","ctags") {
  scoop shim rm $n; scoop shim add $n "$b\$n.exe"
}
```

开始菜单快捷方式用 `scripts\make-shortcuts.py` 重建（指向 `runemacs.exe`）。

## 换到 Emacs 31 之后连带变了什么

- **`dump: 已激活 63/68 个包` 是健康值**，不再是 68/68。少的 5 个是
  `project` / `jsonrpc` / `flymake` / `eglot` / `compat`——Emacs 31 都已内置且版本 ≥ elpa 副本，
  package.el 于是主动跳过 elpa 那份改用内置的。实测 5 个 `require` 全部正常、magit 也正常。
  **判据要看的是「跳过 0 个」和分子是否突然大幅下滑**，63/68 这个组合本身没问题。
- **仓库里那条「Emacs 31.0.90 加载任意 `--dump-file` 必崩」是误判**，已在
  [pdump-startup.md](pdump-startup.md) 推翻。真凶是 trampoline 和 eln-load-path 两个内容坑，
  只是它们要 native-comp 构建才暴露，而当时对照组 scoop 30.2 没有 native-comp。
- **Emacs 31 会对缺 `lexical-binding` cookie 的文件告警**（30 只在字节编译期告警，31 提前到
  `load` 时）。`custom.el`（Customize 自动生成、已 gitignore）和 `lisp/init-ai.el` 都补了首行
  cookie；`custom.el` 那行实测过 `custom-save-all` 重写时不会被冲掉。
  换机器时 `custom.el` 是重新生成的，需要再补一次。
- **配置侧唯一的实质改动在 `lisp/init-lsp.el` 的 tree-sitter 路由**：`treesit-enabled-modes`
  必须用 `setopt`（`setq` 静默失效，会导致 ts-mode 和 eglot 全部不生效），且列白名单而非写 `t`。
  原委见 [lsp-eglot-tuning.md](lsp-eglot-tuning.md)。
- **两条新默认值配置里没覆盖，先用着**：`split-window-preferred-direction` 默认 `longest`
  （宽屏下 `display-buffer` 改为左右分屏；不适应就设 `'vertical`）、终端下
  `xterm-mouse-mode` 默认开启（只影响 TTY）。
- **升级方式**：不再是 `pacman -Syu` 升 emacs（那只升 msys2 的库和工具链）。要升 Emacs 本身，
  回 `/d/dev-cache/emacs31` `git pull` 重编重装。**升完必须 `make dump` 重建 pdmp。**

## 保留的回退项

msys2 的 **mingw64** 包 `mingw-w64-x86_64-emacs`（30.2，batch 输出正常）仍然装着，没进 PATH，
留作 31 出问题时的回退。要清掉：`pacman -R mingw-w64-x86_64-emacs`。

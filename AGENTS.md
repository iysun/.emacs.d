# AGENTS.md

个人 Emacs 配置仓库（Emacs Lisp）。本文件是 **AI 协作的单一事实源**：项目规范、构建/运行/开发流程都写在这里，其他 agent 适配文件（`CLAUDE.md`、`.cursor/rules/`）只做引用，不复制内容。

> 平台：Windows（scoop 工具链，`emacs` / `make` / `git` 均在 PATH）。命令以 PowerShell 给出。
> **emacs 是在 msys2 UCRT64 环境里从上游源码自编的 Emacs 31.0.91**（msys2 由 scoop 装，
> 装在 `<scoop>\apps\msys2\current\ucrt64`），PATH 上是 scoop shim 指过去的；带 native-comp。
> 升级 = 回源码树 `git pull` 重编重装，**不是** `pacman -Syu`（那只升 msys2 的库）。
> ⚠ 别改用 pacman 装的 `mingw-w64-ucrt-x86_64-emacs`：MSYS2 自家的 `001-ucrt.patch` 破坏了
> stdout，那份的 `--batch` 没有任何控制台输出，本仓库靠读 batch 输出的流程
> （`/run` `/build` `make compile`）会全部变成睁眼瞎。装法、坑、分步 install 见
> [docs/notes/emacs-install-msys2.md](docs/notes/emacs-install-msys2.md)。

## 这个项目是什么

一套模块化的 Emacs 配置，支持两套 profile：

- **全量（full，默认）**：`init-full.el` 声明包列表并 `require` 各模块（evil、补全、UI、LSP、magit…）。
- **精简（minimal）**：单文件 `init-minimal.el`，只含 evil + 内置 project/eglot + completion-preview。

启动链：`early-init.el` → `init.el`（profile 分发器）→ `init-full.el` 或 `init-minimal.el`。

## AI 工具入口

为本仓库生成的命令 / 规则（详见各 agent 适配层）：

- **`/build`**（Claude Code，`.claude/commands/build.md`）：生成自定义 portable dump（`emacs.pdmp`）加速启动。
- **`/run`**（Claude Code，`.claude/commands/run.md`）：批处理加载冒烟验证循环。
- **`/bench`**（Claude Code，`.claude/commands/bench.md`）：测本机启动速度（三场景真实 GUI），追加到 `docs/startup-benchmark.md`。
- Cursor：`.cursor/rules/project.mdc`（始终生效）+ `*.el` 条件规则，指向本文件。
- Codex：原生读取本 `AGENTS.md`，无需额外文件。

## 目录结构

| 路径 | 作用 |
|------|------|
| `early-init.el` | GC 延迟、native-comp、包系统早期开关、首装签名校验兜底 |
| `init.el` | profile 分发器（仅分发，不含具体配置） |
| `init-full.el` | 全量 profile：声明包列表 + `require` 各模块（与 `init.el` 同级，按路径 load） |
| `init-minimal.el` | 精简 profile 全部内容（与 `init.el` 同级，按路径 load） |
| `lisp/init-*.el` | 全量 profile 的功能模块（每个 `(provide 'init-xxx)`） |
| `lisp/init-format.el` | apheleia 格式化（非 LSP 场景；`SPC f` 仍是 eglot-format） |
| `lisp/init-navigation.el` | citre 兜底代码导航 + imenu-list 大纲侧栏（citre 需本机 Universal Ctags） |
| `lisp/init-windows.el` | Windows 专项、无其它调用方的设置（文件属性/管道调优、控制台+剪贴板编码、git 环境变量…），非 Windows 平台空操作。由 `early-init.el` 在最早期用绝对路径 `load`（此时 `lisp/` 还没进 load-path）。新增纯 OS-only 代码都加进这一个文件，别再散落到别处；跨平台功能不放这里，见下条与「多平台代码怎么归位」 |
| `lisp/init-ime.el` | 跨平台输入法切换（`my/switch-to-english-input-method`，Windows 用 im-select.exe / Linux·macOS 用 fcitx5-remote），全量/精简两套 profile 共用一份。同样由 `early-init.el` 绝对路径 `load` |
| `lisp/init-mirrors.el` | **包源镜像的唯一定义处**（全量/精简/dump 三处都 require 它，换镜像只改这一个文件） |
| `lisp/init-bars.el` | **mode-line + tab-line** 的入口：两条 bar 共用的工具函数 + 字号/内边距统一设置（放一起改才不会顾此失彼），本体 `load` 自 `lisp/extensions/`。须在 `init-ui` 之后加载，复用其字体选择结果 |
| `lisp/extensions/mode-line/mode-line.el` | mode-line 实现本体，`(provide 'init-mode-line)`，由 `init-bars.el` `load` |
| `lisp/extensions/tab-line/tab-line.el` | tab-line 实现本体，`(provide 'init-tab-line)`（特意不叫 `tab-line'，避免跟内置库撞名），由 `init-bars.el` `load`。标签按项目分组、不带图标（纯文字，跟 mode-line 一样简约优先），较复杂的实现（如按组操作、ace-jump 跳标签）放在这里，跟 `init-bars.el` 里两条 bar 共用的简单工具函数分开 |
| `lisp/extensions/` | 约定：每个扩展独立一个子目录（如 `mode-line/`、`tab-line/`），不直接在 `extensions/` 下放 .el 文件 |
| `lisp/lang-*.el` | 语言专属配置（如 `lang-go.el`，当前未启用） |
| `themes/` | 本仓库自维护的主题文件（`*-theme.el`），由 `custom-theme-load-path` 接入（`lisp/init-ui.el`），新增主题放进去即可被 `switch-emacs-theme` 自动发现，不用改代码。共 5 个：`nn-world`（借自 zdn/.emacs.d，GPLv3，默认主题）、`catppuccin`/`crafters`/`gits`/`matrix`（调色板移植自 [LionyxML/emacs-solo](https://github.com/LionyxML/emacs-solo)，GPL-3.0-or-later，face 结构复用 `nn-world-theme.el`，见各文件头注释）；不再依赖 `doom-themes` 包 |
| `assets/fonts/` | vendor 进仓库的字体文件（OFL 等自由许可，随 git 一起到位），配 `scripts/install-fonts.ps1` 装进当前用户；`lisp/init-ui.el` 英文/中文/符号/emoji 四组字体候选表里各有一项对应这里的文件。见 [docs/notes/vendored-fonts.md](docs/notes/vendored-fonts.md) |
| `custom.el` | Customize 自动生成，**已 gitignore，勿手改** |
| `elpa/` | 第三方包，**已 gitignore，勿编辑/勿提交** |
| `var/` `etc/` | no-littering 收编的运行期文件（recentf/savehist/bookmark/project/tramp/eshell/transient…），**已 gitignore，勿手改** |
| `docs/` | 配置笔记，`docs/notes.md` 是索引，正文在 `docs/notes/*.md`（按需读取） |
| `dump.el` | portable dump 构建脚本（预加载重包→`emacs.pdmp`），`make dump` / `/build` 调用 |
| `README.md` | 简洁项目介绍 + 文档入口（规范/流程仍以本文件为准） |
| `docs/startup-benchmark.md` | 多机启动速度基准记录 + 测法（脚本 `-a` 追加到此） |
| `scripts/bench-startup.py` | 跨平台测速脚本：采集机器信息 + 三场景测真实 GUI 启动耗时，输出/追加基准块 |
| `scripts/make-shortcuts.ps1` | Windows：在开始菜单建 Emacs 快捷方式（指向 `runemacs.exe`，带/不带 pdmp 两个入口） |
| `scripts/install-fonts.ps1` | Windows：把 `assets/fonts/` 里 vendor 的字体装进当前用户（不需要管理员），装法/原理见文件头注释和 [docs/notes/vendored-fonts.md](docs/notes/vendored-fonts.md) |
| `emacs-dump.cmd` | Windows：带 `--dump-file` 启动 Emacs（pdmp 缺失则回退普通启动） |
| `emacs-dump.sh` | Linux/macOS：同上 |
| `emacs.pdmp` | 生成的 dump 映像，**已 gitignore，按需 `make dump` 重建** |

当前启用的模块（见 `init-full.el` 末尾）：`init-base` `init-evil` `init-ui` `init-bars` `init-window`
`init-completion` `init-dired` `init-git` `init-term` `init-project` `init-mc`
`init-keymaps` `init-lsp` `init-format` `init-navigation`。`init-ai` / `init-evil-plugins` / `lang-go`
已写好但注释停用。

`init-format`（apheleia，非 LSP 场景的格式化，`SPC f` = eglot-format 仍只管 LSP buffer）与
`init-navigation`（citre 兜底代码导航 + imenu-list 大纲侧栏，`F12`/`C-'`；citre 需要本机装
Universal Ctags，没装就整个不加载）借鉴自 zdn/.emacs.d（见 git log 里对应提交）。

## 文档（docs/）

项目笔记放在 `docs/`，采用「索引 + 按需读取」结构（渐进式上下文）：

- **`docs/notes.md`** 是索引：每条一行 `- [标题](notes/slug.md) — 何时该读`，描述即"要不要展开读"的路由信号。
- 正文按主题拆到 **`docs/notes/*.md`**（英文 kebab-case 文件名，内容中文）。
- **维护纪律**：新增笔记 = 在 `notes/` 加一篇 + 在 `docs/notes.md` 补一行。
- 改动牵涉某主题（构建/编译、profile、镜像安装、AI 补全…）时，先查 `docs/notes.md` 有无相关笔记。

关于字节编译的细节见 [docs/notes/byte-compile-broken-elc.md](docs/notes/byte-compile-broken-elc.md)。

## 构建 = 生成 portable dump（启动加速）

本仓库的「build」= 生成自定义 dump 映像 `emacs.pdmp`（预加载 evil/补全栈/doom-themes 等重包），
启动时用 `--dump-file` 内存映射回来，省掉 `require` 的几秒。实测 `emacs-init-time` ~5.6s → ~3.3s。

```powershell
make dump            # = /build，调用 dump.el 生成 emacs.pdmp
```
启动用映像：把日常快捷方式指向仓库根的 **`emacs-dump.cmd`**（pdmp 缺失会回退普通启动），
或手动 `emacs --dump-file=<.emacs.d>\emacs.pdmp`。

要点（细节见 [docs/notes/pdump-startup.md](docs/notes/pdump-startup.md)）：
- **只预加载第三方库，不在 dump 期跑用户 init**（dump 期无 GUI，会踩字体/frame/主题坑）。
- `dump.el` 转储前复位 `package--initialized`/`package-activated-list`/`package-alist`，
  让启动时 `init.el` 的 `package-initialize` 重建 load-path（否则没烤进映像的包如 `fd-dired` 找不到）。
- evil 的 `evil-want-keybinding` 等 `evil-want-*` 须在 dump.el 里先设好再 require（用默认 `t`，
  与 init-evil.el 一致；已移除 evil-collection）。
- **dump 期禁 subr trampoline**（`native-comp-enable-subr-trampolines` 设 nil，转储前再恢复）：
  包 advice 原语会现场编出 trampoline `.eln`，被烤进映像后启动时加载不回来，报
  `Error using execdir …: 找不到指定的模块`。见 pdump 笔记 ③。
- 别再动 `native-comp-eln-load-path`：清空它救不了任何东西，反而让映像加载时段错误
  （`0xC0000005`）。这条已从 `dump.el` 删除，见 pdump 笔记 ②。
- `dump.el` 在 `package-initialize` 前把 `package-quickstart-file` 指回本仓库并复位 package 记账，
  否则从 Git Bash / make 里跑（`HOME` 被设）会读到别处的过期 quickstart，静默只激活一小部分包。
- 构建输出要盯两行：`已激活 63/68 个包` 与 `预加载 20 个包，跳过 0 个`。**跳过不为 0**、或分子
  突然大幅下滑 = 映像残缺（历史上这里静默只烤进过 9/20）。
  63/68 里少的 5 个（`project` `jsonrpc` `flymake` `eglot` `compat`）是 Emacs 31 已内置且版本更高、
  package.el 主动跳过 elpa 副本，属正常，见安装笔记。
- ⚠️ **装/删包、或重编升级 emacs 后必须 `make dump` 重建**，否则映像不兼容、启动报错。
  「装/删包后忘了重建」这种**不报错**的情况，由 `init-full.el` 的 `my/check-pdmp-freshness`
  在启动时比对 `emacs.pdmp` 与 `elpa/` 的时间戳并弹 `*Warnings*` 提醒。

## 字节编译与 .elc

曾有一处脆弱点：多个模块在**顶层**用 evil 宏（`init-evil.el` 的 `evil-define-text-object`、
`init-keymaps.el` 的 `evil-define-key`），而字节编译期未加载 evil，编译器把宏当函数编译，
产出坏 `.elc`（加载报 `void-variable evil-a-between` / `Invalid function: evil-define-key`）。

**已修复**：在 `init-evil.el` / `init-keymaps.el` / `init-evil-plugins.el` 顶层加了 `(require 'evil)`
（byte-compiler 会执行顶层 `require`，使宏在编译期可用）。现在 `make compile` 产出的 `.elc` 正确、可加载。

仍需知道的两点：

- **本仓库约定加载 `.el` 源码**（`.elc` 已 gitignore，不提交）。
- 交互会话里 `load-prefer-newer` 为 nil（见 `early-init.el`），**残留的旧 `.elc` 会悄悄盖过更新的 `.el`**。
  所以编译只用于检查；检查完用 **`make clean`** 把 `.elc` 清掉，回到源码加载。
  ```powershell
  make compile   # 语法检查
  make clean     # 清 .elc（不动 emacs.pdmp）
  ```
  （`make clean` 原先用 GNU `find`，在 Windows 会命中 `system32\find.exe` 而**静默失效**，现已改成
  用 `emacs --batch` 删，三平台一致。要连 `emacs.pdmp` 一起删用 `make distclean`——单独分出来是因为
  pdmp 重建要几十秒，不该被高频的清 `.elc` 顺手毁掉。）
  （`/build` 生成 pdmp，不做编译；纯语法检查走上面两步。）

## 验证配置是否能正常加载

两套 profile 均可用 `--batch` 加载验证（修复后全量也能干净加载）：

| profile | 方法 | 结果 |
|---------|------|------|
| 全量 | `emacs --batch` 加载 `early-init.el` + `init.el` | ✅ 干净通过 |
| 精简 | `emacs --batch`（设 `EMACS_MINIMAL=1`）加载 `init.el` | ✅ 干净通过 |

`/run` 命令封装了这两步。注意批处理无 GUI，只验证「能否无错加载」；**视觉外观**（字体、主题、
modeline 等）仍需启动真实 Emacs 肉眼确认：

```powershell
emacs                          # 全量 profile（本仓库即 ~/.emacs.d）
emacs --minimal                # 精简 profile（或设 EMACS_MINIMAL=1）
```

## AI 代码补全（minuet）

`lisp/init-ai.el`（当前停用）用 minuet 接 SiliconFlow。密钥**不写进配置**，从环境变量读取：

```powershell
$env:SILICONFLOW_API_KEY = "sk-xxxx"   # 由用户在自己的 shell/系统环境设置
```

`init-ai.el` 里 `:api-key` 传的是**环境变量名字符串**，由 minuet 自行 `getenv`。切勿把真实密钥硬编码进任何文件。

## 维护约定（判断式，非强制）

- **改了行为/加了模块** → 同步更新本文件相关小节（结构表、启用模块列表、命令）。纯重构 / 小修可不动文档。
- **新增模块**：在 `lisp/` 下建 `init-xxx.el`，文件末 `(provide 'init-xxx)`，并在 `init.el` 末尾 `(require 'init-xxx)`。
- **改完怎么验证**：用 `/run`（批处理加载全量 + 精简两套 profile，确认无错）；语法快查用 `/build`（编译后自动清理 `.elc`）。
- **别碰** `elpa/`、`var/`、`etc/`、`custom.el`、`server/`；不要提交 `.elc`（已 gitignore），也不要把 `.elc` 留在工作区——交互会话 `load-prefer-newer` 为 nil，旧 `.elc` 会盖过更新的 `.el`。
- **运行期文件一律走 `var/` / `etc/`**（全量 profile 由 no-littering 统一收编；精简 profile 手动指了
  `savehist-file` / `package-quickstart-file`）。新加的包若往仓库根写文件，先看 no-littering 有没有覆盖，
  没有就显式把它的路径指进 `var/`，**别让根目录再长出运行期文件**。
  ⚠ 尤其是 `package-quickstart.el`：根目录一旦有过期的那份，会被 `package-activate-all` 当成激活清单
  读走，导致大批包"装了却没激活"（dump 踩过这个坑，见 pdump 笔记）。
- 包源用 USTC 镜像；**只在 `lisp/init-mirrors.el` 里改**（全量/精简/dump 都 require 它，不要再在别处写 `package-archives`）。
- 路径别硬编码 `~/.emacs.d/`，一律用 `user-emacs-directory`。Windows 上 Git Bash 等会设 `HOME`，
  届时 `~/.emacs.d` 指向 `C:\Users\<user>\.emacs.d`，而本仓库在 `%APPDATA%\.emacs.d`，两者不是一个地方。
- **多平台代码怎么归位**（目前只有 Windows 是真实平台，Linux/macOS 分支未经验证，别为它们新建
  `init-linux.el`/`init-mac.el` 占位——等哪天真有对应机器要跑，再照那台机器的实际情况建、验证）：
  - **某平台专属、没有别的模块会调用**（一次性设置全局变量/环境变量）→ `lisp/init-<os>.el`
    （如 `init-windows.el`），整个文件 `(when (eq system-type '<os>) ...)` 包起来，由
    `early-init.el` 绝对路径 `load`。
  - **跨平台功能，只是实现因平台而异** → 留在功能所属的模块里，一个函数内部按 `system-type`
    `cond`/`pcase` 分支，不要因为某个分支代码长就把整个功能搬去 OS 文件（一个能力的所有平台
    分支应该在同一处看全）。
  - 例外：**同一份跨平台功能要被全量 `lisp/init-*.el` 和精简 `init-minimal.el` 两条不相交的
    加载路径共用**（如 `lisp/init-ime.el` 的输入法切换）→ 单开一个按能力命名（不是按 OS
    命名）的文件，走 `early-init.el` 的绝对路径 `load`，两套 profile 都能吃到。

# AGENTS.md
个人 Emacs 配置仓库（Emacs Lisp）。本文件是 **AI 协作的单一事实源**：项目规范、构建/运行/开发流程都写在这里。与具体 agent 无关的通用流程文档放在 `.agent/`。

> 平台：Windows（scoop 工具链，`emacs` / `make` / `git` 均在 PATH）。命令以 PowerShell 给出。
> **emacs 是在 msys2 UCRT64 环境里从上游源码自编的 Emacs 31**（msys2 由 scoop 装，
> 装在 `<scoop>\apps\msys2\current\ucrt64`），PATH 上是 scoop shim 指过去的；带 native-comp。
> 升级 = 回源码树 `git pull` 重编重装，**不是** `pacman -Syu`（那只升 msys2 的库）。
> ⚠ 别改用 pacman 装的 `mingw-w64-ucrt-x86_64-emacs`：MSYS2 自家的 `001-ucrt.patch` 破坏了
> stdout，那份的 `--batch` 没有任何控制台输出，本仓库靠读 batch 输出的流程
> （靠读 batch 输出判成败）会全部变成睁眼瞎。装法、坑、分步 install 见
> [docs/notes/emacs-install-msys2.md](docs/notes/emacs-install-msys2.md)。

## 这个项目是什么

一套模块化的 Emacs 配置（Emacs 31+）。功能模块放在 `user-lisp/` 下，由 Emacs 31 的
**user-lisp 机制**（`prepare-user-lisp`）在启动时自动接管：把 `user-lisp/` 及其子目录加入
`load-path`，对改动过的文件按需字节编译，并生成 autoload。因此 `init.el` 直接 `require`
即可，不再手动改 load-path，也没有 profile 分发。

启动链：`early-init.el` →（Emacs 处理 user-lisp）→ `init.el` → `require` 各 `init-xxx` 模块。

## Agent 命令文档（`.agent/`）

与具体 agent 无关的通用流程文档放 `.agent/`，任何 agent 都可直接读：

- [.agent/run.md](.agent/run.md) — 批处理加载冒烟验证。
- [.agent/bench.md](.agent/bench.md) — 测本机启动速度，追加到 `docs/startup-benchmark.md`。

## 目录结构

| 路径 | 作用 |
|------|------|
| `early-init.el` | GC 延迟、native-comp、**早期初始化包**（`package-enable-at-startup nil` + `(package-initialize)`，须早于 user-lisp 自动编译）、init 期抑制重绘/回显、收窄编译告警、首装签名校验兜底；用绝对路径 `load` `user-lisp/init-windows` 与 `user-lisp/evil-plugins/ime` |
| `init.el` | 顶层启动：声明包列表（`use-package … :ensure t :defer t`）+ `require` 各模块 |
| `user-lisp/` | 功能模块目录，由 Emacs 31 user-lisp 机制自动加入 load-path 并字节编译/生成 autoload |
| `user-lisp/init-*.el` | 各功能模块（每个 `(provide 'init-xxx)`） |
| `user-lisp/init-windows.el` | Windows 专项、无其它调用方的设置（文件属性/管道调优、控制台+剪贴板编码、git 环境变量…），非 Windows 平台空操作。由 `early-init.el` 最早期绝对路径 `load`。新增纯 OS-only 代码都加进这一个文件；跨平台功能不放这里 |
| `user-lisp/evil-plugins/ime.el` | 跨平台输入法切换（`my/switch-to-english-input-method`，Windows 用 im-select.exe / Linux·macOS 用 fcitx5-remote）。由 `early-init.el` 绝对路径 `load` |
| `user-lisp/init-mirrors.el` | **包源镜像的唯一定义处**（`init.el` require 它，换镜像只改这一个文件） |
| `user-lisp/init-bars.el` | **mode-line + tab-line** 的入口：两条 bar 共用的工具函数 + 字号/内边距统一设置（放一起改才不会顾此失彼）。本体 `require` 自 `user-lisp/mode-line`、`user-lisp/tab-line`。须在 `init-ui` 之后加载，复用其字体选择结果 |
| `user-lisp/mode-line/init-mode-line.el` | mode-line 实现本体，`(provide 'init-mode-line)`，由 `init-bars.el` `require` |
| `user-lisp/tab-line/init-tab-line.el` | tab-line 实现本体，`(provide 'init-tab-line)`。⚠ 特意不叫 `tab-line.el`：user-lisp 会把子目录**前置**到 load-path，叫 `tab-line.el` 会盖住内置库 |
| `user-lisp/eshell-prompt/init-eshell-prompt.el` | eshell 提示符实现本体，由 `init-term.el` `require` |
| `user-lisp/evil-plugins/` | evil 相关插件合集：**内联**的 `evil-surround` / `evil-commentary`(+integration) / `evil-visualstar`（GPLv3），以及本仓库的 `evil-config.el` / `evil-keymaps.el` / `evil-vc.el` / `evil-dired.el` / `evil-ibuffer.el` / `evil-extra.el` / `evil-textobjects.el`(停用) / `mc-evil.el` / `ime.el`。见其 `README.md` |
| `user-lisp/gcmh/gcmh.el` | **内联**的 `gcmh`（GC 调优，GPLv3），由 `init-base.el` `require`。见其 `README.md` |
| `user-lisp/lang-*.el` | 语言专属配置（如 `lang-go.el`，当前未启用） |
| `themes/` | 本仓库自维护的主题文件（`*-theme.el`），由 `custom-theme-load-path` 接入（`user-lisp/init-ui.el`），新增主题放进去即可被 `switch-emacs-theme` 自动发现。共 5 个：`nn-world`（借自 zdn/.emacs.d，GPLv3，默认主题）、`catppuccin`/`crafters`/`gits`/`matrix` |
| `assets/fonts/` | vendor 进仓库的字体文件（OFL 等自由许可），配 `scripts/install-fonts.py` 装进当前用户。见 [docs/notes/vendored-fonts.md](docs/notes/vendored-fonts.md) |
| `custom.el` | Customize 自动生成，**已 gitignore，勿手改** |
| `elpa/` | 第三方包，**已 gitignore，勿编辑/勿提交** |
| `var/` `etc/` | no-littering 收编的运行期文件，**已 gitignore，勿手改** |
| `docs/` | 配置笔记，`docs/notes.md` 是索引，正文在 `docs/notes/*.md` |
| `README.md` | 简洁项目介绍 + 文档入口（规范/流程仍以本文件为准） |
| `docs/startup-benchmark.md` | 多机启动速度基准记录 + 测法 |
| `scripts/bench-startup.py` | 跨平台测速脚本：采集机器信息 + 真实 GUI 启动耗时，输出/追加基准块 |
| `scripts/make-shortcuts.py` | Windows：在开始菜单建 Emacs 快捷方式（指向 `runemacs.exe`）。需 `pip install pywin32` |
| `scripts/install-fonts.py` | Windows：把 `assets/fonts/` 里 vendor 的字体装进当前用户（不需要管理员）。只用标准库 |

当前启用的模块（见 `init.el` 末尾）：`init-base` `init-ui` `init-bars` `init-window`
`init-completion` `init-dired` `init-git` `init-term` `init-project` `init-keymaps`
`init-lsp` `init-format` `init-navigation`，以及 `user-lisp/evil-plugins/` 下的
`evil-config` `evil-keymaps` `evil-vc` `evil-dired` `evil-ibuffer` `evil-extra` `mc-evil`（`ime` 由 `early-init.el` 加载）。
其中 **`evil-config` 由 `init.el` 在 `after-init-hook`（depth -99）才 `require`**，让 evil 的加载
不计入 `emacs-init-time`；故 `evil-keymaps`/`init-completion` 取 `evil-define-key` 宏改用
`eval-when-compile`。
`init-ai` / `evil-plugins/evil-textobjects` / `lang-go` 已写好但注释停用（停用模块的
`use-package` 用 `:ensure nil`，避免 user-lisp 自动字节编译时联网装包；启用前先装好对应包）。

`init-format`（apheleia，非 LSP 场景的格式化；`SPC f` = `my/format-buffer` 统一入口，按 buffer
是否有 eglot 托管自动分流到 eglot-format 或 apheleia-format-buffer）与
`init-navigation`（citre 补 eglot/xref 覆盖不到的场景；citre 需要本机装 Universal Ctags，没装就
整个不加载）借鉴自 zdn/.emacs.d。跳转键位统一到标准 xref 入口（`gd`/`M-.`/`M-,`/`M-?`）；
citre 只留一个不可替代的命令：`SPC p`（`citre-peek`）。
看文档键：`gh` = `my/doc-at-point`（`user-lisp/init-base.el`）。

## 构建 / 编译 = user-lisp 自动处理

Emacs 31 的 user-lisp 机制在启动时会：

1. 把 `user-lisp/` 及其子目录加入 `load-path`；
2. 对新增/改动过的 `.el` **按需字节编译**（生成 `.elc`，native-comp 可用时异步再编译），
   首次或改文件后有一次编译开销；
3. 生成 `user-lisp/.user-lisp-autoloads.el` 并加载。

这些产物都已 gitignore。**没有独立的构建步骤**——直接启动 `emacs` 即可。
若怀疑某个 `.elc` 陈旧/损坏（交互会话 `load-prefer-newer` 为 nil 会优先用它），删掉对应
`.elc`（或 `M-x prepare-user-lisp` 带前缀强制重建），下次启动会按需重编。

> ⚠ 两个**必须在 `early-init.el` 里设好、别改回去**的开关：
> - **包初始化必须在 `early-init` 完成**（`package-enable-at-startup nil` + `(package-initialize)`）：
>   user-lisp 的自动字节编译发生在 init **之前**，若那时包还没激活（evil/gcmh/hydra… 不在
>   load-path），编译会失败并把错误刷进 `*Compile-Log*`。`init.el` 用
>   `(unless package--initialized …)` 守卫，避免重复初始化（`package-initialize` 每次都会做全量
>   load-all-descriptors / read-archive-contents / activate-all，很重）。
> - **收窄 `byte-compile-warnings`**（`(not free-vars unresolved obsolete interactive-only lexical)`）：
>   本配置大量"先 `setq` 包变量、用时才加载"，编译必然产生成片此类良性告警；真正的
>   语法 / 宏错误仍会暴露（运行时也会立刻报）。

## 字节编译与 .elc（重要）

因为 user-lisp 机制会自动字节编译，`.elc` 成为实际加载物（交互会话 `load-prefer-newer` 为 nil，
优先 `.elc`）。前提是编译时包已激活——见上「构建 / 编译」的 `package-enable-at-startup` 说明。
下面这条是**硬性要求**：

- **文件顶层（含 `with-eval-after-load` 体内）用到某个包的宏时，必须在文件顶层 `(require '那个包)`。**
  否则字节编译器把宏当函数编译进 `.elc`，运行时报 `Invalid function: <宏名>`。
- 已知需要（取 evil 宏）：
  - `evil-plugins/evil-config.el`、`evil-plugins/evil-textobjects.el` → `(require 'evil)`（这俩本身在 evil 加载后才被载入）
  - `evil-plugins/evil-keymaps.el`、`init-completion.el` → `(eval-when-compile (require 'evil))`
    —— evil 已延迟到 after-init 加载，运行时不能 require，只需编译期取宏
  - `init-ai.el`、`lang-go.el` → `(require 'use-package)`
  （`defhydra` 等有 autoload cookie 的宏会被编译器自动加载，不需要显式 require。）
- 详见 [docs/notes/byte-compile-broken-elc.md](docs/notes/byte-compile-broken-elc.md)。

## 验证配置是否能正常加载

`--batch` 下 user-lisp 机制不生效（`init-file-user` 为空），需先手动把 `user-lisp/` 及其
子目录加入 load-path 再加载。完整命令见 [.agent/run.md](.agent/run.md)（在仓库根执行）：

```powershell
emacs --batch `
  --init-directory "$PWD" `
  --eval '(dolist (d (list "user-lisp" "user-lisp/evil-plugins" "user-lisp/gcmh" "user-lisp/mode-line" "user-lisp/tab-line" "user-lisp/eshell-prompt")) (add-to-list (quote load-path) (expand-file-name d user-emacs-directory)))' `
  -l "$PWD\early-init.el" -l "$PWD\init.el" `
  --eval '(message "== CONFIG LOADED OK ==")' 2>&1 | Select-Object -Last 12
```

出现 `== CONFIG LOADED OK ==` 且 `EXIT=0` 即通过。注意批处理无 GUI，只验证「能否无错加载」；
**视觉外观**（字体、主题、modeline、tab-line）仍需启动真实 Emacs 肉眼确认：

```powershell
emacs                          # 真实 GUI，看 *Messages* / *Warnings*
```

## AI 代码补全（minuet）

`user-lisp/init-ai.el`（当前停用）用 minuet 接 SiliconFlow。密钥**不写进配置**，从环境变量读取：

```powershell
$env:SILICONFLOW_API_KEY = "sk-xxxx"   # 由用户在自己的 shell/系统环境设置
```

`init-ai.el` 里 `:api-key` 传的是**环境变量名字符串**，由 minuet 自行 `getenv`。切勿把真实密钥硬编码进任何文件。

## 维护约定（判断式，非强制）

- **改了行为/加了模块** → 同步更新本文件相关小节（结构表、启用模块列表、命令）。纯重构 / 小修可不动文档。
- **新增模块**：在 `user-lisp/` 下建 `init-xxx.el`，文件末 `(provide 'init-xxx)`，并在 `init.el` 末尾 `(require 'init-xxx)`。
- **改完怎么验证**：批处理加载见 [.agent/run.md](.agent/run.md)；再启动真实 GUI 看 `*Messages*` / `*Warnings*`。
- **别 eager `require` 会连带拉起重库的包**：例如 `fd-dired` 顶层 require `find-dired`/`ibuffer`/
  `ibuf-ext`，`find-dired` 又拉起 `dired`——启动时 eager `(require 'fd-dired)` 实测多花 ~0.4s。
  这类包用 `use-package … :defer t` 即可，命令靠 autoload，首次用时再加载。
- **别碰** `elpa/`、`var/`、`etc/`、`custom.el`、`server/`；不要提交 `.elc` 或 `.user-lisp-autoloads.el`（已 gitignore）。
- **运行期文件一律走 `var/` / `etc/`**（全量 profile 由 no-littering 统一收编）。新加的包若往仓库根写文件，
  先看 no-littering 有没有覆盖，没有就显式把它的路径指进 `var/`，别让根目录再长出运行期文件。
- 包源用 USTC 镜像；**只在 `user-lisp/init-mirrors.el` 里改**。
- 路径别硬编码 `~/.emacs.d/`，一律用 `user-emacs-directory`。Windows 上 Git Bash 等会设 `HOME`，
  届时 `~/.emacs.d` 指向 `C:\Users\<user>\.emacs.d`，而本仓库在 `%APPDATA%\.emacs.d`，两者不是一个地方。
- **多平台代码怎么归位**（目前只有 Windows 是真实平台，Linux/macOS 分支未经验证）：
  - **某平台专属、没有别的模块会调用** → `user-lisp/init-<os>.el`，整个文件 `(when (eq system-type '<os>) ...)`
    包起来，由 `early-init.el` 绝对路径 `load`。
  - **跨平台功能，只是实现因平台而异** → 留在功能所属模块里，一个函数内部按 `system-type`
    `cond`/`pcase` 分支。
  - 例外：**被 `early-init.el` 阶段就要加载**的跨平台能力（如输入法切换 `user-lisp/evil-plugins/ime.el`）→
    单开一个按能力命名（不是按 OS 命名）的文件，走 `early-init.el` 绝对路径 `load`。

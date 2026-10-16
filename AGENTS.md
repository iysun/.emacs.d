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
- [.agent/check-comments-only.el](.agent/check-comments-only.el) — 校验「只改了注释、代码没动」（解析成 sexp 比对）。

## 目录结构

| 路径 | 作用 |
|------|------|
| `early-init.el` | GC 延迟、native-comp、**早期激活包**（`package-enable-at-startup nil` + `package-quickstart` + `(package-activate-all)`，须早于 user-lisp 自动编译；快照缺失时自动 `package-quickstart-refresh`）、init 期抑制重绘/回显、收窄编译告警、首装签名校验兜底；用绝对路径 `load` `user-lisp/init-windows` 与 `user-lisp/evil-plugins/ime` |
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
| `user-lisp/init-parens.el` | **括号显示**：默认很淡（`my-paren-face`）+ 光标处强调（`show-paren` 反显加粗）。机制**改编自 rainbow-delimiters**（GPLv3），只保留"走括号 + 跳过字符串/注释/转义/双字符 opener"的必要代码、砍掉深度配色机器，故不再依赖 `rainbow-delimiters`；淡色按主题 fg/bg 现场混合（用 `init-ui` 的 `my-ui--*`，须在其后 `require`） |
| `user-lisp/evil-plugins/` | evil 相关插件合集：**内联**的 `evil-surround` / `evil-commentary`(+integration) / `evil-visualstar`（GPLv3），以及本仓库的 `evil-config.el` / `evil-keymaps.el` / `evil-vc.el` / `evil-dired.el` / `evil-ibuffer.el` / `evil-extra.el` / `mc-evil.el` / `ime.el`。见其 `README.md` |
| `user-lisp/gcmh/gcmh.el` | **内联**的 `gcmh`（GC 调优，GPLv3），由 `init-base.el` `require`。见其 `README.md` |
| `themes/` | 本仓库自维护的主题文件（`*-theme.el`），由 `custom-theme-load-path` 接入（`user-lisp/init-ui.el`），新增主题放进去即可被 `switch-emacs-theme` 自动发现。共 13 个：`nn-world`（借自 zdn/.emacs.d，GPLv3，**模板**）、`catppuccin`/`crafters`/`gits`/`matrix`，深色 `gruvbox-dark`/`nord`/`dracula`/`monokai-pro`，浅色 `gruvbox-light`/`catppuccin-latte`/`solarized-light`/`one-light`（后 8 个都照 nn-world 模板换 24 槽调色板生成，结构与 face 表一致）。Emacs 自带的 `modus-vivendi`/`modus-operandi` 等也在候选里 |
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

当前启用的模块（见 `init.el` 末尾）：`init-base` `init-ui` `init-parens` `init-bars` `init-window`
`init-completion` `init-dired` `init-git` `init-term` `init-project` `init-keymaps`
`init-lsp` `init-format` `init-navigation`，以及 `user-lisp/evil-plugins/` 下的
`evil-config` `evil-keymaps` `evil-vc` `evil-dired` `evil-ibuffer` `evil-extra` `mc-evil`（`ime` 由 `early-init.el` 加载）。
其中 **`evil-config` 由 `init.el` 在 `after-init-hook`（depth -99）才 `require`**，让 evil 的加载
不计入 `emacs-init-time`；故 `evil-keymaps`/`init-completion` 取 `evil-define-key` 宏改用
`eval-when-compile`。
**分词口径**（`evil-config.el`）：`w`/`b`/`e` 与 `iw`/`aw` 按**整词**（`[[:word:]_-]+`，
即 `fooBarBaz`/`foo-bar-baz`/`foo_bar_baz` 各算一个；实现为把 `forward-evil-word` alias 成整词运动，
`forward-thing 'evil-word` 与 `iw/aw` 的 thingatpt bounds 都走它）；`i SPC w` / `a SPC w` 按
**subword**（camelCase 边界）；`W`/`iW`/`aW` 仍是空白分隔大词。
`*`/`#` 也按整词：evil-search 模块会把 `*` 从 `evil-search-word-forward` 改绑到
`evil-ex-search-word-forward`，后者取词用 Emacs `word`（不含 `-`/`_`），故本仓库重绑为自建的
`my/evil-ex-search-word-{forward,backward}`——取词走 `evil-word`、搜索仍走 evil-ex（`gn`/`cgn` 可用）。
⚠ 首尾的 `-` 会被去掉（如 `-foo` 搜 `foo`、`--flag` 搜 `flag`），因为 `\<`/`\>` 是基于语法表
的词边界、不含 `-`。`g*`/`g#` 已显式解绑（无边界版用不上；visual 态的 `*`/`#` 由 evil-visualstar 提供）。
⚠ 自定义 forward-op 必须返回
「未移动数」（0=成功），否则 `evil-forward-nearest` 的 `(zerop ...)` 会报 wrong-type-argument。
另开 `global-subword-mode`，让 Emacs 自身的 M-f/M-b/M-d 也按 subword 切（evil 侧不依赖它）。

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
> - **包必须在 `early-init` 里激活完成**（`package-enable-at-startup nil` + `package-quickstart t`
>   + `(package-activate-all)`）：user-lisp 的自动字节编译发生在 init **之前**，若那时包还没激活
>   （evil/gcmh/hydra… 不在 load-path），编译会失败并把错误刷进 `*Compile-Log*`。
>   - 用 `package-quickstart`（快照 `var/package-quickstart.el`）把「激活所有包」预计算成一份文件，
>     快照缺失时 early-init 会先 `package-quickstart-refresh` 生成一次（实测启动 ~−0.3s）。
>   - ⚠ 走 quickstart 时 `package--initialized` 仍为 nil，`init.el` 的兜底守卫要用
>     `package--activated`（`package-activate-all` 会置它），**别**再调 `(package-initialize)`
>     （它会做全量 load-all-descriptors/read-archive-contents，抵消 quickstart 收益）。
>   - 快照过期**不报错**，靠 `init.el` 的 `my/check-quickstart-freshness` 告警（早于 `elpa/` 就提醒重建）。
> - **收窄 `byte-compile-warnings`**（`(not free-vars unresolved obsolete interactive-only lexical)`）：
>   本配置大量"先 `setq` 包变量、用时才加载"，编译必然产生成片此类良性告警；真正的
>   语法 / 宏错误仍会暴露（运行时也会立刻报）。

## 字节编译与 .elc（重要）

因为 user-lisp 机制会自动字节编译，`.elc` 成为实际加载物（交互会话 `load-prefer-newer` 为 nil，
优先 `.elc`）。前提是编译时包已激活——见上「构建 / 编译」的 `package-quickstart` 说明。
下面这条是**硬性要求**：

- **文件顶层（含 `with-eval-after-load` 体内）用到某个包的宏时，必须在文件顶层 `(require '那个包)`。**
  否则字节编译器把宏当函数编译进 `.elc`，运行时报 `Invalid function: <宏名>`。
- 已知需要（取 evil 宏）：
  - `evil-plugins/evil-config.el` → `(require 'evil)`（本身在 evil 加载后才被载入）
  - `evil-plugins/evil-keymaps.el`、`init-completion.el` → `(eval-when-compile (require 'evil))`
    —— evil 已延迟到 after-init 加载，运行时不能 require，只需编译期取宏
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
  --eval '(princ "== CONFIG LOADED OK ==\n")' 2>&1 | Select-Object -Last 12
```

出现 `== CONFIG LOADED OK ==` 且 `EXIT=0` 即通过。⚠ 末行必须用 `princ` 而非 `message`：
`early-init.el` 设了 `inhibit-message t`，只靠 `window-setup-hook` 恢复，而 `--batch` 不触发该 hook，
用 `(message ...)` 会被吞掉、永远看不到 OK 字样。注意批处理无 GUI，只验证「能否无错加载」；
**视觉外观**（字体、主题、modeline、tab-line）仍需启动真实 Emacs 肉眼确认：

```powershell
emacs                          # 真实 GUI，看 *Messages* / *Warnings*
```

## 注释规范（硬性：写/改代码的 agent 必须遵守）

- **默认不写注释**。只在 WHY 不显然时写一条：隐藏约束、微妙不变量、特定 bug 的 workaround、
  会让读者意外的行为。（判据与措辞取自 Claude Code 系统提示词的 comment 条款。）
- 自检问句：**删掉这条注释会让将来读代码的人困惑吗？不会就别写。**
- 不写 WHAT（好名字已经说明）；不写「本任务是 / 谁调用 / 对应 issue #123」这类会腐烂的引用。
- 望文生义的注释直接删，不要换个说法重写（`;; 用 rg 做兜底搜索`、
  `(setq completion-ignore-case t)  ; capf 匹配不区分大小写`）。
- 留下的一律压到最短（十几字级别，可加 `⚠`）：`;; ⚠ 必须 setopt：setq 不触发 :set`。
- 头注释最多两行、能删就删（没有非写不可的就别写头注释）；行内注释同样只留最短形式。
- `docstring` 是代码不是注释：行为不显然时写一句，禁止多行注释块。
- **不删别人的注释**——除非同时删掉它描述的代码，或确认它是错的：看似废话的注释可能在记录
  当前 diff 看不出来的教训。（本仓库目前由维护者本人要求成批删减，属显式授权。）
- 改注释**不许动代码**：`.agent/check-comments-only.el` 校验（基线 HEAD 与工作区解析成
  sexp 比对，全部 `代码等价 OK`）+ 字节编译无 warning + `.agent/run.md` 冒烟。

## 维护约定（判断式，非强制）

- **注释一律按上面的「注释规范」写**：默认不写，只在 WHY 不显然时留最短一条；评审代码时先看这条。
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

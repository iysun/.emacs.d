# AGENTS.md

个人 Emacs 配置仓库（Emacs Lisp）。本文件是 **AI 协作的单一事实源**：项目规范、构建/运行/开发流程都写在这里，其他 agent 适配文件（`CLAUDE.md`、`.cursor/rules/`）只做引用，不复制内容。

> 平台：Windows（scoop 工具链，`emacs` / `make` / `git` 均在 PATH）。命令以 PowerShell 给出。

## 这个项目是什么

一套模块化的 Emacs 配置，支持两套 profile：

- **全量（full，默认）**：`init.el` 加载 `lisp/init-*.el` 各模块（evil、补全、UI、LSP、magit…）。
- **精简（minimal）**：单文件 `init-minimal.el`，只含 evil + 内置 project/eglot + completion-preview。

启动链：`early-init.el` → `init.el`（profile 分发器）→ `init-minimal.el` 或 `lisp/init-*.el`。

## AI 工具入口

为本仓库生成的命令 / 规则（详见各 agent 适配层）：

- **`/build`**（Claude Code，`.claude/commands/build.md`）：字节编译-修复循环。
- **`/run`**（Claude Code，`.claude/commands/run.md`）：批处理加载冒烟验证循环。
- Cursor：`.cursor/rules/project.mdc`（始终生效）+ `*.el` 条件规则，指向本文件。
- Codex：原生读取本 `AGENTS.md`，无需额外文件。

## 目录结构

| 路径 | 作用 |
|------|------|
| `early-init.el` | GC 延迟、native-comp、包系统早期开关、首装签名校验兜底 |
| `init.el` | profile 分发；全量下声明包列表 + `require` 各模块 |
| `init-minimal.el` | 精简 profile 全部内容（与 `init.el` 同级，按路径 load） |
| `lisp/init-*.el` | 全量 profile 的功能模块（每个 `(provide 'init-xxx)`） |
| `lisp/lang-*.el` | 语言专属配置（如 `lang-go.el`，当前未启用） |
| `custom.el` | Customize 自动生成，**已 gitignore，勿手改** |
| `elpa/` | 第三方包，**已 gitignore，勿编辑/勿提交** |
| `docs/` | 配置笔记，`docs/notes.md` 是索引，正文在 `docs/notes/*.md`（按需读取） |

当前启用的模块（见 `init.el` 末尾）：`init-base` `init-evil` `init-ui` `init-window`
`init-completion` `init-dired` `init-git` `init-term` `init-project` `init-mc`
`init-keymaps` `init-lsp`。`init-ai` / `init-evil-plugins` / `lang-go` 已写好但注释停用。

## 文档（docs/）

项目笔记放在 `docs/`，采用「索引 + 按需读取」结构（渐进式上下文）：

- **`docs/notes.md`** 是索引：每条一行 `- [标题](notes/slug.md) — 何时该读`，描述即"要不要展开读"的路由信号。
- 正文按主题拆到 **`docs/notes/*.md`**（英文 kebab-case 文件名，内容中文）。
- **维护纪律**：新增笔记 = 在 `notes/` 加一篇 + 在 `docs/notes.md` 补一行。
- 改动牵涉某主题（构建/编译、profile、镜像安装、AI 补全…）时，先查 `docs/notes.md` 有无相关笔记。

关于字节编译的细节见 [docs/notes/byte-compile-broken-elc.md](docs/notes/byte-compile-broken-elc.md)。

## 字节编译与 .elc

曾有一处脆弱点：多个模块在**顶层**用 evil 宏（`init-evil.el` 的 `evil-define-text-object`、
`init-keymaps.el` 的 `evil-define-key`），而字节编译期未加载 evil，编译器把宏当函数编译，
产出坏 `.elc`（加载报 `void-variable evil-a-between` / `Invalid function: evil-define-key`）。

**已修复**：在 `init-evil.el` / `init-keymaps.el` / `init-evil-plugins.el` 顶层加了 `(require 'evil)`
（byte-compiler 会执行顶层 `require`，使宏在编译期可用）。现在 `make compile` 产出的 `.elc` 正确、可加载。

仍需知道的两点：

- **本仓库约定加载 `.el` 源码**（`.elc` 已 gitignore，不提交）。
- 交互会话里 `load-prefer-newer` 为 nil（见 `early-init.el`），**残留的旧 `.elc` 会悄悄盖过更新的 `.el`**。
  所以编译只用于检查；检查完把自己的 `.elc` 清掉，回到源码加载（`make clean` 在 Windows 因 GNU find 失效，改用）：
  ```powershell
  Get-ChildItem -Path .,lisp -Filter *.elc -File | Remove-Item -Force
  ```
  `/build` 命令已内置「编译→清理」，优先用它。

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
- **别碰** `elpa/`、`custom.el`、`server/`；不要提交 `.elc`（已 gitignore），也不要把 `.elc` 留在工作区——交互会话 `load-prefer-newer` 为 nil，旧 `.elc` 会盖过更新的 `.el`。
- 包源用 USTC 镜像（见 `init.el`）；切镜像时全量与精简两处都要改。

---
name: build
description: 字节编译本仓库 .el 做 lint（抓语法错误与编译警告），编译后自动清理 .elc 回到源码加载
---

对本 Emacs 配置跑「字节编译-修复」循环。字节编译是本项目事实上的 lint。

> 本仓库约定**加载 `.el` 源码**（`.elc` 已 gitignore）。交互会话 `load-prefer-newer` 为 nil，
> 残留旧 `.elc` 会悄悄盖过更新的 `.el`。**所以本命令编译只为检查，结束时清理 `.elc`。**

## 循环

1. **只编译本仓库源文件**（避开 `elpa/` 噪音）：

   ```powershell
   $own = @('early-init.el','init.el','init-minimal.el') + (Get-ChildItem lisp\*.el | ForEach-Object FullName)
   emacs --batch -Q `
     --eval "(setq user-emacs-directory (file-name-as-directory (expand-file-name `".`")))" `
     --eval "(add-to-list 'load-path (expand-file-name `"lisp`" user-emacs-directory))" `
     --eval "(setq package-user-dir (expand-file-name `"elpa`" user-emacs-directory))" `
     --eval "(require 'package)" --eval "(package-initialize)" `
     -f batch-byte-compile $own 2>&1
   ```

2. **清理生成的 `.elc`**（每次都做，无论成败）：

   ```powershell
   Get-ChildItem -Path .,lisp -Filter *.elc -File | Remove-Item -Force
   ```

3. **读输出，分类**：
   - **必须修**：`Error`、`void-function`、`void-variable`、`Wrong number of arguments`、
     `unbalanced parentheses`、`End of file during parsing`、`Cannot open load file`（缺 require / 模块顺序错）。
     报错带 `文件:行:列`，直接定位修。
   - **可忽略的噪音**：对包提供的变量报 `assignment to free variable` / `reference to free variable`
     （如 `evil-want-*`、`doom-themes-*`、`completion-preview-*`、`tab-line-*`）——`-Q` 下相关包未加载所致，属预期。
   - **停用模块的安装报错**：`init-ai.el`（minuet）、`lang-go.el`（go-mode）当前注释停用，
     单独编译会触发 `:ensure t` 联网装包，可能报 `Failed to install …`。未启用则忽略。

   > 注：顶层用 evil 宏的模块（`init-evil.el` / `init-keymaps.el` / `init-evil-plugins.el`）已在文件顶层
   > `(require 'evil)`，编译期宏可解析。若再看到 `void-variable evil-a-between` /
   > `Invalid function: evil-define-key`，说明那个 require 被误删了——补回去。

4. **修完**回到 1 重编，直到无「必须修」级别问题。

5. **收尾**：确认工作区已无 `.elc`（第 2 步）。正确性/加载验证用 `/run`。
   如改动涉及模块结构或命令，按 `AGENTS.md` 判断式约定看是否要更新文档。

---
name: run
description: 批处理加载验证配置能否无错加载；改完配置后的快速自检
---

验证本 Emacs 配置能否干净加载：用 `--batch` 加载（无 GUI，只验证「能否无错加载」）。
**视觉外观**（字体、主题、modeline、tab-line 等）仍需启动真实 Emacs 肉眼确认。

## 用法

Emacs 31 的 user-lisp 机制在 `--batch` 下不会自动生效（`init-file-user` 为空，
`prepare-user-lisp` 不运行），所以要先手动把 `user-lisp/` 及其子目录加进 load-path，
再加载 `early-init.el` + `init.el`。在仓库根目录执行：

```powershell
emacs --batch `
  --init-directory "$PWD" `
  --eval '(dolist (d (list "user-lisp" "user-lisp/evil-plugins" "user-lisp/gcmh" "user-lisp/mode-line" "user-lisp/tab-line" "user-lisp/eshell-prompt")) (add-to-list (quote load-path) (expand-file-name d user-emacs-directory)))' `
  -l "$PWD\early-init.el" -l "$PWD\init.el" `
  --eval '(message "== CONFIG LOADED OK ==")' 2>&1 | Select-Object -Last 12
Write-Output "EXIT=$LASTEXITCODE"
```

出现 `== CONFIG LOADED OK ==` 且 `EXIT=0`、无回退错误即视为通过。

## 判断有无问题

- **有 bug 要修**：`Cannot open load file`（缺文件/缺 require）、`void-function`、`void-variable`、
  `Symbol's value as variable is void`、`Invalid function: <宏名>`（字节编译期该宏没被加载 → 坏
  `.elc`，见 [docs/notes/byte-compile-broken-elc.md](../../docs/notes/byte-compile-broken-elc.md)）。
- **可忽略**：包里字节编译期的 obsolete/deprecation 警告、`assignment to free variable`
  （多为 -Q 无关变量），不是错误。

## 启动真实 GUI 复核

- 启动 `emacs`，看 `*Messages*` 与 `*Warnings*`。
- user-lisp 机制会在启动时对 `user-lisp/` 按需字节编译（首次或改文件后有一次编译）。

## 注意

- 不要装/删包在 `elpa/`；不要改 `custom.el`。
- `.elc` / `.user-lisp-autoloads.el` 由 user-lisp 机制自动产生且已 gitignore，勿手动提交；怀疑陈旧时删掉对应 `.elc`，下次启动按需重编。

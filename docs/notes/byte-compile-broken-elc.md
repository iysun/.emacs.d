# 字节编译与 .elc（宏必须在顶层 require）

## 背景：user-lisp 机制会自动字节编译

Emacs 31 的 user-lisp 机制在启动时对 `user-lisp/` 下**新增/改动过的** `.el` 自动字节编译，
交互会话 `load-prefer-newer` 为 nil → 实际加载的是 `.elc`。因此「字节编译产物必须正确」
从"可选项"变成**硬约束**。

> 前提：编译时包必须已激活。`early-init.el` 里 `package-enable-at-startup` 必须为 **t**
> ——user-lisp 的自动编译发生在 init（`package-initialize`）**之前**，若包未激活，
> 编译会报 `Cannot open load file: evil/gcmh…` 并把错误刷进 `*Compile-Log*`。

## 现象

启动报：

```
Invalid function: evil-define-key
Symbol's value as variable is void: evil-a-between
```

## 根因

`evil-define-key` / `evil-define-text-object` 都是**宏**。而 `evil` 的 `evil-define-key`
**不是** autoload 宏——若编译该文件时 evil 尚未加载，byte-compiler 看不到宏定义，就把
`evil-define-key` 当**函数**编译进 `.elc`，运行到该调用时报 `Invalid function`。

（对比：`defhydra` 这类带 autoload cookie 的宏，编译器会自动加载对应库，不需要显式 require。
`with-eval-after-load` 体内同样会被编译，不能因为是"延迟执行"就省掉 require。）

## 规则

**文件顶层用到某个包的宏时，必须在文件顶层 `(require '那个包)`。** byte-compiler 会执行
顶层 `require`，使宏在编译期可用；源码加载时也保证宏先于使用处可用。

已知需要：

- `init-evil.el`、`init-keymaps.el`、`init-completion.el`、`init-evil-plugins.el` → `(require 'evil)`
  - `init-evil.el` 的 `(require 'evil)` 必须放在 `evil-want-*` 那组 `setq` **之后**
    （`evil-want-*` 要在 evil 加载前设好）。
- `init-ai.el`、`lang-go.el` → `(require 'use-package)`

## 排查方法

- 启动时的自动字节编译、或 `/run`（批处理加载）都会暴露编译期问题；
- 再启动真实 GUI 看 `*Messages*` / `*Warnings*`。

## 清理

生成的 `.elc` 已 gitignore；怀疑陈旧时直接删掉对应 `.elc`（或 `user-lisp/.user-lisp-autoloads.el`），下次启动会按需重编。

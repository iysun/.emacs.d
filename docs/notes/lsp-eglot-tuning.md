# eglot / LSP 手感调优（含两个静默失效的陷阱）

配置在 `lisp/init-lsp.el`。这里只记**为什么这么设**，以及踩过的坑。

## ⚠ `eglot-events-buffer-size` 是个静默失效的陷阱

**结论：不要用它，改用 `eglot-events-buffer-config`。**

`eglot-events-buffer-size` 自 eglot 1.16 起废弃。它**不是**别名——整个 eglot 里只有一处读它：

```elisp
;; eglot.el
(defcustom eglot-events-buffer-config
  (list :size (or (bound-and-true-p eglot-events-buffer-size) 2000000)
        :format 'full)
  ...)
```

也就是说它只在 **eglot 加载那一刻**、作为新变量 defcustom 默认值的一部分被读一次。
写在 `(with-eval-after-load 'eglot ...)` 里必然太晚——那时 defcustom 早已求值完毕。

本仓库此前就是这样：

```elisp
(with-eval-after-load 'eglot
  (setq eglot-events-buffer-size 0))   ; ← 一直没生效
```

实测复现：

```
(require 'eglot) 之后 (setq eglot-events-buffer-size 0)
→ eglot-events-buffer-config 仍是 (:size 2000000 :format full)
```

**正确写法**（可以放在 `with-eval-after-load` 里，它是普通 defcustom）：

```elisp
(setq eglot-events-buffer-config '(:size 0 :format short))
```

> 注意别写成 `'(:size 0 :format 'short)`——多一层 quote，`:format` 会变成 `(quote short)`
> 而不是符号 `short`。（这是从别的配置抄来时的常见错误。）

**教训**：Emacs 里"设了个废弃变量却没报错"是常态，因为 `setq` 对未绑定符号一样成功。
凡是看到 `make-obsolete-variable`，去看新变量**在哪里、什么时候**读旧值——很多是只在加载期读一次。

## ⚠ `treesit-enabled-modes` 必须用 `setopt`，`setq` 静默失效

**结论：凡是带 `:set` 处理器的 defcustom，一律用 `setopt`。**

Emacs 31 内置 `treesit-enabled-modes` 取代第三方 treesit-auto。但它的 defcustom 长这样
（`treesit.el:5856`）：

```elisp
(defcustom treesit-enabled-modes nil
  ...
  :set (lambda (sym val)
         (set-default sym val)
         (when (treesit-available-p)
           (dolist (m treesit-major-mode-remap-alist)
             (if (or (eq val t) (memq (cdr m) val))
                 (add-to-list 'major-mode-remap-alist m)
               ...)))))
```

**真正干活的是 `:set`**——它才是把 `treesit-major-mode-remap-alist` 灌进
`major-mode-remap-alist` 的那一步。`setq` 只改变量值、不触发 `:set`，于是一条 remap 都不生成。

实测（Emacs 31.0.91）：

| 写法 | `major-mode-remap-alist` 条数 |
|---|---|
| `(setq treesit-enabled-modes t)` | **0** |
| `(setopt treesit-enabled-modes t)` | 26 |

**连带后果**比表面严重：`init-lsp.el` 的 `eglot-ensure` 全部挂在 `*-ts-mode-hook` 上，
remap 没生成 → 打开 .go/.py 进的是原生 mode → **eglot 根本不会启动**。
而且从头到尾没有任何报错。

`setopt` 会自动 `require` treesit（`treesit-enabled-modes` 的 defcustom 带 autoload cookie），
不需要手动 require。

**为什么列白名单而不是写 `t`**：`t` 会 remap 全部 26 个 ts-mode，包括本机没装 grammar 的；
打开对应文件时 `treesit-auto-install-grammar`（默认 `'ask`）会拦下来问要不要现场编译 grammar。
显式列表等价于旧版逐语言 `treesit-ready-p` 把关：缺 grammar 的语言留在原生 mode，安静可预期。
Windows 上 grammar DLL 常因 ABI 不匹配加载失败，这一点尤其重要。
当前被排除的：`c` / `c-or-c++`（缺 c grammar）、`typescript`、`tsx`、`bash`、`csharp`、`cmake`。
装了新 grammar 记得往 `init-lsp.el` 的列表里加。

**教训（与上一节同源，但触发机制不同）**：上一节是「新变量只在加载期读一次旧值」，
这一节是「变量的副作用全在 `:set` 里」。两者的共同点是 **`setq` 永远不会报错**。
判据：`C-h v` 看变量，文档末尾若有 "This variable has a custom `:set` function" 或
去源码看 defcustom 有没有 `:set` / `:initialize`——有就用 `setopt`。

## 日志开销要掐两层

1. `eglot-events-buffer-config` 的 `:size 0` → 不**保留**事件内容。
2. `(fset #'jsonrpc--log-event #'ignore)` → 不**构造**日志对象。

只做 1 的话，每条 LSP 消息仍会走一遍 `jsonrpc--log-event` 的构造逻辑。高频编辑时这部分不可忽略。

代价：`M-x eglot-events-buffer` 永远是空的。**要抓 LSP 协议时**把 `fset` 那行注释掉，
并把 `:size` 调大（如 `2000000`），重启 Emacs。

## 关掉的服务端能力

```elisp
(setq eglot-ignored-server-capabilities
      '(:inlayHintProvider          ; 通知量大
        :documentHighlightProvider  ; 光标停留就高亮同名符号，每次移动都发请求
        :foldingRangeProvider))     ; 本配置没用折叠
```

`:documentHighlightProvider` 是移动光标时卡顿的常见来源——它按 `eldoc-idle-delay`
的节奏反复向服务端要"当前符号的所有出现位置"。

## 其它

- `read-process-output-max` 设 4MB：减少大响应（如 gopls 的补全列表）的分批 I/O 次数。
- `eglot-sync-connect 0`：异步连接，打开文件不阻塞在"等 LSP 起来"。
- `xref-search-program 'ripgrep`：影响无 LSP 时 `xref-find-references` 的回退搜索。
- eldoc 的 `eldoc-idle-delay 0.5` 就是默认值，显式写出只为提示"调小会明显增加 LSP 请求"。
- gopls 关掉 `staticcheck`（代价高），只留 `unusedparams` / `shadow`。

## 相关

- LSP 服务端的安装方式见 [../lsp-servers.md](../lsp-servers.md)。
- tree-sitter 模式路由在 `init-lsp.el` 顶部（Emacs ≤30 的 `major-mode-remap-alist` 兜底分支
  已随升级到 31 删除）。
- Emacs 31 升级涉及的其它配置改动见 [emacs-install-msys2.md](emacs-install-msys2.md)。

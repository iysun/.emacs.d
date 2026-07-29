;;; -*- lexical-binding: t; -*-

;; tree-sitter 模式路由（Emacs 31 内置 `treesit-enabled-modes'，替代第三方 treesit-auto）。
;;
;; ⚠ **必须用 `setopt'，不能用 `setq'**。`treesit-enabled-modes' 的 defcustom 带 `:set'
;; 处理器，真正干活的是那个 `:set'——它按 `treesit-major-mode-remap-alist' 去填
;; `major-mode-remap-alist'。`setq' 只改变量值、不触发 `:set'，于是一条 remap 都不会生成，
;; 而且**没有任何报错**。实测（31.0.91）：setq → 0 条，setopt → 26 条。
;; 连带后果是下面的 `eglot-ensure' 全部失效（它们只挂在 *-ts-mode-hook 上）。
;;
;; 这里显式列出要启用的 mode，而不是图省事写 t：t 会把 26 个 ts-mode 全部 remap，
;; 包括本机没装 grammar 的，打开对应文件就会被 `treesit-auto-install-grammar'（默认 'ask）
;; 拦下来问要不要现场编译 grammar。列白名单等价于旧版逐语言 `treesit-ready-p' 把关：
;; 缺 grammar 的语言留在原生 mode，安静且可预期。
;; （Windows 上 grammar DLL 常因 ABI 不匹配加载失败，这一点尤其重要。）
;;
;; 下面这份是「仓库 tree-sitter/ 下实际可用的 grammar」∩「31 能 remap 的 ts-mode」，
;; 用 `treesit-language-available-p' 逐个验过。装了新 grammar 后记得往这里加。
;; 当前缺 grammar 而被排除的：c / c-or-c++（缺 c）、typescript、tsx、bash、csharp、cmake。
;; `setopt' 会自动 require treesit，无需手动 require。
(setopt treesit-enabled-modes
        '(go-ts-mode go-mod-ts-mode go-work-ts-mode
          python-ts-mode js-ts-mode json-ts-mode
          c++-ts-mode
          css-ts-mode mhtml-ts-mode php-ts-mode
          java-ts-mode lua-ts-mode ruby-ts-mode rust-ts-mode
          yaml-ts-mode toml-ts-mode dockerfile-ts-mode
          elixir-ts-mode heex-ts-mode))

;; 补充 Emacs 31 尚未内置 grammar 源的语言（TypeScript/Rust/TOML/YAML/Dockerfile 已内置）。
;; 缺 grammar 时执行 M-x treesit-install-language-grammar 即可按此列表拉取。
(setq treesit-language-source-alist
      '((go         "https://github.com/tree-sitter/tree-sitter-go")
        (gomod      "https://github.com/camdencheek/tree-sitter-go-mod")
        (python     "https://github.com/tree-sitter/tree-sitter-python")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
        (c          "https://github.com/tree-sitter/tree-sitter-c")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")))

(setq completion-ignore-case t)                   ; capf 匹配时不区分大小写
(setq read-process-output-max (* 4 1024 1024))    ; 4MB，减少 LSP 大响应的分批 I/O

;; xref 用 ripgrep 而非默认 grep（本机 rg 已装）。影响 xref-find-references
;; 在无 LSP 时的回退搜索，以及 project 相关的查找。
(when (executable-find "rg")
  (setq xref-search-program 'ripgrep))

;; 不再 eager (require 'eglot)（省 ~1.1s 启动）。
;; 下面的 eglot-ensure 钩子会在打开对应代码文件时自动加载 eglot。
(add-hook 'go-ts-mode-hook 'eglot-ensure)
(add-hook 'python-ts-mode-hook 'eglot-ensure)
(add-hook 'js-ts-mode-hook 'eglot-ensure)
(add-hook 'typescript-ts-mode-hook 'eglot-ensure)
(add-hook 'tsx-ts-mode-hook 'eglot-ensure)
(add-hook 'c-ts-mode-hook 'eglot-ensure)
(add-hook 'c++-ts-mode-hook 'eglot-ensure)

;; eglot 专属设置移进 with-eval-after-load，避免 setq 早于 defcustom 定义的不确定性。
(with-eval-after-load 'eglot
  (setq eglot-autoshutdown t)
  ;; 关闭事件日志（省内存 + 省每条消息的日志构造开销）。
  ;; ⚠ 这里**必须**设 `eglot-events-buffer-config'，不能设旧的 `eglot-events-buffer-size'：
  ;; 后者自 eglot 1.16 起废弃，全 eglot 只在 `eglot-events-buffer-config' 的 defcustom
  ;; 默认值表达式里被读一次，即 **eglot 加载那一刻**。写在 with-eval-after-load 里必然太晚，
  ;; 静默无效（本仓库此前就是这样，"关掉事件日志"其实一直没生效）。
  (setq eglot-events-buffer-config '(:size 0 :format short))
  (setq eglot-sync-connect 0)               ; 异步连接，打开文件不阻塞
  (setq eglot-send-changes-idle-time 0.5)   ; 停止输入 0.5s 后才把变更推给 LSP（默认值，显式写出）
  (setq eglot-ignored-server-capabilities   ; 关掉这几项高频、低收益的服务端推送
        '(:inlayHintProvider                ; inlay hints：通知量大
          :documentHighlightProvider        ; 光标停留就高亮同名符号，每次移动都发请求
          :foldingRangeProvider))           ; 折叠区间：本配置没用折叠
  (setq eldoc-idle-delay 0.5)               ; 延迟 eldoc hover 请求（= 默认值，显式写出；调小会明显增加 LSP 请求）

  ;; gopls 专项调优：关闭代价高的静态分析，按需开启
  (setq-default eglot-workspace-configuration
                '(:gopls (:staticcheck       :json-false
                          :analyses          (:unusedparams t :shadow t)
                          :usePlaceholders   t
                          :completeUnimported t)))

  (add-to-list 'eglot-server-programs '((c++-ts-mode c-ts-mode) "clangd"))
  (add-to-list 'eglot-server-programs '((python-ts-mode python-mode) "pyright-langserver" "--stdio"))
  (add-to-list 'eglot-server-programs '((typescript-ts-mode tsx-ts-mode js-ts-mode) "typescript-language-server" "--stdio"))
  (require 'consult-eglot)

  (defun my/lsp-complete ()
    "手动触发含 LSP 的完整补全（C-M-i）。
用 cape-capf-super 合并 eglot + 本地 capf，corfu 弹窗显示所有来源的候选。"
    (interactive)
    (let ((completion-at-point-functions
           (list (cape-capf-super
                  #'eglot-completion-at-point
                  #'cape-dabbrev
                  #'cape-keyword
                  #'cape-file))))
      (call-interactively #'completion-at-point)))

  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (setq-local completion-at-point-functions
                          (remq 'eglot-completion-at-point
                                completion-at-point-functions))
              (local-set-key (kbd "C-M-i") #'my/lsp-complete))))

;; jsonrpc 每条 LSP 消息都会调 `jsonrpc--log-event' 构造日志对象。上面已把事件缓冲区
;; 设为 0（不保留内容），但**构造开销仍在**——直接 fset 成 ignore 才能整条掐掉。
;; 代价：`M-x eglot-events-buffer' 里永远是空的。要抓 LSP 协议时把这行注释掉，
;; 并把 eglot-events-buffer-config 的 :size 调大。
(with-eval-after-load 'jsonrpc
  (fset #'jsonrpc--log-event #'ignore))

;; Workaround: eglot 的 track-changes 回调有时把 marker 对象直接放进 LSP 消息结构，
;; 导致 jsonrpc--json-encode 在序列化时报 "Wrong type argument: consp, #<marker>"。
;; 上游 bug，在修复合并前用此 advice 兜底：递归把 marker 替换为整数位置再编码。
(with-eval-after-load 'jsonrpc
  (defun my/jsonrpc-sanitize-markers (obj)
    (cond
     ((markerp obj) (marker-position obj))
     ((consp obj)
      (cons (my/jsonrpc-sanitize-markers (car obj))
            (my/jsonrpc-sanitize-markers (cdr obj))))
     ((vectorp obj)
      (cl-map 'vector #'my/jsonrpc-sanitize-markers obj))
     (t obj)))
  (advice-add 'jsonrpc--json-encode :filter-args
              (lambda (args) (list (my/jsonrpc-sanitize-markers (car args))))))

(provide 'init-lsp)

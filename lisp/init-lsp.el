;;; -*- lexical-binding: t; -*-

;; tree-sitter 模式路由。
;;
;; Emacs 31 内置 `treesit-enabled-modes'：设 t 即自动把所有有 ts 变体的 major mode
;; 切到 tree-sitter 版本，替代第三方 treesit-auto。
;;
;; Emacs ≤30 没有这个变量，`setq' 它只是凭空造一个没人读的全局量（静默失效）。
;; 该分支下手动填 `major-mode-remap-alist'，逐语言用 `treesit-ready-p' 把关：
;; grammar 装了才 remap，没装就留在原生 mode，不会开出一个报错的空 ts buffer。
;; （Windows 上 grammar DLL 常因 ABI 不匹配加载失败，此时全部跳过，行为同未配置。）
(if (boundp 'treesit-enabled-modes)
    (setq treesit-enabled-modes t)
  (when (and (fboundp 'treesit-available-p) (treesit-available-p))
    (require 'treesit)
    ;; (语言 . (原 mode . ts mode))；只覆盖下面 eglot-ensure 挂钩的那几门语言。
    (dolist (spec '((go         (go-mode        . go-ts-mode))
                    (gomod      (go-dot-mod-mode . go-mod-ts-mode))
                    (python     (python-mode    . python-ts-mode))
                    (javascript (js-mode        . js-ts-mode)
                                (javascript-mode . js-ts-mode)
                                (js2-mode       . js-ts-mode))
                    (typescript (typescript-mode . typescript-ts-mode))
                    (c          (c-mode         . c-ts-mode))
                    (cpp        (c++-mode       . c++-ts-mode))))
      (when (treesit-ready-p (car spec) t)
        (dolist (pair (cdr spec))
          (add-to-list 'major-mode-remap-alist pair))))
    ;; .ts/.tsx 在 Emacs 30 没有非 ts 的内置 major mode 可 remap，直接进 auto-mode-alist。
    (when (treesit-ready-p 'typescript t)
      (add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode)))
    (when (treesit-ready-p 'tsx t)
      (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode)))))

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
  (require 'eldoc-mouse))

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

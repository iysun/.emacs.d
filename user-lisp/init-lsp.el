;;; init-lsp.el --- tree-sitter 模式路由 + eglot 挂载与调优  -*- lexical-binding: t; -*-

;; ⚠ 必须 setopt（setq 不触发 defcustom 的 :set）；只有没有 maybe 路由的语言靠它才走 ts-mode
;; ⚠ 延迟到 startup hook：setopt 会载入 treesit 并生成 remap，占 init 时间
(add-hook 'emacs-startup-hook
          (lambda ()
            (setopt treesit-enabled-modes
                    '(go-ts-mode go-mod-ts-mode go-work-ts-mode
                      python-ts-mode js-ts-mode json-ts-mode
                      c++-ts-mode
                      css-ts-mode mhtml-ts-mode php-ts-mode
                      java-ts-mode lua-ts-mode ruby-ts-mode rust-ts-mode
                      yaml-ts-mode toml-ts-mode dockerfile-ts-mode
                      elixir-ts-mode heex-ts-mode)))
          -90)

;; ⚠ 这里与自带 recipe 同名的（go/gomod/c/cpp）会因 `add-to-list' 头插盖掉自带的 pin
(setq treesit-language-source-alist
      '((go         "https://github.com/tree-sitter/tree-sitter-go")
        (gomod      "https://github.com/camdencheek/tree-sitter-go-mod")
        (python     "https://github.com/tree-sitter/tree-sitter-python")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
        (c          "https://github.com/tree-sitter/tree-sitter-c")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")))

(setq completion-ignore-case t)                   ; capf 匹配时不区分大小写
(setq read-process-output-max (* 4 1024 1024))    ; 4MB，减少 LSP 大响应的分批 I/O

(when (executable-find "rg")
  (setq xref-search-program 'ripgrep))

;; 不 eager require eglot（省 ~1.1s 启动）；下面的钩子打开代码文件时才加载它
;; ⚠ 每个语言 ts-mode 与原生 mode 两条 hook 都挂：落点由 grammar + 白名单决定，可能落到原生 mode 或 fundamental-mode
(defconst my/lsp-modes
  '((c-ts-mode          c-mode)        ; clangd
    (c++-ts-mode        c++-mode)
    (python-ts-mode     python-mode)   ; pyright
    (js-ts-mode         js-mode)       ; typescript-language-server
    (typescript-ts-mode typescript-mode)
    (tsx-ts-mode        nil)           ; 无原生对应 mode
    (go-ts-mode         go-mode)       ; gopls
    (go-mod-ts-mode     go-dot-mod-mode)
    (go-work-ts-mode    go-dot-work-mode)
    (rust-ts-mode       rust-mode)     ; rust-analyzer
    (mhtml-ts-mode      mhtml-mode)    ; rass 聚合 html+css+ts（.html 落 mhtml-ts-mode）
    (css-ts-mode        css-mode))     ; vscode-css-language-server
  "每个元素是 (TS-MODE 原生-MODE …)，nil 表示无对应 mode。")

(dolist (modes my/lsp-modes)
  (dolist (m modes)
    (when m (add-hook (intern (format "%s-hook" m)) 'eglot-ensure))))

(with-eval-after-load 'eglot
  (setq eglot-autoshutdown t)
;; ⚠ 必须设 eglot-events-buffer-config：旧的 eglot-events-buffer-size 只在 eglot 加载那一刻被读一次
  (setq eglot-events-buffer-config '(:size 0 :format short))
  (setq eglot-sync-connect 0)               ; 异步连接，打开文件不阻塞
  (setq eglot-send-changes-idle-time 0.5)   ; 停止输入 0.5s 后才把变更推给 LSP（= 默认值）
  (setq eglot-ignored-server-capabilities   ; 关掉这几项高频、低收益的服务端推送
        '(:inlayHintProvider
          :documentHighlightProvider
          :foldingRangeProvider))
  (setq eldoc-idle-delay 0.5)               ; eldoc hover 延迟（= 默认值；调小会明显增加请求）

  (setq-default eglot-workspace-configuration
                '(:gopls (:staticcheck       :json-false
                          :analyses          (:unusedparams t :shadow t)
                          :usePlaceholders   t
                          :completeUnimported t)))

  (add-to-list 'eglot-server-programs '((c++-ts-mode c++-mode c-ts-mode c-mode) "clangd"))
  (add-to-list 'eglot-server-programs '((python-ts-mode python-mode) "pyright-langserver" "--stdio"))
  (add-to-list 'eglot-server-programs
               '(((js-mode            :language-id "javascript")
                  (js-ts-mode         :language-id "javascript")
                  (tsx-ts-mode        :language-id "typescriptreact")
                  (typescript-ts-mode :language-id "typescript")
                  (typescript-mode    :language-id "typescript"))
                 "typescript-language-server" "--stdio"))
  ;; 一个 buffer 只能连一个 server：rass 聚合 html+css+ts（scripts/rass/html.py），缺 rass 回退纯 html
  (add-to-list 'eglot-server-programs
               `((html-mode html-ts-mode mhtml-mode mhtml-ts-mode)
                 . ,(eglot-alternatives
                     (list (list "rass"
                                 (expand-file-name "scripts/rass/html.py" user-emacs-directory))
                           '("vscode-html-language-server" "--stdio")))))
  (require 'consult-eglot)

  (defun my/lsp-complete ()
    "手动触发补全（C-M-i）。
eglot-managed-mode-hook 已经把 completion-at-point-functions 换成了
`cape-capf-super' 合并出的单个 capf（eglot + 本地 capf 一起给候选），
自动弹出的 corfu 用的也是同一个，这里直接调 `completion-at-point' 即可，
留这个命令只是为了在 corfu-auto 关闭的补全风格下也有手动触发入口。"
    (interactive)
    (call-interactively #'completion-at-point))

  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (setq-local completion-at-point-functions
                          (cons (cape-capf-super
                                 #'eglot-completion-at-point
                                 #'cape-dabbrev
                                 #'cape-keyword
                                 #'cape-file)
                                (remq 'eglot-completion-at-point
                                      completion-at-point-functions)))
              (local-set-key (kbd "C-M-i") #'my/lsp-complete)
;; ⚠ eglot 会头插 eglot-xref-backend 把 citre 挤到后面，xref-find-backend 就不回退 tags/global
              (when (memq 'citre-xref-backend xref-backend-functions)
                (setq-local xref-backend-functions
                            (cons 'citre-xref-backend
                                  (remq 'citre-xref-backend
                                        xref-backend-functions)))))))

;; fset ignore 才真掐掉日志构造开销（代价：M-x eglot-events-buffer 永远空）
(with-eval-after-load 'jsonrpc
  (fset #'jsonrpc--log-event #'ignore))

;; ⚠ 上游 bug：eglot 把 marker 混进 LSP 消息 → jsonrpc--json-encode 序列化报错
;; 序列化时报 "Wrong type argument: consp, #<marker>"；这里递归把 marker 换成整数位置兜底。
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

;; ⚠ 上游 bug：gopls 在 Windows 返回大写盘符的 URI，匹配不上 → 诊断被静默丢进 flymake-list-only-diagnostics
(with-eval-after-load 'eglot
  (define-advice eglot--find-buffer-visiting (:around (orig server abspath) my/case-insensitive-fallback)
    (or (funcall orig server abspath)
        (when (eq system-type 'windows-nt)
          (cl-loop for b in (eglot--managed-buffers server)
                   when (with-current-buffer b
                          (and buffer-file-name
                               (eq t (compare-strings abspath nil nil
                                                       buffer-file-name nil nil t))))
                   return b)))))

(provide 'init-lsp)

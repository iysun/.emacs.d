;;; init-lsp.el --- tree-sitter 模式路由 + eglot 挂载与调优  -*- lexical-binding: t; -*-

(require 'init-lsp-symbols)

;; 客户端和协议一起钉在 submodule 里。路径只相对这份配置。
(load (expand-file-name "vendor/lspmux/emacs/lspmux-async" user-emacs-directory))

(declare-function lspmux-async-complete "lspmux-async")
(declare-function lspmux-async-mode "lspmux-async")
(declare-function eglot-xref-backend "eglot")
(declare-function eglot-hover-eldoc-function "eglot")

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

(setq completion-ignore-case t)
(setq read-process-output-max (* 4 1024 1024))    ; 4MB，减少 LSP 大响应的分批 I/O

(when (executable-find "rg")
  (setq xref-search-program 'ripgrep))

;; 不 eager require eglot（省 ~1.1s 启动）；下面的钩子打开代码文件时才加载它
;; ⚠ 每个语言 ts-mode 与原生 mode 两条 hook 都挂：落点由 grammar + 白名单决定，可能落到原生 mode 或 fundamental-mode
(defconst iys/lsp-modes
  '(    (c-ts-mode          c-mode)        ; lspmux → clangd
    (c++-ts-mode        c++-mode)
    (python-ts-mode     python-mode)   ; lspmux → pyright
    (js-ts-mode         js-mode)       ; lspmux → typescript
    (typescript-ts-mode typescript-mode)
    (tsx-ts-mode        nil)           ; 无原生对应 mode
    (go-ts-mode         go-mode)       ; lspmux → gopls
    (go-mod-ts-mode     go-dot-mod-mode)
    (go-work-ts-mode    go-dot-work-mode)
    (rust-ts-mode       rust-mode)     ; lspmux → rust-analyzer
    (mhtml-ts-mode      mhtml-mode)    ; lspmux 聚合 html+css+ts
    (css-ts-mode        css-mode)      ; lspmux → vscode-css
    (bash-ts-mode       sh-mode))      ; lspmux → shfmt
  "每个元素是 (TS-MODE 原生-MODE …)，nil 表示无对应 mode。")

(defun iys/lspmux--auto-index-p (project)
  "是否让 lspmux 打开文件时自动建 tags：`.project` / `.git` / `project-list-file`。"
  (require 'project)
  (when-let* ((root (and project (ignore-errors (project-root project)))))
    (let ((root (file-name-as-directory (expand-file-name root))))
      (or (file-exists-p (expand-file-name ".project" root))
          (file-exists-p (expand-file-name ".git" root))
          (seq-some
           (lambda (known)
             (file-equal-p (expand-file-name known) root))
           (project-known-project-roots))))))

(defun iys/lspmux-contact (_interactive project)
  (list "lspmux"
        :initializationOptions
        (list :autoIndex (if (iys/lspmux--auto-index-p project) t :json-false))))

(defun iys/lspmux-index ()
  "让 lspmux 为当前文件所在目录建/加载 tags 索引（`lspmux/index`）。"
  (interactive)
  (unless buffer-file-name
    (user-error "没有访问文件"))
  (require 'eglot)
  (let ((server (eglot-current-server)))
    (unless server
      (user-error "当前 buffer 没有 eglot"))
    (jsonrpc-request server :lspmux/index
                     (list :uri (eglot-path-to-uri (expand-file-name buffer-file-name)))
                     :timeout 120)
    (message "lspmux 已索引")))

(dolist (modes iys/lsp-modes)
  (dolist (m modes)
    (when m (add-hook (intern (format "%s-hook" m)) 'eglot-ensure))))

(with-eval-after-load 'eglot
  (setq eglot-autoshutdown t)
;; ⚠ 必须设 eglot-events-buffer-config：旧的 eglot-events-buffer-size 只在 eglot 加载那一刻被读一次
  (setq eglot-events-buffer-config '(:size 0 :format short))
  (setq eglot-sync-connect 0)               ; 异步连接，打开文件不阻塞
  (setq eglot-ignored-server-capabilities   ; 关掉这几项高频、低收益的服务端推送
        '(:inlayHintProvider
          :documentHighlightProvider
          :foldingRangeProvider))

  ;; 没有 jsconfig 的 JS 文件，typescript-language-server 默认 checkJs 为假，
  ;; 未定义名字（如单独一行的 dsaf）不算诊断。打开之后才会报 Cannot find name。
  (setq-default eglot-workspace-configuration
                '(:gopls (:staticcheck       :json-false
                          :analyses          (:unusedparams t :shadow t)
                          :usePlaceholders   t
                          :completeUnimported t)
                  :implicitProjectConfiguration (:checkJs t)))

  ;; 所有托管 mode 只连 PATH 上的 lspmux；源码钉在 vendor/lspmux（submodule）
  ;; ⚠ CONTACT 必须是函数或 (PROGRAM …)，不能再包一层列表，否则
  ;; eglot 会把字符串 "lspmux" 当成 major mode。
  ;; ⚠ mhtml-ts-mode 同时派生自 css-mode / js-mode。eglot 取第一条
  ;; `provided-mode-derived-p' 命中的 languageId，所以 mhtml 必须排在 css/js 前面，
  ;; 否则 HTML 文件会被当成 css，只拉起 vscode-css，标签和 script 都没有补全。
  (add-to-list 'eglot-server-programs
               (cons
                '((mhtml-mode :language-id "html")
                  (mhtml-ts-mode :language-id "html")
                  html-mode html-ts-mode
                  c-mode c-ts-mode
                  (c++-mode :language-id "cpp")
                  (c++-ts-mode :language-id "cpp")
                  python-mode python-ts-mode
                  go-mode go-ts-mode
                  (go-dot-mod-mode :language-id "go.mod")
                  (go-mod-ts-mode :language-id "go.mod")
                  (go-dot-work-mode :language-id "go.work")
                  (go-work-ts-mode :language-id "go.work")
                  rust-mode rust-ts-mode
                  css-mode css-ts-mode
                  (js-mode :language-id "javascript")
                  (js-ts-mode :language-id "javascript")
                  (tsx-ts-mode :language-id "typescriptreact")
                  (typescript-ts-mode :language-id "typescript")
                  (typescript-mode :language-id "typescript")
                  (sh-mode :language-id "shellscript")
                  (bash-ts-mode :language-id "shellscript"))
                #'iys/lspmux-contact))

  (defun iys/lsp-complete ()
    "手动触发补全（C-M-i）。走 lspmux 通知，不调用会阻塞的 `completion-at-point'。"
    (interactive)
    (call-interactively #'lspmux-async-complete))

  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (if (bound-and-true-p eglot--managed-mode)
                  (progn
                    ;; eglot 的 capf / xref 定义会在主线程上等到回应。LSP 候选改由通知回调画。
                    (setq-local completion-at-point-functions
                                (cons (cape-capf-super
                                       #'cape-dabbrev
                                       #'cape-keyword
                                       #'cape-file)
                                      (remq 'eglot-completion-at-point
                                            completion-at-point-functions)))
                    (remove-hook 'xref-backend-functions #'eglot-xref-backend t)
                    (remove-hook 'eldoc-documentation-functions #'eglot-hover-eldoc-function t))))))

;; fset ignore 才真掐掉日志构造开销（代价：M-x eglot-events-buffer 永远空）
(with-eval-after-load 'jsonrpc
  (fset #'jsonrpc--log-event #'ignore))

;; ⚠ 上游 bug：eglot 把 marker 混进 LSP 消息 → jsonrpc--json-encode 序列化报错
;; 序列化时报 "Wrong type argument: consp, #<marker>"；这里递归把 marker 换成整数位置兜底。
(with-eval-after-load 'jsonrpc
  (defun iys--jsonrpc-sanitize-markers (obj)
    (cond
     ((markerp obj) (marker-position obj))
     ((consp obj)
      (cons (iys--jsonrpc-sanitize-markers (car obj))
            (iys--jsonrpc-sanitize-markers (cdr obj))))
     ((vectorp obj)
      (cl-map 'vector #'iys--jsonrpc-sanitize-markers obj))
     (t obj)))
  (advice-add 'jsonrpc--json-encode :filter-args
              (lambda (args) (list (iys--jsonrpc-sanitize-markers (car args))))))

;; ⚠ 上游 bug：gopls 在 Windows 返回大写盘符的 URI，匹配不上 → 诊断被静默丢进 flymake-list-only-diagnostics
(with-eval-after-load 'eglot
  (define-advice eglot--find-buffer-visiting (:around (orig server abspath) iys/case-insensitive-fallback)
    (or (funcall orig server abspath)
        (when (eq system-type 'windows-nt)
          (cl-loop for b in (eglot--managed-buffers server)
                   when (with-current-buffer b
                          (and buffer-file-name
                               (eq t (compare-strings abspath nil nil
                                                       buffer-file-name nil nil t))))
                   return b)))))

(provide 'init-lsp)

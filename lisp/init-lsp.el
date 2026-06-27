;;; -*- lexical-binding: t; -*-

;; Emacs 31 内置：自动把有 ts 变体的 major mode 全部切换到 tree-sitter 版本。
;; 替代第三方 treesit-auto 包的 global-treesit-auto-mode + add-to-auto-mode-alist。
(setq treesit-enabled-modes t)

;; 补充 Emacs 31 尚未内置 grammar 源的语言（TypeScript/Rust/TOML/YAML/Dockerfile 已内置）。
;; 缺 grammar 时执行 M-x treesit-install-language-grammar 即可按此列表拉取。
(setq treesit-language-source-alist
      '((go         "https://github.com/tree-sitter/tree-sitter-go")
        (gomod      "https://github.com/camdencheek/tree-sitter-go-mod")
        (python     "https://github.com/tree-sitter/tree-sitter-python")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
        (c          "https://github.com/tree-sitter/tree-sitter-c")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")))

(setq completion-ignore-case t)              ; capf 匹配时不区分大小写
(setq read-process-output-max (* 1024 1024)) ; 1MB

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
  ;; eglot-send-changes-idle-time 0.1
  (setq eglot-events-buffer-size 0)
  (add-to-list 'eglot-server-programs '((c++-ts-mode c-ts-mode) "clangd"))
  (add-to-list 'eglot-server-programs '((python-ts-mode python-mode) "pyright-langserver" "--stdio"))
  (add-to-list 'eglot-server-programs '((typescript-ts-mode tsx-ts-mode js-ts-mode) "typescript-language-server" "--stdio"))
  (require 'consult-eglot)
  (require 'eldoc-mouse))

(provide 'init-lsp)

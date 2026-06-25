;; 加载 treesit-auto
(require 'treesit-auto)
(with-eval-after-load 'treesit-auto
  (treesit-auto-add-to-auto-mode-alist 'all)
  (setq treesit-auto-install 'prompt)
  (global-treesit-auto-mode)
  ;; Emacs 30.x 内置 libtree-sitter.dll 只支持 ABI 14，
  ;; 以下 grammar 的 master 分支已升到 ABI 15，固定到最后一个 ABI 14 兼容 tag。
  (dolist (entry '((javascript . "v0.21.4")
                   (typescript . "v0.21.2")
                   (tsx        . "v0.21.2")))
    (when-let ((recipe (cl-find (car entry) treesit-auto-recipe-list
                                :key #'treesit-auto-recipe-lang)))
      (setf (treesit-auto-recipe-abi14-revision recipe) (cdr entry)))))

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

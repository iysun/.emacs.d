;; -*- lexical-binding: t; -*-

(with-eval-after-load 'apheleia
  ;; ⚠ emacs-lisp 映射靠外部 diff/gdiff 打 patch，GUI 下 PATH 常找不到 diff 而报错
  (setf (alist-get 'emacs-lisp-mode apheleia-mode-alist nil 'remove) nil)
  (when (executable-find "shfmt")
    (setf (alist-get 'sh-mode apheleia-mode-alist) 'shfmt)))

(defun my/format-buffer ()
  "格式化统一入口：eglot 托管的 buffer 用 eglot-format，否则用 apheleia-format-buffer。"
  (interactive)
  (if (and (fboundp 'eglot-managed-p) (eglot-managed-p))
      (call-interactively #'eglot-format)
    (call-interactively #'apheleia-format-buffer)))

(provide 'init-format)

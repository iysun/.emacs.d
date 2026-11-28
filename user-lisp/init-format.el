;; -*- lexical-binding: t; -*-

(defun iys/format-buffer ()
  "格式化当前 buffer（`eglot-format` → lspmux）。"
  (interactive)
  (unless (and (fboundp 'eglot-managed-p) (eglot-managed-p))
    (user-error "当前 buffer 没有 eglot"))
  (call-interactively #'eglot-format))

(provide 'init-format)

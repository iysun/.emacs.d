;; init-term.el 	-*- lexical-binding: t -*-

(defvar eshell-buffer-maximum-lines)
(defun eshell-clear ()
  (interactive)
  (let ((eshell-buffer-maximum-lines 0))
    (eshell-truncate-buffer)
    (previous-line)
    (delete-char 1)))

;; 别名须入库：etc/ 不受 gitignore，no-littering 的 var/eshell/ 会被收编。
(setq eshell-aliases-file
      (expand-file-name "etc/eshell/alias" user-emacs-directory))

(setq eshell-banner-message "")
(setq eshell-visual-commands '("bat" "less" "more" "htop" "man" "vim" "fish"))
(setq eshell-destroy-buffer-when-process-dies t)
(setq eshell-cmpl-autolist t)
(setq eshell-where-to-jump 'begin)
(setq eshell-review-quick-commands nil)
(setq eshell-smart-space-goes-to-end t)
(setq eshell-history-size 10000)


(autoload 'eshell-delchar-or-maybe-eof "em-rebind")

(require 'init-eshell-prompt)

(add-hook 'eshell-mode-hook 'eshell-syntax-highlighting-global-mode)

;; ⚠ 语法高亮每次按键都重新 executable-find，命令未敲完必然 miss → 卡顿；只在 eshell buffer 缓存。
(defvar my/eshell--executable-cache (make-hash-table :test #'equal)
  "eshell 里 `executable-find' 的结果缓存：(命令 . remote) → 路径或 nil。")

(defun my/eshell-clear-executable-cache ()
  "清空 eshell 的 `executable-find' 缓存。装了新命令行工具后没被高亮成命令时用。"
  (interactive)
  (clrhash my/eshell--executable-cache)
  (message "eshell executable 缓存已清空"))

(defun my/eshell--executable-find-cached (orig command &optional remote)
  "只在 eshell buffer 里给 `executable-find' 加缓存（见上面的说明）。"
  (if (derived-mode-p 'eshell-mode)
      (let* ((key (cons command remote))
             (hit (gethash key my/eshell--executable-cache 'my/miss)))
        (if (eq hit 'my/miss)
            (puthash key (funcall orig command remote) my/eshell--executable-cache)
          hit))
    (funcall orig command remote)))

(advice-add 'executable-find :around #'my/eshell--executable-find-cached)
(add-hook 'eshell-mode-hook
          (lambda ()
            (setq eshell-prefer-lisp-functions t)
            (setq password-cache t)
            (setq password-cache-expiry 900)
            (setq-local truncate-lines -1)
            ))

(provide 'init-term)

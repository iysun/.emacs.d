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
(setq eshell-visual-commands '("less" "more" "htop" "man" "vim" "fish"))
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

;; ⚠ 原生模块默认在包目录，MELPA 升级整目录替换会删掉 → 放 var/
(setq ghostel-module-directory (expand-file-name "var/ghostel/" user-emacs-directory))
(when (eq system-type 'windows-nt)
  (setq ghostel-shell "pwsh"))

;; ⚠ global-display-line-numbers-mode 在 mode hook 之后才生效，只能用 after-change-major-mode-hook 关
(defun my/ghostel-no-line-numbers ()
  (when (derived-mode-p 'ghostel-mode)
    (display-line-numbers-mode -1)))
(add-hook 'after-change-major-mode-hook #'my/ghostel-no-line-numbers t)

(add-hook 'eshell-load-hook #'ghostel-eshell-visual-command-mode)
(defalias 'eshell/v #'eshell/ghostel)
;; ⚠ 用 Hook 不用 ghostel-comint-global-mode：后者 init 期就 eager 加载 ghostel + 原生模块
(add-hook 'comint-mode-hook #'ghostel-comint-mode)

;; ⚠ 走 shell 且 -NoExit：命令跑完要留在同一个终端里；Windows 上 npm/lazygit 是 .cmd，argv 起不来
(defun my/ghostel-run--command (command)
  "Return (PROGRAM . ARGS) that runs COMMAND and then keeps a shell in the buffer."
  (if (eq system-type 'windows-nt)
      (cons "pwsh" (list "-NoLogo" "-NoExit" "-Command" command))
    (let ((shell (or (getenv "SHELL") "/bin/sh")))
      (cons shell (list "-c" (format "%s; exec %s -i" command shell))))))

(defun my/ghostel-run (command)
  "Run COMMAND in a fresh ghostel buffer at `default-directory'.
The shell stays alive afterwards, so the buffer is usable as a terminal."
  (interactive (list (read-shell-command "Ghostel: ")))
  (when (string-blank-p command)
    (user-error "Empty command"))
  (require 'ghostel)
  (let* ((dir default-directory)
         (spec (my/ghostel-run--command command))
         (buffer (generate-new-buffer (format "*ghostel: %s*" (string-trim command)))))
    (switch-to-buffer buffer)
    (setq default-directory dir)
    (condition-case err
        (ghostel-exec buffer (car spec) (cdr spec))
      (error (kill-buffer buffer)
             (signal (car err) (cdr err))))))

;; ⚠ 用 emacs 态：evil 的 insert/normal 键位会抢 C-a/C-e/C-k/C-p/C-n 和 ESC，
;;   emacs 态下这些键与 copy/line 模式各自的键位才能到 ghostel
(setq ghostel-keymap-exceptions '("C-c" "C-x" "C-h" "M-x" "M-:" "C-\\"))
(with-eval-after-load 'evil
  (evil-set-initial-state 'ghostel-mode 'emacs))

(provide 'init-term)

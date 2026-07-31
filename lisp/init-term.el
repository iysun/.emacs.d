;; init-term.el 	-*- lexical-binding: t -*-
;; eshell 配置

;; eshell 键绑定
;;(define-key eshell-mode-map (kbd "C-l") 'eshell-clear)
;;(define-key eshell-mode-map (kbd "<M-tab>") 'tab-bar-switch-to-next-tab)
;; eshell 模式键绑定
;;(define-key eshell-mode-map (kbd "C-d") 'eshell-delchar-or-maybe-eof)
;;(define-key eshell-mode-map (kbd "C-r") 'consult-history)

;; eshell 自定义函数
(defun eshell-clear ()
  (interactive)
  (let ((eshell-buffer-maximum-lines 0))
    (eshell-truncate-buffer)
    (previous-line)
    (delete-char 1)))

;; eshell 别名文件。no-littering 把 `eshell-directory-name' 指到了 var/eshell/（运行期数据），
;; 但**别名是配置、要入库**，所以单独指到 etc/eshell/alias（etc/ 不在 gitignore 里）。
;; 历史 / lastdir 仍留在 var/eshell/。
(setq eshell-aliases-file
      (expand-file-name "etc/eshell/alias" user-emacs-directory))

;; eshell 自定义变量
(setq eshell-banner-message "")
(setq eshell-visual-commands '("bat" "less" "more" "htop" "man" "vim" "fish"))
(setq eshell-destroy-buffer-when-process-dies t)
(setq eshell-cmpl-autolist t)
(setq eshell-where-to-jump 'begin)
(setq eshell-review-quick-commands nil)
(setq eshell-smart-space-goes-to-end t)
(setq eshell-history-size 10000)


(autoload 'eshell-delchar-or-maybe-eof "em-rebind")

;; ================= 提示符 =================
;; 实现本体见 `extensions/eshell-prompt/eshell-prompt.el'（同 `init-bars.el' 用
;; `load' 接 `extensions/mode-line'、`extensions/tab-line' 的方式）。
(let ((dir (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))))
  (load (expand-file-name "extensions/eshell-prompt/eshell-prompt" dir)))

;; ================= 语法高亮 =================
(add-hook 'eshell-mode-hook 'eshell-syntax-highlighting-global-mode)

;; eshell-syntax-highlighting 挂在 `post-command-hook' 上，每次按键重解析整行输入，
;; 命令名 token 要走一次 `executable-find'：本机实测命中 7.4ms、**未命中 20.9ms**
;; （`exec-path' 44 项 × Windows 还要逐个试 .exe/.bat/.cmd 后缀），而命令名没敲完时
;; 走的全是未命中那条路——敲一个命令名就凭空多出上百毫秒。这里只在 eshell buffer 里
;; 给它套一层缓存（命中与否都缓存），别处的 `executable-find' 行为不变。
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
;; 内置 completion-preview-mode（Emacs 30+，替代 capf-autosuggest）在 eshell/comint 里
;; 是否启用由 init-completion.el 的补全风格切换（my/completion--set-preview-hooks）统一管理。
;; eshell 模式钩子
(add-hook 'eshell-mode-hook
          (lambda ()
            (setq eshell-prefer-lisp-functions t)
            (setq password-cache t)
            (setq password-cache-expiry 900)
            ;; (setenv "TERM" "xterm-256color")
            (setq-local truncate-lines -1)
            ))

(provide 'init-term)

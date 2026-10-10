;; evil-keymaps.el 	-*- lexical-binding: t -*-
;;
;; evil 专属键位（normal/insert/visual 全局键、eshell、dired、minuet）。
;;
;; `evil-define-key' 是宏，编译期必须先加载 evil，否则被当函数编译成坏 .elc
;; （加载时报 "Invalid function: evil-define-key"）。用 `eval-when-compile' 只为编译期
;; 取宏；运行时 evil 已延迟到 after-init 加载，故所有绑定包在
;; `with-eval-after-load 'evil' 里，会在 evil 加载时生效（本文件在 init 期 require，
;; 只是注册回调）。
;;
;; 非 evil 的全局键（consult/embark/mc/popper/tab-line…）见 user-lisp/init-keymaps.el。

(eval-when-compile (require 'evil))
(defvar eshell-mode-map)
(defvar dired-mode-map)
(defvar minuet-active-mode-map)

(with-eval-after-load 'evil
  ;; normal 态全局：格式化 / citre 原地预览 / 看文档
  (evil-define-key 'normal 'global (kbd "SPC f") 'my/format-buffer)
  ;; citre 唯一保留的专属命令：原地预览定义，不跳转、不用 xref（xref 前端做不到）。
  (evil-define-key 'normal 'global (kbd "SPC p") 'citre-peek)
  ;; 看文档，不跳转、不动光标（实现见 init-base.el）。
  (evil-define-key 'normal 'global (kbd "gh") 'my/doc-at-point)

  ;; eshell-mode-map 每次进入 eshell-mode 都会被重建，eshell 的 first-time 钩子会重设键位。
  ;; 为确保 insert 态 RET = 执行命令（而非只换行），这些绑定放在 eshell-mode-hook（晚于
  ;; first-time 钩子）里、且 depth 靠后，才能稳定覆盖。
  (defun my/eshell-evil-insert-keys ()
    (evil-define-key 'insert eshell-mode-map (kbd "RET") 'eshell-send-input)        ; 回车=执行命令
    (evil-define-key 'insert eshell-mode-map (kbd "<return>") 'eshell-send-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-p") 'eshell-previous-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-n") 'eshell-next-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-r") 'consult-history)
    (evil-normalize-keymaps))
  (add-hook 'eshell-mode-hook #'my/eshell-evil-insert-keys 90)

  ;; dired：C-a 新建文件、C-d 新建目录
  (dolist (state '(normal insert visual))
    (evil-define-key state dired-mode-map (kbd "C-a") 'dired-create-empty-file)
    (evil-define-key state dired-mode-map (kbd "C-d") 'dired-create-directory))

  ;; C-w w 打开自写的窗口缩放 hydra（`hydra-window-size'，定义见 init-window.el）。
  ;; 注意：覆盖了 evil 默认的 `C-w w'（`evil-window-next'，循环切窗）。
  (define-key evil-window-map (kbd "w") #'hydra-window-size/body)

  ;; minuet（停用模块，用到才加载）
  (with-eval-after-load 'minuet
    (evil-define-key 'insert minuet-active-mode-map (kbd "<tab>") 'minuet-accept-suggestion)
    (evil-define-key 'insert minuet-active-mode-map (kbd "M-p") 'minuet-previous-suggestion)
    (evil-define-key 'insert minuet-active-mode-map (kbd "M-n") 'minuet-next-suggestion))

  ;; visual 态：Y 复制到系统剪贴板
  (evil-define-key 'visual 'global (kbd "Y") 'clipboard-kill-ring-save)

  ;; insert 态全局
  (evil-define-key 'insert 'global (kbd "C-v") 'clipboard-yank)
  (evil-define-key 'insert 'global (kbd "C-a") 'beginning-of-line)
  (evil-define-key 'insert 'global (kbd "C-e") 'end-of-line)
  (evil-define-key 'insert 'global (kbd "C-k") 'kill-line)
  (evil-define-key 'insert 'global (kbd "C-d") 'delete-char)
  (evil-define-key 'insert 'global (kbd "M-u") 'custom/upcase-back)
  (evil-define-key 'insert 'global (kbd "M-l") 'custom/downcase-back)
  (evil-define-key 'insert 'global (kbd "M-c") 'custom/capitalize-back))

(provide 'evil-keymaps)

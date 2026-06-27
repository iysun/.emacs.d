;; init-term.el 	-*- lexical-binding: t -*-
;; Better terminal emulator
(with-eval-after-load 'eat
  ;; eat 配置
  (eat-eshell-mode 1)
  (setq eat-semi-char-non-bound-keys '([C--] [M--]))
  (setq eat-term-terminfo-type "xterm-256color")
  (setq eat-term-scrollback-lines 10000)
  ;; 输入处理
  (setq eat-enable-input-processing nil)
  (setq eat-enable-auto-line-mode t)
  ;; eat 钩子设置
  (add-hook 'eshell-load-hook 'eat-eshell-mode)
  ;; (add-hook 'eshell-load-hook 'eat-eshell-visual-command-mode)
  )

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

;; eshell 配置
(add-hook 'completion-at-point-functions 'pcomplete-completations-at-point nil t)

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

;; eshell-git-prompt 配置
(add-hook 'after-init-hook (lambda () (eshell-git-prompt-use-theme 'multiline2)))
;; eshell-syntax-highlighting-global-mode
(add-hook 'eshell-mode-hook 'eshell-syntax-highlighting-global-mode)
;; 内置 completion-preview-mode（Emacs 30+），替代 capf-autosuggest
(add-hook 'eshell-mode-hook 'completion-preview-mode)
(add-hook 'comint-mode-hook 'completion-preview-mode)
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

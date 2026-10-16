;; evil-keymaps.el 	-*- lexical-binding: t -*-

;; evil-define-key 是宏，必须在编译期先加载 evil，否则被当函数编成坏 .elc（Invalid function）。
(eval-when-compile (require 'evil))
(defvar eshell-mode-map)
(defvar dired-mode-map)
(defvar minuet-active-mode-map)

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "SPC f") 'my/format-buffer)
  (evil-define-key 'normal 'global (kbd "SPC p") 'citre-peek)
  (evil-define-key 'normal 'global (kbd "gh") 'my/doc-at-point)

  ;; ⚠ eshell-mode-map 每次进 mode 都重建，hook 须排在 first-time 钩子之后（depth 90）。
  (defun my/eshell-evil-insert-keys ()
    (evil-define-key 'insert eshell-mode-map (kbd "RET") 'eshell-send-input)
    (evil-define-key 'insert eshell-mode-map (kbd "<return>") 'eshell-send-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-p") 'eshell-previous-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-n") 'eshell-next-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-r") 'consult-history)
    (evil-normalize-keymaps))
  (add-hook 'eshell-mode-hook #'my/eshell-evil-insert-keys 90)

  ;; 覆盖 evil 默认的 C-w w 循环切窗，改用自写窗口缩放 hydra（定义见 init-window.el）。
  (define-key evil-window-map (kbd "w") #'hydra-window-size/body)

  (evil-define-key 'visual 'global (kbd "Y") 'clipboard-kill-ring-save)

  (evil-define-key 'insert 'global (kbd "C-v") 'clipboard-yank)
  (evil-define-key 'insert 'global (kbd "C-a") 'beginning-of-line)
  (evil-define-key 'insert 'global (kbd "C-e") 'end-of-line)
  (evil-define-key 'insert 'global (kbd "C-k") 'kill-line)
  (evil-define-key 'insert 'global (kbd "C-d") 'delete-char)
  (evil-define-key 'insert 'global (kbd "M-u") 'custom/upcase-back)
  (evil-define-key 'insert 'global (kbd "M-l") 'custom/downcase-back)
  (evil-define-key 'insert 'global (kbd "M-c") 'custom/capitalize-back))

(provide 'evil-keymaps)

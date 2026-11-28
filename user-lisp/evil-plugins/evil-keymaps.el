;; evil-keymaps.el 	-*- lexical-binding: t -*-

;; evil-define-key 是宏，必须在编译期先加载 evil，否则被当函数编成坏 .elc（Invalid function）。
(eval-when-compile (require 'evil))
(defvar eshell-mode-map)

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "SPC f") 'iys/format-buffer)
  (evil-define-key 'normal 'global (kbd "SPC c") 'iys/lspmux-index)
  (evil-define-key 'normal 'global (kbd "gh") 'iys/doc-at-point)
  (evil-define-key 'normal 'global (kbd "gH") 'iys-notify-pop-out)
  ;; evil-commentary-mode 自己的 map 也绑了 gy，后加载会盖掉 global，须再绑一次
  (evil-define-key 'normal 'global (kbd "gy") 'iys-notify-copy-dwim)
  (with-eval-after-load 'evil-commentary
    (evil-define-key 'normal evil-commentary-mode-map
      (kbd "gy") 'iys-notify-copy-dwim))

  ;; ⚠ eshell-mode-map 每次进 mode 都重建，hook 须排在 first-time 钩子之后（depth 90）。
  (defun iys/eshell--evil-insert-keys ()
    (evil-define-key 'insert eshell-mode-map (kbd "<return>") 'eshell-send-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-p") 'eshell-previous-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-n") 'eshell-next-matching-input-from-input)
    (evil-define-key 'insert eshell-mode-map (kbd "C-r") 'consult-history)
    (evil-normalize-keymaps))
  (add-hook 'eshell-mode-hook #'iys/eshell--evil-insert-keys 90)

  ;; 覆盖 evil 默认的 C-w w 循环切窗，改用自写窗口缩放 hydra（定义见 init-window.el）。
  (define-key evil-window-map (kbd "w") #'hydra-window-size/body)

  ;; ⚠ clipboard-kill-ring-save 不带 yank-handler，按行选区按 Y 会退化成字符级粘贴
  (evil-define-operator iys/evil-visual-yank-clipboard (beg end type)
    "可视态 Y：复制到系统剪贴板，保留行/块类型。"
    :move-point nil
    :repeat nil
    (let ((select-enable-clipboard t))
      (evil-yank beg end type)))
  (evil-define-key 'visual 'global (kbd "Y") #'iys/evil-visual-yank-clipboard)

  (evil-define-key 'insert 'global (kbd "C-v") 'clipboard-yank)
  (evil-define-key 'insert 'global (kbd "C-a") 'beginning-of-line)
  (evil-define-key 'insert 'global (kbd "C-e") 'end-of-line)
  (evil-define-key 'insert 'global (kbd "C-k") 'kill-line)
  (evil-define-key 'insert 'global (kbd "C-d") 'delete-char)
  (evil-define-key 'insert 'global (kbd "M-u") 'iys/upcase-back)
  (evil-define-key 'insert 'global (kbd "M-l") 'iys/downcase-back)
  (evil-define-key 'insert 'global (kbd "M-c") 'iys/capitalize-back))

(provide 'evil-keymaps)

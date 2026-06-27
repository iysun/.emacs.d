;;; -*- lexical-binding: t; -*-
;; (defun my-diff-hl-fringe-bmp-function (_type _pos)
;; "Fringe bitmap function for use as `diff-hl-fringe-bmp-function'."
;;     (define-fringe-bitmap 'my-diff-hl-bmp
;; 	(vector ((if (eq system-type 'gnu/linux) #b11111100 #b11100000)))
;; 	1 8
;; 	'(center t)))
;; (require 'magit)

;; Magit 配置
(with-eval-after-load 'magit
  (unbind-key "M-1" magit-mode-map)
  (unbind-key "M-2" magit-mode-map)
  (unbind-key "M-3" magit-mode-map)
  (unbind-key "M-4" magit-mode-map)
  )

;; (require 'diff-hl)

;; Highlight uncommitted changes using VC
;; ;; :bind (:map diff-hl-command-map
;; ;;        ("SPC" . diff-hl-mark-hunk))

(with-eval-after-load 'diff-hl
  ;; 自定义设置
  (setq diff-hl-draw-borders nil)
  (setq diff-hl-update-async t)
  (setq diff-hl-global-modes '(not image-mode pdf-view-mode))
  
  ;; 区分 staged 和 unstaged
  (setq diff-hl-show-staged-changes nil)
  (setq diff-hl-reference-revision nil)
  ;; Set fringe style
  (setq-default fringes-outside-margins t)
  
  ;; (setq diff-hl-fringe-bmp-function 'my-diff-hl-fringe-bmp-function)
  
  ;; Highlight on-the-fly
  (diff-hl-flydiff-mode 1)
  
  ;; Fall back to the display margin since the fringe is unavailable in tty
  (unless (display-graphic-p) (diff-hl-margin-mode 1))
  )
;; 钩子设置
;; diff-hl 加载 + 全局开启实测 ~0.4s，且只在文件缓冲区有意义。从 after-init 挪到
;; 首次打开文件时一次性启用（届时正好要看 git 改动标记），不再占启动时间。
(defun my/enable-diff-hl-once ()
  (global-diff-hl-mode 1)
  (global-diff-hl-show-hunk-mouse-mode 1)
  (remove-hook 'find-file-hook 'my/enable-diff-hl-once))
(add-hook 'find-file-hook 'my/enable-diff-hl-once)
(add-hook 'dired-mode-hook 'diff-hl-dired-mode)
(add-hook 'magit-pre-refresh-hook 'diff-hl-magit-pre-refresh)  ; Magit 刷新前更新 diff-hl
(add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)

(provide 'init-git)

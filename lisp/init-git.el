;;; -*- lexical-binding: t; -*-
;; (defun my-diff-hl-fringe-bmp-function (_type _pos)
;; "Fringe bitmap function for use as `diff-hl-fringe-bmp-function'."
;;     (define-fringe-bitmap 'my-diff-hl-bmp
;; 	(vector ((if (eq system-type 'gnu/linux) #b11111100 #b11100000)))
;; 	1 8
;; 	'(center t)))
;; (require 'magit)

;; Windows 上给 git 子进程定的环境变量已挪到 lisp/init-windows.el（early-init.el
;; 阶段就设好，比这里更早，覆盖面也更全——不止 magit 会起 git 子进程）。

;; Magit 配置
(with-eval-after-load 'magit
  (unbind-key "M-1" magit-mode-map)
  (unbind-key "M-2" magit-mode-map)
  (unbind-key "M-3" magit-mode-map)
  (unbind-key "M-4" magit-mode-map)

  ;; magit-status 提速：默认会在 status 里渲染完整 diff + 一大段 log，
  ;; 大仓库下这是主要耗时来源。
  (setq magit-commit-show-diff nil            ; 写 commit message 时不同时铺开 diff
        magit-log-section-commit-count 5      ; status 里近期提交只列 5 条（默认 10）
        magit-refresh-verbose nil))

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

;; 打开文件时若检测到冲突标记就自动开 smerge-mode（省去手动 M-x）。
;; 只扫文件开头到第一个匹配，代价可忽略。
(defun my/auto-smerge-mode ()
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^<<<<<<< " nil t)
      (smerge-mode 1))))
(add-hook 'find-file-hook #'my/auto-smerge-mode)
(add-hook 'dired-mode-hook 'diff-hl-dired-mode)
(add-hook 'magit-pre-refresh-hook 'diff-hl-magit-pre-refresh)  ; Magit 刷新前更新 diff-hl
(add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)

(provide 'init-git)

;; init-base.el 	-*- lexical-binding: t -*-

;; setup

;; 启动不自动最大化（如需恢复，取消下面这行注释）
;; (add-hook 'after-init-hook 'toggle-frame-maximized)
(progn
  (global-auto-revert-mode t)
  (setq make-backup-files nil)                 
  (setq use-short-answers t)
  (setq select-enable-clipboard nil)
  
  ;;; And I have tried
  (setq-default indent-tabs-mode nil)

  ;; 自定义项目标识
  (setq project-vc-extra-root-markers '(".project"))
  
  (global-hl-line-mode t)
  )


;; eldoc 延迟：避免光标移动时频繁触发 LSP hover 请求
(setq eldoc-idle-delay 0.5)

;; 记录 M-x 历史
(add-hook 'after-init-hook 'savehist-mode)
(progn
  (setq enable-recursive-minibuffers t)
  (setq history-length 1000)
  (setq savehist-additional-variables '(mark-ring
                                        global-mark-ring
                                        search-ring
                                        regexp-search-ring
                                        extended-command-history))
  (setq savehist-autosave-interval 300)
  )

;; 文件历史
(add-hook 'after-init-hook 'recentf-mode)
(progn
  (setq recentf-max-saved-items 300)
  (setq recentf-auto-cleanup 'never)
  (setq recentf-filename-handlers '(abbreviate-file-name))
  )

(provide 'init-base)

;; (defun word-syntax- ()
;;   (interactive)
;;   (modify-syntax-entry ?- "w"))

;; (defun word-syntax_ ()
;;   (interactive)
;;   (modify-syntax-entry ?_ "w"))

;; (modify-syntax-entry ?- "w")

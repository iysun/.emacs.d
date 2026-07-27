;; init-base.el 	-*- lexical-binding: t -*-

;; `cl-remove-if-not' / `cl-loop' 来自 cl-lib；顶层 require 保证编译期宏可用。
(require 'cl-lib)

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


;; eldoc 延迟见 `init-lsp.el'（那里才是它的动机：减少 LSP hover 请求）。

;; 记录 M-x 历史
(add-hook 'after-init-hook 'savehist-mode)
(progn
  (setq enable-recursive-minibuffers t)
  (setq history-length 1000)
  (setq savehist-additional-variables '(kill-ring
                                        register-alist
                                        mark-ring
                                        global-mark-ring
                                        search-ring
                                        regexp-search-ring
                                        extended-command-history))
  (setq savehist-autosave-interval 300)
  )

;; 存盘前把文本属性剥掉。kill-ring / register 里的字符串常带一整套 face、
;; 甚至 overlay 引用，直接序列化会让 savehist 文件膨胀好几倍，个别不可打印
;; 的对象还会让整次保存失败（于是历史悄悄丢了）。
(defun my/savehist-unpropertize ()
  (setq kill-ring
        (mapcar #'substring-no-properties
                (cl-remove-if-not #'stringp kill-ring))
        register-alist
        (cl-loop for (reg . item) in register-alist
                 if (stringp item)
                 collect (cons reg (substring-no-properties item))
                 else collect (cons reg item))))

(defun my/savehist-drop-unprintable-registers ()
  (setq register-alist (cl-remove-if-not #'savehist-printable register-alist)))

(with-eval-after-load 'savehist
  (add-hook 'savehist-save-hook #'my/savehist-unpropertize)
  (add-hook 'savehist-save-hook #'my/savehist-drop-unprintable-registers))

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

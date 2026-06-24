;; init-window.el 	-*- lexical-binding: t -*-
(add-hook 'after-init-hook 'winner-mode)

;; defhydra 来自 hydra 包；显式 require，确保宏在此处可用（否则 fresh 机器
;; 上 hydra 未被自动加载时会报 void-function defhydra）。
(require 'hydra)

(defhydra hydra-window-size (:color red)
  "调整窗口大小"
  ("h" shrink-window-horizontally "向左缩窄")
  ("j" enlarge-window "向下拉高")
  ("k" shrink-window "向上缩短")
  ("l" enlarge-window-horizontally "向右加宽")
  ("q" nil "退出"))

;; 原生 tab-line（按项目分组 + 过滤 eglot buffer）——替代 centaur-tabs，零第三方、零启动开销。
(defun my/tab-line-buffer-group-by-project (&optional buffer)
  "Group buffers by project root via project.el."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((dir (or (buffer-file-name) nil))
           (proj (project-current nil dir))
           (root (when proj (project-root proj))))
      (if (and root dir)
          (file-name-nondirectory (directory-file-name root))
        "Other"))))

(defun my/tab-line-filter (buffers)
  "Filter out Eglot-generated buffers from tab-line."
  (let (result)
    (dolist (buf buffers (nreverse result))
      (let ((name (buffer-name buf)))
        (unless (and name
                     (let ((case-fold-search t))
                       (string-match-p "\\`\\s-*\\*eglot" name)))
          (push buf result))))))

(progn
  (setq tab-line-tabs-function 'tab-line-tabs-buffer-groups)
  (setq tab-line-tabs-buffer-group-function #'my/tab-line-buffer-group-by-project)
  (advice-add 'tab-line-tabs-buffer-list :filter-return #'my/tab-line-filter))

(add-hook 'after-init-hook 'global-tab-line-mode)

;; (require 'popper)
(with-eval-after-load 'popper
  (setq popper-window-height 20)
  (setq popper-reference-buffers
        '("\\*Messages\\*"
          "Output\\*$"
          "\\*Async Shell Command\\*"
          "^\\*Copilot"
          "^\\*.*eshell.*\\*$" eshell-mode ;eshell as a popup
          "^\\*.*shell.*\\*$"  shell-mode  ;shell as a popup
          "^\\*.*term.*\\*$"   term-mode   ;term as a popup
          "^\\*.*eat.*\\*$"   eat-mode   ;term as a popup
          "^\\*.*vterm.*\\*$"  vterm-mode  ;vterm as a popup
          "^\\*Buffer List.*\\*$"
          "\\*Ibuffer.*\\*" ibuffer-mode ;ibuffer-mode
          help-mode
          magit-status-mode
          "COMMIT_EDITMSG"                       ;; exact match
          git-commit-ts-mode
          compilation-mode))
  )
(popper-mode +1)

(provide 'init-window)

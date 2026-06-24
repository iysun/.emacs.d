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

;; centaur-tabs：加载 + 全局开启较重（实测 ~2.2s，且仅 GUI 有此开销）。
;; 从启动关键路径移除——启动后空闲 0.3s 再 require，frame 先显示、标签栏稍后瞬间补上，
;; emacs-init-time 不再含这 2.2s。两个 local-mode 钩子移进 with-eval-after-load，
;; 否则启动时 (popper-mode +1) 会经 popper-mode-hook 触发 centaur-tabs 提前加载。
(with-eval-after-load 'centaur-tabs
  (centaur-tabs-mode t)
  (setq centaur-tabs-cycle-scope 'tabs)
  (setq centaur-tabs-height 50)
  (setq centaur-tabs-set-icons t)
  (setq centaur-tabs-icon-type 'nerd-icons)  ; or 'nerd-icons
  (setq centaur-tabs-gray-out-icons 'buffer)
  (setq centaur-tabs-style "box")
  (add-hook 'dashboard-mode-hook 'centaur-tabs-local-mode)
  (add-hook 'popper-mode-hook 'centaur-tabs-local-mode))

(add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-idle-timer 0.3 nil (lambda () (require 'centaur-tabs)))))

(defun my-consult--source-centaur-groups ()
  "Source for switching Centaur Tabs groups."
  `(:name     "Tab Groups"
    :narrow   ?g
    :category centaur-group
    :face     font-lock-type-face
    :items    ,(lambda ()
                  (centaur-tabs-get-groups))
    :action   ,(lambda (group)
                  (centaur-tabs-switch-group group))
    :preview-key nil))  ;; 禁用预览，因为切换group是立即动作

;; 添加到 consult-buffer
(with-eval-after-load 'consult
  (add-to-list 'consult-buffer-sources 
                (my-consult--source-centaur-groups)
                t)
  )

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

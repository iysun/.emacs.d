;; init-completion.el   -*- lexical-binding: t -*-

;; Optionally use the `orderless' completion style.
;; (require 'orderless)
(progn
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  (setq completion-category-overrides '((file (styles basic partial-completion))))
  )

;; marginalia 直接调用 compat 内部符号 compat--seconds-to-string，
;; 而 Emacs 31 上 compat 不再定义它（seconds-to-string 已内置）。
;; 上游未修复前保留此 shim。
(unless (fboundp 'compat--seconds-to-string)
  (defalias 'compat--seconds-to-string #'seconds-to-string))

;; (require 'marginalia)
(add-hook 'after-init-hook 'marginalia-mode)
;; (use-package vertico-posframe
;;   :ensure t
;;   :hook (vertico-mode . vertico-posframe-mode))


;; (require 'vertico)
(with-eval-after-load 'vertico
  (setq vertico-count 10)
  (setq vertico-cycle t)
  )
(add-hook 'after-init-hook  'vertico-mode)
(add-hook 'vertico-mode-hook  'vertico-reverse-mode)
(add-hook 'vertico-mode-hook  'vertico-multiform-mode)


;; (require 'embark)
;; 组合键 C-h 可以展示后续的有效按键
(setq prefix-help-command 'embark-prefix-help-command)
;; Embark 使用 posframe 打开
(progn 
  (defun posframe-display-buffer (buffer)
    (let ((default-fgc (face-attribute 'default :foreground))
          (default-bgc (face-attribute 'default :background))
          (hl (face-attribute 'highlight :background)))
      (when buffer (posframe-show
                    buffer
                    ;; :position (point)
                    :poshandler 'posframe-poshandler-frame-center
                    :font-height 1.0
                    :font-width 1.0
                    ;; :width 120
                    ;; :height 30
                    :border-width 5
                    :left-fringe 20
                    :right-fringe 20
                    :border-color hl
                    :background-color default-bgc))))
  (defun embark-get-buffer-pos-display (orig-fun)
    (interactive)
    (let* ((orig-result (funcall orig-fun)))
      (lambda (&optional keymap targets prefix)
        (let ((result (funcall orig-result keymap targets prefix)))
          (when (and result (windowp result))
            (posframe-display-buffer (window-buffer result))
            (delete-window result))))))
  (advice-add #'embark-verbose-indicator :around #'embark-get-buffer-pos-display)
  )

;; (require 'consult)
(progn
  ;; Tweak the register preview
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)
  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  ;; Optionally configure the narrowing key.
  (setq consult-narrow-key ",")
  )

(add-hook 'completion-list-mode-hook 'consult-preview-at-point-mode)

;; (require 'embark-consult)
;; (with-eval-after-load 'embark-consult
;;   (define-key minibuffer-mode-map (kbd "C-c C-o") 'embark-export)
;;   )
(add-hook 'embark-collect-mode-hook 'consult-preview-at-point-mode)

;; Auto completion - corfu
;;(unless (package-installed-p 'corfu)
;;(package-install 'corfu))

;; (require 'corfu)
;; 设置 corfu 变量（corfu-auto 由下面的补全风格切换按需设置，不在这里写死）
(progn
  (setq corfu-auto-prefix 2)
  (setq corfu-preview-current nil)
  (setq corfu-auto-delay 0.2)
  (setq corfu-popupinfo-delay '(0.4 . 0.2))
  ;; 设置 corfu 字体
  (custom-set-faces
   '(corfu-border ((t (:inherit region :background unspecified)))))
  )
;; corfu / corfu-popupinfo / corfu-terminal 的启停交给下面的补全风格切换统一管理

;; corfu 配置
(with-eval-after-load 'corfu
  (keymap-set corfu-map "RET"
              `(menu-item "" nil :filter
                          ,(lambda (&optional _)
                             ;; 如果当前是 eshell 或 comint 模式，返回 nil (忽略 corfu 绑定)
                             ;; 否则返回 corfu-send (执行 corfu 的补全确认)
                             (unless (or (derived-mode-p 'eshell-mode 'comint-mode)
                                         (minibufferp))
                               #'corfu-send))))

  ;; corfu-map 里的 C-n/C-p 靠 `<remap> <next-line>'/`<remap> <previous-line>' 生效，
  ;; 但 evil insert 状态的 C-n/C-p 直接绑死在 evil-complete-next/-previous（vim 关键字补全）上，
  ;; 命令层级压根不经过 next-line/previous-line，remap 永远不会触发；而 evil 的
  ;; emulation-mode-map-alists 优先级又高于 corfu 挂在 minor-mode-overriding-map-alist
  ;; 上的 corfu-map，所以哪怕给 corfu-map 直接绑 C-n/C-p 也一样会被 evil 截胡。
  ;; 于是直接在 evil-insert-state-map 上按上下文分流：corfu 弹窗活着时转发给
  ;; corfu-next/-previous，否则维持 evil 原生的 C-n/C-p。
  (evil-define-key 'insert 'global (kbd "C-n")
    `(menu-item "" evil-complete-next :filter
                ,(lambda (cmd)
                   (if (and corfu-mode completion-in-region-mode)
                       #'corfu-next
                     cmd))))
  (evil-define-key 'insert 'global (kbd "C-p")
    `(menu-item "" evil-complete-previous :filter
                ,(lambda (cmd)
                   (if (and corfu-mode completion-in-region-mode)
                       #'corfu-previous
                     cmd))))
  )

;; Emacs 原生配置
;; TAB cycle if there are only few candidates
;; (setq completion-cycle-threshold 3)

;; Enable indentation+completion using the TAB key.
;; `completion-at-point' is often bound to M-TAB.
;; (setq tab-always-indent 'complete)

;; Emacs 30 and newer: Disable Ispell completion function.
(setq text-mode-ispell-word-completion nil)

;; Emacs 28 and newer: Hide commands in M-x which do not apply to the current mode.
(setq read-extended-command-predicate #'command-completion-default-include-p)

;; Add extensions - cape
;; cape-dabbrev 默认扫描所有 buffer，在 LSP 模式下会拖慢补全触发，限制为只查当前 buffer
(setq cape-dabbrev-check-other-buffers nil)
(add-to-list 'completion-at-point-functions #'cape-dabbrev)
(add-to-list 'completion-at-point-functions #'cape-file)
(add-to-list 'completion-at-point-functions #'cape-elisp-block)
(add-to-list 'completion-at-point-functions #'cape-keyword)
(add-to-list 'completion-at-point-functions #'cape-abbrev)

;; cape-wrap-buster 已移除：它每次按键都绕过 eglot 缓存强制重新请求 LSP，是输入卡顿的主因。
;; eglot 29+ 自身的缓存机制已足够，无需 buster。

;; 行内补全预览（Emacs 30+ 内置）：打字时在光标后 inline 显示候选词（灰字），
;; 不弹窗、不发 LSP 请求，与 corfu 互补。是否在 prog/text/eshell/comint 四类
;; buffer 里挂载由下面的补全风格切换（my/completion--set-preview-hooks）控制，
;; 这里只配置它自身的行为参数。
(with-eval-after-load 'completion-preview
  (setq completion-preview-minimum-symbol-length 1)
  ;; evil insert 模式下退格/删除后也刷新行内预览
  (dolist (cmd '(evil-delete-backward-char
                 evil-delete-backward-char-and-join
                 evil-delete-char))
    (push cmd completion-preview-commands))
  ;; M-n/M-p 与 diff-hl 的 evil insert 绑定冲突，不覆盖；用 TAB 确认，C-M-i 看完整列表
  )

;; ------------------------------------------------------------------
;; 补全风格切换：corfu 自动弹出 / corfu 手动触发+行内预览 / 仅行内预览
;; 用法仿照 switch-emacs-theme（见 init-ui.el）：交互选择、立即生效、
;; customize-save-variable 存进 custom.el，下次启动 use-completion-style 自动恢复。
;; ------------------------------------------------------------------

(defconst my/completion-styles '(auto manual preview-only)
  "可选补全风格：
auto         corfu 自动弹出（打字即弹），关闭行内预览；
manual       corfu 仅手动触发（C-M-i / my/lsp-complete），开启行内预览；
preview-only 完全关闭 corfu 弹窗，只保留行内预览。")

(defun my/completion--preview-hook-list ()
  '(prog-mode-hook text-mode-hook eshell-mode-hook comint-mode-hook))

(defun my/completion--set-preview-hooks (enable)
  "把 completion-preview-mode 挂/摘到 prog/text/eshell/comint 四个 hook 上。"
  (dolist (hook (my/completion--preview-hook-list))
    (if enable
        (add-hook hook #'completion-preview-mode)
      (remove-hook hook #'completion-preview-mode))))

(defun my/completion--sync-preview-buffers (enable)
  "把已打开、属于上述四类 major-mode 的 buffer 里的 completion-preview-mode 同步到 ENABLE。"
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'prog-mode 'text-mode 'eshell-mode 'comint-mode)
        (completion-preview-mode (if enable 1 -1))))))

(defun my/completion--set-corfu (enable)
  "联动 global-corfu-mode 及其 popupinfo/terminal 全局子模式。三者都是 :global t，
用显式 1/-1 而非 hook 里的隐式 toggle，避免反复切换风格后状态漂移。"
  (global-corfu-mode (if enable 1 -1))
  (corfu-popupinfo-mode (if enable 1 -1))
  (unless (display-graphic-p)
    (corfu-terminal-mode (if enable 1 -1))))

(defun my/apply-completion-style (style)
  "按 STYLE（auto/manual/preview-only）应用补全行为，对已打开的 buffer 立即生效。"
  (pcase style
    ('auto
     (setq corfu-auto t)
     (my/completion--set-corfu t)
     (my/completion--set-preview-hooks nil)
     (my/completion--sync-preview-buffers nil))
    ('manual
     (setq corfu-auto nil)
     (my/completion--set-corfu t)
     (my/completion--set-preview-hooks t)
     (my/completion--sync-preview-buffers t))
    ('preview-only
     (my/completion--set-corfu nil)
     (my/completion--set-preview-hooks t)
     (my/completion--sync-preview-buffers t))
    (_ (error "未知补全风格: %s" style))))

(defun switch-completion-style (style)
  "交互切换补全风格并持久化到 custom.el（仿 switch-emacs-theme）。"
  (interactive
   (list
    (intern (completing-read
             "select completion style: "
             (mapcar #'symbol-name my/completion-styles)
             nil t))))
  (my/apply-completion-style style)
  (customize-save-variable 'custom-completion-style style))

(defun use-completion-style ()
  (my/apply-completion-style
   (if (and (boundp 'custom-completion-style)
            (memq custom-completion-style my/completion-styles))
       custom-completion-style
     'manual)))
(add-hook 'after-init-hook 'use-completion-style)

(provide 'init-completion)

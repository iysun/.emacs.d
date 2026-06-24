;; init-ui.el   -*- lexical-binding: t -*-

;; (set-frame-font "-CTDB-FiraCode Nerd Font-medium-normal-normal-*-26-*-*-*-m-0-iso10646-1" nil t)
;; 按候选顺序选第一个已安装的字体；都没有则用默认，避免缺字体时启动报错。
;; （Windows 上 JetBrainsMono 的家族名常为 "JetBrainsMono NFM"，故一并列入。）
(catch 'font-set
  (dolist (f '("JetBrainsMono Nerd Font" "JetBrainsMono NFM"
               "FiraCode Nerd Font" "FiraCode NFM"))
    (when (member f (font-family-list))
      (set-frame-font f nil t)
      (throw 'font-set t))))
;; 中文字体回退（仅当系统装有该字体时生效）
(when (member "微软雅黑" (font-family-list))
  (set-fontset-font t 'han (font-spec :family "微软雅黑" :size 16)))
;; 开启连体字
(global-prettify-symbols-mode 1)

;;让鼠标滚动更好用
(setq mouse-wheel-scroll-amount '(1 ((shift) . 1) ((control) . nil)))
(setq mouse-wheel-progressive-speed nil)

;; line numbers
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)
(setq display-line-numbers-width 4)

;; auto pair
(electric-pair-mode t)

;; rainbow-delimiters
;; (require 'rainbow-delimiters)
(add-hook 'prog-mode-hook 'rainbow-delimiters-mode)

;; whitespace：display-table 只做字形映射，勿在 glyph 上绑独立 face，否则与 `region`
;; 合并异常（选区发灰/断层）；颜色只设在 `whitespace-space` / `whitespace-tab`（font-lock）。
;; Tab 用 GNU 默认向量；font-lock prepend 减轻 treesit 盖住的问题。
(setq whitespace-style '(face tabs tab-mark spaces space-mark)
      whitespace-display-mappings
      '((space-mark ?\s [?·] [?.])
        (space-mark ?\xa0 [?¤] [?_])
        (tab-mark ?\t [?» ?\t] [?\\ ?\t])))
(setq-default tab-width 2)

(defun my-ui--fg (face fallback)
  (let ((v (face-attribute face :foreground nil t)))
    (if (and (stringp v) (not (equal v "unspecified-fg"))) v fallback)))

(defun my-ui--bg ()
  (let ((v (face-attribute 'default :background nil t)))
    (if (and (stringp v) (not (equal v "unspecified-bg"))) v "#1e1e1e")))

(defun my-ui--whitespace-muted-fg (fg bg)
  "无可用注释色时，在 FG 与 BG 之间折中。"
  (require 'color)
  (condition-case nil
      (let* ((frgb (color-name-to-rgb fg))
             (brgb (color-name-to-rgb bg))
             (fl (+ (car frgb) (cadr frgb) (caddr frgb)))
             (bl (+ (car brgb) (cadr brgb) (caddr brgb))))
        (if (> fl bl)
            (color-darken-name fg 30)
          (color-lighten-name fg 38)))
    (error fg)))

(defun my-ui--blend-fg (color-a color-b a-ratio)
  "线性混合：A-RATIO·COLOR-A + (1-A-RATIO)·COLOR-B，均为颜色名字符串。"
  (require 'color)
  (condition-case nil
      (let* ((ra (color-name-to-rgb color-a))
             (rb (color-name-to-rgb color-b))
             (w2 (- 1.0 a-ratio))
             (r (+ (* a-ratio (car ra)) (* w2 (car rb))))
             (g (+ (* a-ratio (cadr ra)) (* w2 (cadr rb))))
             (b (+ (* a-ratio (caddr ra)) (* w2 (caddr rb)))))
        (color-rgb-to-hex r g b))
    (error color-a)))

(defun my-ui--comment-faded-fg (bg)
  "取主题 `font-lock-comment-face'，向背景拉淡（仍偏注释色相）。"
  (let ((comment (my-ui--fg 'font-lock-comment-face nil))
        (base (my-ui--fg 'default "#d4d4d4")))
    (if (and comment (not (string= comment "unspecified-fg")))
        ;; 越小越淡（越靠近背景）；0.34–0.42 在多数主题下「像注释但更轻」
        (my-ui--blend-fg comment bg 0.38)
      (my-ui--whitespace-muted-fg base bg))))

(defun my-ui-setup-whitespace-faces (&optional _theme _body)
  (require 'whitespace)
  (let* ((bg (my-ui--bg))
         (faded (my-ui--comment-faded-fg bg))
         (base (my-ui--fg 'default "#d4d4d4")))
    (when (or (null faded) (string= faded base))
      (setq faded (my-ui--whitespace-muted-fg base bg)))
    (dolist (x '((whitespace-tab . semi-bold)))
      (set-face-attribute (car x) nil :foreground faded :background nil :weight (cdr x)))
    (dolist (sym '(whitespace-space whitespace-hspace))
      (set-face-attribute sym nil :foreground faded :background nil :weight 'normal))))

(add-hook 'after-init-hook #'my-ui-setup-whitespace-faces t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'my-ui-setup-whitespace-faces))

(defun my-ui-whitespace--after-on ()
  (when whitespace-mode
    (my-ui-setup-whitespace-faces)
    (when (and (bound-and-true-p whitespace-font-lock-keywords) font-lock-mode)
      (font-lock-remove-keywords nil whitespace-font-lock-keywords)
      ;; prepend：优先于 treesit / 其它 append 的 font-lock，空格背景色才可见
      (font-lock-add-keywords nil whitespace-font-lock-keywords 'prepend)
      (font-lock-flush))))
(add-hook 'whitespace-mode-hook #'my-ui-whitespace--after-on)

;; 4. 全局开启
(add-hook 'prog-mode-hook 'whitespace-mode)

;; nerd-icons
;; (require 'nerd-icons)
;; (require 'nerd-icons-completion)
;; (require 'nerd-icons-corfu)
;; (require 'nerd-icons-dired)

(add-hook 'dired-mode-hook 'nerd-icons-dired-mode)
(add-hook 'dired-mode-hook 'diredfl-mode)
(add-hook 'vertico-mode-hook 'nerd-icons-completion-mode)

;; dashboard 首屏已禁用以提速启动（启动直接进 scratch/文件；inhibit-startup-screen 见 early-init.el）。
;; 若想恢复：取消下面 with-eval-after-load 与 (dashboard-setup-startup-hook) 的注释。
;; (with-eval-after-load 'dashboard
;;   (setq dashboard-startup-banner "~/.emacs.d/logo.svg")
;;   (setq dashboard-icon-type 'nerd-icons)
;;   (setq dashboard-set-heading-icons t)
;;   (setq dashboard-set-file-icons t))
;; (dashboard-setup-startup-hook)

;; (load-theme 'wombat)
;; doom-themes
(with-eval-after-load 'doom-themes
  (setq doom-themes-enable-bold t    ; if nil, bold is universally disabled
        doom-themes-enable-italic t) ; if nil, italics is universally disabled
  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (nerd-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (setq doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config)
  )


;; doom-modeline
(require 'doom-modeline)
(with-eval-after-load 'doom-modeline
  (doom-modeline-mode 1)
  (setq doom-modeline-height 50)
  )

(defun set-bigger-spacing ()                                               
  (interactive)
  (setq-local default-text-properties '(line-spacing 0.2 line-height 1.2)))

;; 保存主题
(defun switch-emacs-theme(theme)
  "switch emacs theme"
  (interactive
   (list
    (intern (completing-read 
             "select theme: "
             (mapcar #'symbol-name
                     (custom-available-themes))))))
  
  ;; 禁用所有已启用的主题
  (mapc #'disable-theme custom-enabled-themes)
  
  ;; 加载新主题
  (load-theme theme t)
  
  ;; 使用customize保存到配置文件
  (customize-save-variable 'custom-emacs-theme theme)
  )

(defun use-emacs-theme()
  (if (and (boundp 'custom-emacs-theme)
           (symbolp custom-emacs-theme)
           (not (null custom-emacs-theme)))
      (load-theme custom-emacs-theme t)
    (load-theme 'doom-one t))
  )
(add-hook 'after-init-hook 'use-emacs-theme)

(provide 'init-ui)


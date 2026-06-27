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
;; 中文字体回退（仅当系统装有该字体时生效）。
;; 不写死 :size——之前固定 16 比英文小，导致中文偏小。去掉 size 后中文跟随默认（英文）字号，等大对齐。
(when (member "微软雅黑" (font-family-list))
  (set-fontset-font t 'han (font-spec :family "微软雅黑")))
;; 若想微调中文相对英文的大小（或解决中英行高不齐），用 rescale：>1 放大中文，<1 缩小。
;; (setq face-font-rescale-alist '(("微软雅黑" . 1.1)))
;; 开启连体字
(global-prettify-symbols-mode 1)

;; 精准像素滚动（Emacs 29+，31 更稳定）
(pixel-scroll-precision-mode 1)

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
(setq whitespace-style '(face tabs tab-mark)
      whitespace-display-mappings
      '((tab-mark ?\t [?» ?\t] [?\\ ?\t])))

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
      (set-face-attribute (car x) nil :foreground faded :background 'unspecified :weight (cdr x)))
    (dolist (sym '(whitespace-space whitespace-hspace))
      (set-face-attribute sym nil :foreground faded :background 'unspecified :weight 'normal))))

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

(add-hook 'dired-mode-hook 'diredfl-mode)

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


;; 原生 mode-line（VSCode 风格分栏，基于 Emacs 默认段）——替代 doom-modeline。
;; early-init.el 启动时把 mode-line-format 置 nil（提速），这里在 init 阶段恢复为自定义格式。
(setq-default mode-line-format
              '("%e"
                mode-line-front-space
                (:eval
                 (if (bound-and-true-p evil-local-mode)
                     (format "%s " evil-mode-line-tag)
                   ""))
                mode-line-buffer-identification
                mode-line-format-right-align
                (:eval
                 (when (and (bound-and-true-p flymake-mode)
                            (boundp 'flymake-mode-line-format))
                   (format-mode-line flymake-mode-line-format)))
                " "
                (:eval (when vc-mode (format-mode-line '(vc-mode vc-mode))))
                " "
                mode-line-misc-info
                " "
                mode-line-front-space
                mode-line-end-spaces))

;; 加粗 mode-line / tab-line 并加内边距。box 颜色取各自背景色 → 呈现为 padding 而非边框。
;; 主题加载会重置这些 face，故挂到 enable-theme-functions（每次启用主题后重新应用）+ after-init 兜底。
(defun my-ui--bg-of (face)
  "取 FACE 背景色（含继承）；取不到则回退 default 背景。"
  (or (face-background face nil t) (face-background 'default nil t) "#1e1e1e"))

(defun my-ui-setup-bars (&rest _)
  "把 mode-line / tab-line 调粗并加内边距。"
  (require 'tab-line nil t)                       ; 确保 tab-line-* face 已定义
  ;; mode-line：只用 box 上下 padding 加粗，不动字号（线宽 cons = (左右 . 上下)）
  (dolist (f '(mode-line mode-line-inactive))
    (when (facep f)
      (set-face-attribute f nil :height 'unspecified
                          :box `(:line-width (1 . 6) :color ,(my-ui--bg-of f)))))
  ;; tab-line 整条：只用 box padding，不动字号
  (when (facep 'tab-line)
    (set-face-attribute 'tab-line nil :height 'unspecified
                        :box `(:line-width (1 . 5) :color ,(my-ui--bg-of 'tab-line))))
  ;; 每个标签：左右 + 上下 padding，让标签之间更宽松
  (dolist (f '(tab-line-tab tab-line-tab-current tab-line-tab-inactive))
    (when (facep f)
      (set-face-attribute f nil :box `(:line-width (8 . 6) :color ,(my-ui--bg-of f))))))

(add-hook 'after-init-hook #'my-ui-setup-bars t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'my-ui-setup-bars))

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


;; init-ui.el   -*- lexical-binding: t -*-

;; `cl-loop' 是宏，字节编译期必须先加载 cl-lib，否则被当函数编译成坏 .elc
;; （同 init-evil.el 顶层 require evil 的道理）。
(require 'cl-lib)

(defvar my-ui-default-font-family nil
  "实际选中的默认字体族名。供 nerd-icons 复用，见下方图标字体一节。")

;; ---- 字体 ----
;; 每类字符集各给一串候选，取第一个**系统真装了**的；都没有就沉默跳过，用 Emacs 默认。
;; 用 `find-font' 而非 `(member f (font-family-list))'：后者只比家族名字符串，
;; 对同一字体的不同注册名（Windows 上 "JetBrainsMono Nerd Font" vs "JetBrainsMono NFM"）
;; 容易漏判；`find-font' 走真正的字体匹配。
;; 只在图形界面下做——tty 里 set-fontset-font 无意义且可能报错。
(when (display-graphic-p)
  ;; 默认（英文/等宽）。**不写死字号**——`:height 150' 这种绝对磅值是 zdn 那台机器的
  ;; 合适值，换一台 DPI/缩放不同的机器就会明显偏大或偏小。这里跟随系统/frame 默认，
  ;; 由 mode-line 那边用**相对比例**去贴合，缩放才跨机器一致。
  ;; 真要固定字号，在 custom.el 里设 default 的 :height，别写死在这里。
  (cl-loop for f in '("JetBrainsMono Nerd Font" "JetBrainsMono NFM"
                      "FiraCode Nerd Font" "FiraCode NFM" "Cascadia Code")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (progn
                    (set-frame-font f nil t)
                    (setq my-ui-default-font-family f)))
  ;; 中文。不写死 :size——固定字号会比英文小，导致中英不等高；跟随默认字号才对齐。
  ;; prepend：插到该字符集候选表最前，优先于 Emacs 自带的回退链。
  (cl-loop for f in '("微软雅黑" "Microsoft YaHei" "Sarasa Term SC Nerd" "DengXian")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'han spec nil 'prepend))
  ;; 符号（制表符、箭头、几何图形等；magit/dired 的框线字符会用到）
  (cl-loop for f in '("Segoe UI Symbol" "Symbola" "Symbol")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'symbol spec nil 'prepend))
  ;; Emoji
  (cl-loop for f in '("Noto Color Emoji" "Segoe UI Emoji")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'emoji spec nil 'prepend)))

;; 若想微调中文相对英文的大小（或解决中英行高不齐），用 rescale：>1 放大中文，<1 缩小。
;; (setq face-font-rescale-alist '(("微软雅黑" . 1.1)))

;; ---- 图标字体 ----
;; nerd-icons 默认把所有图标**硬绑**在字体族 "Symbols Nerd Font Mono" 上
;; （它给图标字符串加的是 face `(:family "Symbols Nerd Font Mono")'）。
;; 本机没装这个族，于是 mode-line 的分支/诊断图标全渲染成豆腐块 □。
;;
;; 但本机装的 JetBrainsMono NFM / FiraCode Nerd Font **本身就是打过 Nerd 补丁的字体**，
;; 私用区码位（分支 U+E0A0、诊断 U+EA87 等）都在里面。所以不必再下载字体，
;; 直接把 nerd-icons 指向上面选中的默认字体即可——顺带让图标和正文字体完全一致。
;;
;; 另一条路是 `M-x nerd-icons-install-fonts' 下载安装 Symbols Nerd Font Mono；
;; 那样 nerd-icons 的全部图标集都可用，但要联网 + 装系统字体。
(with-eval-after-load 'nerd-icons
  (when my-ui-default-font-family
    (unless (find-font (font-spec :name nerd-icons-font-family))
      (setq nerd-icons-font-family my-ui-default-font-family))))

;; 连字（ligature）。原先用的 `global-prettify-symbols-mode' 其实是把 "->" 之类
;; **替换成单个字符**（如 →），并非真连字，且会改变列宽、干扰对齐。
;; 这里改用 `composition-function-table'：让字体自己的连字字形生效，字符本身不变。
;; 需要字体支持（JetBrainsMono / FiraCode / Cascadia 都带）。
(dolist (chars '("::" "..." "->" "=>" "<=" ">=" "!==" "!=" "===" "==" "<!--" "-->"
                 "/*" "*/" "&&" "||" "??" "|>" "<|" "++" "--" "<<" ">>"))
  (set-char-table-range
   composition-function-table
   (aref chars 0)
   (nconc (char-table-range composition-function-table (aref chars 0))
          (list (vector (regexp-quote chars) 0 'font-shape-gstring)))))

;; 精准像素滚动（Emacs 29+，31 更稳定）
(pixel-scroll-precision-mode 1)

;; line numbers
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)
(setq display-line-numbers-width 4)

;; auto pair
(electric-pair-mode t)

;; 括号匹配：当配对的开括号已滚出屏幕时，在顶部浮层显示它所在那行。
;; 读长函数 / 深嵌套时很有用，且是内置能力，零依赖。
(setq show-paren-style 'parenthesis
      show-paren-context-when-offscreen 'overlay
      blink-matching-paren-highlight-offscreen t)
(show-paren-mode 1)

;; 标题栏显示文件名，未保存时前置 ●（比默认那串 user@host 有用）
(setq frame-title-format
      '(:eval (concat (if (and buffer-file-name (buffer-modified-p)) "● " "")
                      (buffer-name))))

;; rainbow-delimiters
;; (require 'rainbow-delimiters)
(add-hook 'prog-mode-hook 'rainbow-delimiters-mode)

;; whitespace：显示 Tab（»）与空格（·）占位符。
;; 空格显示曾在 37605ee（2026-06-25「tab 字符设置」）里被一并去掉，这里按需加回。
;; display-table 只做字形映射，勿在 glyph 上绑独立 face，否则与 `region' 合并异常
;; （选区发灰/断层）；颜色统一设在 `whitespace-tab' / `whitespace-space'（走 font-lock）。
;; Tab 用 GNU 默认向量；font-lock prepend 减轻 treesit 盖住的问题。
(setq whitespace-style '(face tabs tab-mark spaces space-mark)
      whitespace-display-mappings
      '((tab-mark   ?\t   [?» ?\t] [?\\ ?\t])
        (space-mark ?\s   [?·]     [?.])
        (space-mark ?\xa0 [?¤]     [?_])))   ; 不换行空格，单独标出来便于发现

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
    ;; Tab 稍重一点（» 比 · 需要更明显），空格用常规字重，避免整片缩进太吵。
    (set-face-attribute 'whitespace-tab nil
                        :foreground faded :background 'unspecified :weight 'semi-bold)
    (dolist (sym '(whitespace-space whitespace-hspace))
      (set-face-attribute sym nil
                          :foreground faded :background 'unspecified :weight 'normal))))

(add-hook 'after-init-hook #'my-ui-setup-whitespace-faces t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'my-ui-setup-whitespace-faces))

(defun my-ui-whitespace--after-on ()
  (when whitespace-mode
    (my-ui-setup-whitespace-faces)
    (when (and (bound-and-true-p whitespace-font-lock-keywords) font-lock-mode)
      (font-lock-remove-keywords nil whitespace-font-lock-keywords)
      ;; prepend：优先于 treesit / 其它 append 的 font-lock，Tab/空格标记才不被盖住
      (font-lock-add-keywords nil whitespace-font-lock-keywords 'prepend)
      (font-lock-flush))))
(add-hook 'whitespace-mode-hook #'my-ui-whitespace--after-on)

;; 4. 全局开启
(add-hook 'prog-mode-hook 'whitespace-mode)

(add-hook 'dired-mode-hook 'diredfl-mode)

;; dashboard 首屏已禁用以提速启动（启动直接进 scratch/文件；inhibit-startup-screen 见 early-init.el）。
;; 若想恢复：取消下面 with-eval-after-load 与 (dashboard-setup-startup-hook) 的注释。
;; (with-eval-after-load 'dashboard
;;   (setq dashboard-startup-banner (expand-file-name "logo.svg" user-emacs-directory))
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

;; ---- fringe 图标 HiDPI 缩放 ----
;; diff-hl/flymake 这类包默认给 fringe 位图只画 8px 宽，在高分屏上偏小/发虚。
;; advice `define-fringe-bitmap'：凡是窄于目标宽度的位图，按位重采样放大到目标宽度
;; （宽高同比缩放）。必须在这些包**定义**自己的位图之前就挂上，故用 `after-init-hook'——
;; 此时 diff-hl/flymake 都还没因为打开文件而加载（两者都是首次开文件才 require）。
;; 算法照搬 https://github.com/blahgeek/emacs-fringe-scale（经由 zdn/.emacs.d 的
;; nn-fringe-scale 转手），逻辑不变，仅去掉 nn- 前缀。
(defconst my/fringe-scale-width 16
  "fringe 位图缩放的目标宽度（像素）。")

(defun my/fringe-scale--scale-width (x orig-width new-width)
  "把一行位图 X 从 ORIG-WIDTH 位宽按位重采样到 NEW-WIDTH 位宽。"
  (let ((res 0) (i 0))
    (while (< i new-width)
      (let* ((j (floor (* orig-width (/ (float i) new-width))))
             (bit (logand 1 (lsh x (- j)))))
        (setq res (logior res (lsh bit i))))
      (setq i (1+ i)))
    res))

(defun my/fringe-scale--scale-height (v orig-height new-height)
  "把位图行向量 V 从 ORIG-HEIGHT 行重采样到 NEW-HEIGHT 行。"
  (let ((res (make-vector new-height nil)) (i 0))
    (while (< i new-height)
      (let* ((j (floor (* orig-height (/ (float i) new-height))))
             (val (elt v j)))
        (aset res i val))
      (setq i (1+ i)))
    res))

(defun my/fringe-scale-advice (orig-func &rest r)
  "`define-fringe-bitmap' 的 :around advice：位图窄于目标宽度时先放大再定义。"
  (let* ((bitmap (nth 0 r))
         (bits (nth 1 r))
         (height (or (nth 2 r) (length bits)))
         (width (or (nth 3 r) 8))
         (align (or (nth 4 r) 'center)))
    (when (< width my/fringe-scale-width)
      (let* ((new-width my/fringe-scale-width)
             (new-height (floor (* height (/ (float new-width) width))))
             (bits-w-scaled (mapcar (lambda (x) (my/fringe-scale--scale-width x width new-width)) bits))
             (bits-h-scaled (my/fringe-scale--scale-height bits-w-scaled height new-height)))
        (setq bits bits-h-scaled
              height new-height
              width new-width)))
    (funcall orig-func bitmap bits height width align)))

(add-hook 'after-init-hook
          (lambda () (advice-add 'define-fringe-bitmap :around #'my/fringe-scale-advice)))

(provide 'init-ui)


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
  ;; 候选表第一项 "JetBrainsMonoNL NFM" 是 assets/fonts/ 里 vendor 的字体
  ;; （JetBrainsMono Nerd Font Mono，NoLigatures 变体，装法见
  ;; scripts/install-fonts.ps1），优先于系统装的 JetBrainsMono/FiraCode 各变体——
  ;; 跑过 install-fonts.ps1 的机器由此落在一个可控、可复现的字体上，不用管系统上
  ;; 恰好装了哪个版本。系统变体、以及没打图标补丁的 Cascadia Code 仍留在候选表
  ;; 垫底，供还没跑安装脚本的机器兜底。
  ;; 名字里的 "NL" 是这个变体在字体自身 name table 里的真实 family 名（不是
  ;; "JetBrainsMono NFM"，实测过，见 install-fonts.ps1 头部注释），系统装的官方
  ;; Ligatures 版才叫 "JetBrainsMono NFM"，两者不是一回事，候选表里都留着。
  (cl-loop for f in '("JetBrainsMonoNL NFM" "JetBrainsMono Nerd Font" "JetBrainsMono NFM"
                      "FiraCode Nerd Font" "FiraCode NFM" "Cascadia Code")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (progn
                    (set-frame-font f nil t)
                    (setq my-ui-default-font-family f)))
  ;; 中文。不写死 :size——固定字号会比英文小，导致中英不等高；跟随默认字号才对齐。
  ;; prepend：插到该字符集候选表最前，优先于 Emacs 自带的回退链。
  ;; 候选表前两项 "更纱终端书呆黑体-简"/"思源黑体" 是 assets/fonts/ 里 vendor 的
  ;; 两个字体（Sarasa Term SC Nerd 的实际 family 名、Source Han Sans SC 的实际
  ;; family 名——都是中文名，不是候选表里 "Sarasa Term SC Nerd" 那个英文名，
  ;; 实测过），优先于系统装的微软雅黑/DengXian，装法见 scripts/install-fonts.ps1；
  ;; "Sarasa Term SC Nerd" 是历史遗留的错误英文名，实测不会真的命中，留着无害。
  (cl-loop for f in '("更纱终端书呆黑体-简" "思源黑体" "微软雅黑" "Microsoft YaHei"
                      "Sarasa Term SC Nerd" "DengXian")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'han spec nil 'prepend))
  ;; 符号（制表符、箭头、几何图形等；magit/dired 的框线字符会用到）。
  ;; "Symbola" 是 assets/fonts/ 里 vendor 的字体（候选名不用改，字体名本来就叫这个），
  ;; 排第一优先于系统的 Segoe UI Symbol。
  (cl-loop for f in '("Symbola" "Segoe UI Symbol" "Symbol")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'symbol spec nil 'prepend))
  ;; Emoji。"Noto Color Emoji" 同样是 vendor 的字体，候选名本来就对得上，排第一位——
  ;; 系统自带的 Segoe UI Emoji 只在没装 vendor 字体时才会用到。
  (cl-loop for f in '("Noto Color Emoji" "Segoe UI Emoji")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'emoji spec nil 'prepend)))

;; 若想微调中文相对英文的大小（或解决中英行高不齐），用 rescale：>1 放大中文，<1 缩小。
;; (setq face-font-rescale-alist '(("微软雅黑" . 1.1)))

;; ---- 图标字体 ----
;; nerd-icons 默认把所有图标**硬绑**在字体族 "Symbols Nerd Font Mono" 上
;; （它给图标字符串加的是 face `(:family "Symbols Nerd Font Mono")'）。
;; 本机没装这个族，于是 mode-line/tab-line 的图标全渲染成豆腐块 □。
;;
;; 但本机装的 JetBrainsMono NFM / FiraCode Nerd Font **本身就是打过 Nerd 补丁的字体**，
;; 私用区码位（分支 U+E0A0、诊断 U+EA87 等）都在里面。所以不必再下载字体，
;; 直接把 nerd-icons 指向上面选中的默认字体即可——顺带让图标和正文字体完全一致。
;;
;; 只在 `my-ui-default-font-family' **确实是打过 Nerd 补丁的那几个**里挑时才这么改：
;; 上面英文字体候选表最后一项 "Cascadia Code" 是没打过 Nerd 补丁的兜底项，本机若连
;; JetBrainsMono/FiraCode 的 Nerd 变体都没装、落到 Cascadia Code，把 nerd-icons 指过去
;; 反而必现豆腐块（之前就是这样：豆腐块换了张脸，还是豆腐块）。这种机器不重定向，
;; 保持 nerd-icons 找不到字体的状态，让各处图标函数走各自的 ignore-errors 回退纯文本，
;; 好过顶着一个看着像字符实则不可读的方块。
;;
;; 另一条路是 `M-x nerd-icons-install-fonts' 下载安装 Symbols Nerd Font Mono；
;; 那样 nerd-icons 的全部图标集都可用，但要联网 + 装系统字体。
(defconst my-ui--nerd-patched-font-families
  '("JetBrainsMono Nerd Font" "JetBrainsMono NFM" "FiraCode Nerd Font" "FiraCode NFM"
    "JetBrainsMonoNL NFM")
  "英文字体候选表里真正打过 Nerd Font 补丁（含图标私用区码位）的族名子集。
特意不含候选表末尾的 \"Cascadia Code\"——见上方「图标字体」一节注释。
\"JetBrainsMonoNL NFM\" 是 assets/fonts/ 里 vendor 的那个变体。")

;; 只要 `my-ui-default-font-family' 在白名单里就无条件重定向，**不再**额外判断
;; "nerd-icons-font-family 现在的值是不是已经能 find-font 到"——这个判断曾经的用意
;; 是"用户已经手动装好默认字体 Symbols Nerd Font Mono 就别多管"，但实测踩了坑：
;; 有台机器上确实注册了一个叫 "Symbols Nerd Font Mono" 的字体（来自某次半途而废的
;; `nerd-icons-install-fonts'，文件名是可疑的 "NFM.ttf"），find-font 能找到它，
;; 于是这个判断为真、跳过重定向，结果图标 face 挂着这个字体名却渲染不出实际字形
;; （不是豆腐块，是完全空白——`char-displayable-p' 只保证*某个*已装字体能显示该码位，
;; 不保证请求的这个 family 本身真的显示得出来）。我们自己选出来的
;; `my-ui-default-font-family' 是刚刚原地 `find-font' 验证过、且正被当前 frame
;; 实际使用的字体，比一个来路不明的同名字体可信得多，直接用它更稳妥。
(with-eval-after-load 'nerd-icons
  (when (and my-ui-default-font-family
             (member my-ui-default-font-family my-ui--nerd-patched-font-families))
    (setq nerd-icons-font-family my-ui-default-font-family)))

;; ---- vendor 的字体：装了没 ----
;; assets/fonts/ 里的字体文件本身进了仓库，但 Windows 上还得跑一遍
;; scripts/install-fonts.ps1 才会真正装进当前用户、被 find-font 认到——字体候选表
;; 本身"找不到就沉默跳过"的哲学不变（见上面几组 cl-loop），但"vendor 的字体明明
;; 在仓库里、却没跑安装脚本"是另一件事：忘跑了比沉默更值得提醒一下。
;; 照抄 init-full.el 里 `my/check-pdmp-freshness' 的思路——正常沉默，
;; 只在"有个手动步骤大概率忘跑了"时才 `display-warning'。
(defconst my-ui--vendored-fonts
  '(("assets/fonts/JetBrainsMonoNLNerdFontMono-Regular.ttf" . "JetBrainsMonoNL NFM")
    ("assets/fonts/SarasaTermSCNerd-Regular.ttf" . "更纱终端书呆黑体-简")
    ("assets/fonts/SourceHanSansSC-Regular.otf" . "思源黑体")
    ("assets/fonts/NotoColorEmoji-WindowsCompatible.ttf" . "Noto Color Emoji")
    ("assets/fonts/Symbola.ttf" . "Symbola"))
  "（仓库内相对路径 . 装好后的 family 名）。供 `my-ui--check-vendored-fonts' 逐项探测。")

(defun my-ui--check-vendored-fonts ()
  "assets/fonts/ 里有字体文件、但 find-font 探测不到对应 family，说明
scripts/install-fonts.ps1 大概率没跑过（或跑了但没重启 Emacs）——`*Warnings*'
里提示一下，别人换新机器 clone 完直接用，容易忘这一步。"
  (when (eq system-type 'windows-nt)
    (let ((missing
           (seq-filter
            (lambda (cell)
              (and (file-exists-p (expand-file-name (car cell) user-emacs-directory))
                   (not (find-font (font-spec :family (cdr cell))))))
            my-ui--vendored-fonts)))
      (when missing
        (display-warning
         'my-ui
         (format "assets/fonts/ 里有 vendor 的字体，但本机还没装：%s
跑一次：
  powershell -ExecutionPolicy Bypass -File scripts\\install-fonts.ps1
装完重启 Emacs。"
                 (mapconcat #'cdr missing "、"))
         :warning)))))
(add-hook 'emacs-startup-hook #'my-ui--check-vendored-fonts)

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

;; diredfl-mode 的 hook 已随 2026-07-28 dired 简化移除（参照 zdn 精简掉 diredfl 包，
;; 见 lisp/init-dired.el）。

;; dashboard 首屏已禁用以提速启动（启动直接进 scratch/文件；inhibit-startup-screen 见 early-init.el）。
;; 若想恢复：取消下面 with-eval-after-load 与 (dashboard-setup-startup-hook) 的注释。
;; (with-eval-after-load 'dashboard
;;   (setq dashboard-startup-banner (expand-file-name "logo.svg" user-emacs-directory))
;;   (setq dashboard-icon-type 'nerd-icons)
;;   (setq dashboard-set-heading-icons t)
;;   (setq dashboard-set-file-icons t))
;; (dashboard-setup-startup-hook)

;; 本仓库自维护的主题目录（不依赖 doom-themes 包）。当前只有 zdn/.emacs.d 借来的
;; nn-world，见 themes/nn-world-theme.el。加了新主题文件放这个目录即可，
;; switch-emacs-theme 靠 custom-available-themes 现场扫这条 load-path，自动出现在候选里。
(add-to-list 'custom-theme-load-path (expand-file-name "themes" user-emacs-directory))

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
    (load-theme 'nn-world t))
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


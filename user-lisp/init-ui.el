;; init-ui.el   -*- lexical-binding: t -*-

;; ⚠ cl-loop 是宏，须顶层 require cl-lib，否则 .elc 报 Invalid function
(require 'cl-lib)

(defvar iys/ui-default-font-family nil
  "实际选中的默认字体族名。供 nerd-icons 复用，见下方图标字体一节。")

(defun iys/ui--setup-fonts ()
  "选择并应用默认/中文/符号/emoji 字体。延迟到 `after-init-hook'，让首帧先出来。"
  (when (display-graphic-p)
  ;; ⚠ 别写死 :height：换 DPI 机器走形
  ;; "NL" 才是该 vendor 字体的真 family 名
  (cl-loop for f in '("JetBrainsMonoNL NFM" "JetBrainsMono Nerd Font" "JetBrainsMono NFM"
                      "FiraCode Nerd Font" "FiraCode NFM" "Cascadia Code")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (progn
                    (set-frame-font f nil t)
                    (setq iys/ui-default-font-family f)))
  ;; ⚠ 中文别写 :size；须 prepend 且前两项用中文 family 名
  (cl-loop for f in '("更纱终端书呆黑体-简" "思源黑体" "微软雅黑" "Microsoft YaHei"
                      "Sarasa Term SC Nerd" "DengXian")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'han spec nil 'prepend))
  (cl-loop for f in '("Symbola" "Segoe UI Symbol" "Symbol")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'symbol spec nil 'prepend))
  (cl-loop for f in '("Noto Color Emoji" "Segoe UI Emoji")
           for spec = (font-spec :family f)
           when (find-font spec)
           return (set-fontset-font t 'emoji spec nil 'prepend)))
  (when (and iys/ui-default-font-family
             (member iys/ui-default-font-family iys/ui--nerd-patched-font-families))
    (setq nerd-icons-font-family iys/ui-default-font-family)))

(defun iys/ui--setup-new-frame-fonts (frame)
  "给新建 GUI frame 应用字体；daemon 下 after-init 时还没有 GUI frame。"
  (unless (frame-parameter frame 'parent-frame)
    (with-selected-frame frame
      (iys/ui--setup-fonts))))

(add-hook 'after-init-hook #'iys/ui--setup-fonts -95)
(add-hook 'after-make-frame-functions #'iys/ui--setup-new-frame-fonts 95)

;; ⚠ nerd-icons 硬绑未装的 "Symbols Nerd Font Mono" → 豆腐块，须重定向
;; ⚠ 只在打过 Nerd 补丁的白名单内重定向；命中即无条件改（别再加 find-font 判断，反成豆腐块）
(defconst iys/ui--nerd-patched-font-families
  '("JetBrainsMono Nerd Font" "JetBrainsMono NFM" "FiraCode Nerd Font" "FiraCode NFM"
    "JetBrainsMonoNL NFM")
  "英文字体候选表里真正打过 Nerd Font 补丁（含图标私用区码位）的族名子集。
特意不含候选表末尾的 \"Cascadia Code\"——见上方「图标字体」一节注释。
\"JetBrainsMonoNL NFM\" 由 dotfiles 仓库 fonts/ 提供（scripts/install-fonts.py 安装）。")

(with-eval-after-load 'nerd-icons
  (when (and iys/ui-default-font-family
             (member iys/ui-default-font-family iys/ui--nerd-patched-font-families))
    (setq nerd-icons-font-family iys/ui-default-font-family)))

;; ⚠ 用 composition-function-table，别用 global-prettify（后者改列宽）
(dolist (chars '("::" "..." "->" "=>" "<=" ">=" "!==" "!=" "===" "==" "<!--" "-->"
                 "/*" "*/" "&&" "||" "??" "|>" "<|" "++" "--" "<<" ">>"))
  (set-char-table-range
   composition-function-table
   (aref chars 0)
   (nconc (char-table-range composition-function-table (aref chars 0))
          (list (vector (regexp-quote chars) 0 'font-shape-gstring)))))

(pixel-scroll-precision-mode 1)

(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)
(setq display-line-numbers-width 4)

(electric-pair-mode t)

(setq frame-title-format
      '(:eval (concat (if (and buffer-file-name (buffer-modified-p)) "● " "")
                      (buffer-name))))

;; ⚠ display-table 只做字形映射，face 设在 whitespace-tab/-space（否则与 region 合并发灰）
(setq whitespace-style '(face tabs tab-mark spaces space-mark)
      whitespace-display-mappings
      '((tab-mark   ?\t   [?» ?\t] [?\\ ?\t])
        (space-mark ?\s   [?·]     [?.])
        (space-mark ?\xa0 [?¤]     [?_])))

(defun iys/ui--fg (face fallback)
  (let ((v (face-attribute face :foreground nil t)))
    (if (and (stringp v) (not (equal v "unspecified-fg"))) v fallback)))

(defun iys/ui--bg ()
  (let ((v (face-attribute 'default :background nil t)))
    (if (and (stringp v) (not (equal v "unspecified-bg"))) v "#1e1e1e")))

(defun iys/ui--whitespace-muted-fg (fg bg)
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

(defun iys/ui--blend-fg (color-a color-b a-ratio)
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

(defun iys/ui--comment-faded-fg (bg)
  "取主题 `font-lock-comment-face'，向背景拉淡（仍偏注释色相）。"
  (let ((comment (iys/ui--fg 'font-lock-comment-face nil))
        (base (iys/ui--fg 'default "#d4d4d4")))
    (if (and comment (not (string= comment "unspecified-fg")))
        (iys/ui--blend-fg comment bg 0.38)
      (iys/ui--whitespace-muted-fg base bg))))

(defun iys/ui-setup-whitespace-faces (&optional _theme _body)
  (require 'whitespace)
  (let* ((bg (iys/ui--bg))
         (faded (iys/ui--comment-faded-fg bg))
         (base (iys/ui--fg 'default "#d4d4d4")))
    (when (string= faded base)
      (setq faded (iys/ui--whitespace-muted-fg base bg)))
    (set-face-attribute 'whitespace-tab nil
                        :foreground faded :background 'unspecified :weight 'semi-bold)
    (dolist (sym '(whitespace-space whitespace-hspace))
      (set-face-attribute sym nil
                          :foreground faded :background 'unspecified :weight 'normal))))

(add-hook 'after-init-hook #'iys/ui-setup-whitespace-faces t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'iys/ui-setup-whitespace-faces))

(defun iys/ui-setup-hl-line (&rest _)
  "当前行不铺底、不改字色。dank 默认 `hl-line' 继承 `highlight'，整行变紫。
改成窗口宽一条细下划线，跟 tab-line 选中标签同一套语言；定位还靠行号。"
  (let ((c (or (iys/ui--fg 'vertical-border nil)
               (iys/ui--fg 'shadow nil)
               (iys/ui--blend-fg (iys/ui--fg 'default "#cccccc") (iys/ui--bg) 0.28))))
    (set-face-attribute 'hl-line nil
                        :inherit nil
                        :background 'unspecified
                        :foreground 'unspecified
                        :box nil
                        :underline `(:color ,c :position 0)
                        :extend t)))

(add-hook 'after-init-hook #'iys/ui-setup-hl-line t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'iys/ui-setup-hl-line))

(defun iys/ui--whitespace-after-on ()
  (when whitespace-mode
    (iys/ui-setup-whitespace-faces)
    (when (and (bound-and-true-p whitespace-font-lock-keywords) font-lock-mode)
      (font-lock-remove-keywords nil whitespace-font-lock-keywords)
      ;; ⚠ prepend 才不被 treesit 等 append 的 font-lock 盖住
      (font-lock-add-keywords nil whitespace-font-lock-keywords 'prepend)
      (font-lock-flush))))
(add-hook 'whitespace-mode-hook #'iys/ui--whitespace-after-on)

(add-hook 'prog-mode-hook 'whitespace-mode)

(add-to-list 'load-path (expand-file-name "themes" user-emacs-directory))
(add-to-list 'custom-theme-load-path (expand-file-name "themes" user-emacs-directory))

;; ⚠ 只通过 M-x 调用，配置里没有引用；不要当成死代码删掉
(defun iys/set-bigger-spacing ()
  "把当前 buffer 的行距加大。"
  (interactive)
  (setq-local default-text-properties '(line-spacing 0.2 line-height 1.2)))

(defcustom iys/emacs-theme nil
  "启动时加载的主题名；nil 表示回退到 `nn-world'。"
  :type 'symbol
  :group 'faces)

(defun iys/switch-emacs-theme (theme)
  "切换并持久化 Emacs 主题。"
  (interactive
   (list
    (intern (completing-read
             "select theme: "
             (mapcar #'symbol-name
                     (custom-available-themes))))))
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t)
  (customize-save-variable 'iys/emacs-theme theme))

(defun iys/use-emacs-theme ()
  "启动时加载 `iys/emacs-theme'；未设置或不存在时回退到 `nn-world'。"
  (let ((theme (or iys/emacs-theme 'nn-world)))
    (load-theme (if (memq theme (custom-available-themes)) theme 'nn-world) t)))
(add-hook 'after-init-hook #'iys/use-emacs-theme)

;; ⚠ 必须早于各包定义位图，故挂 after-init-hook
(defconst iys/fringe-scale-width 8
  "fringe 位图缩放的目标宽度（像素）。等于包定义位图的标准宽度，
只用来兜底放大异常窄的位图，不做整体 HiDPI 放大——见上面的说明。")

(defun iys/fringe-scale--scale-width (x orig-width new-width)
  "把一行位图 X 从 ORIG-WIDTH 位宽按位重采样到 NEW-WIDTH 位宽。"
  (let ((res 0) (i 0))
    (while (< i new-width)
      (let* ((j (floor (* orig-width (/ (float i) new-width))))
             (bit (logand 1 (ash x (- j)))))
        (setq res (logior res (ash bit i))))
      (setq i (1+ i)))
    res))

(defun iys/fringe-scale--scale-height (v orig-height new-height)
  "把位图行向量 V 从 ORIG-HEIGHT 行重采样到 NEW-HEIGHT 行。"
  (let ((res (make-vector new-height nil)) (i 0))
    (while (< i new-height)
      (let* ((j (floor (* orig-height (/ (float i) new-height))))
             (val (elt v j)))
        (aset res i val))
      (setq i (1+ i)))
    res))

(defun iys--fringe-scale-advice (orig-func &rest r)
  "`define-fringe-bitmap' 的 :around advice：位图窄于目标宽度时先放大再定义。
HEIGHT 参数分两种情况，不能一视同仁地跟宽度同比放大：
- 调用方没显式传 HEIGHT（如 `bookmark-mark'、各包的展开箭头）——
  这类是行数固定的小图标，本来就该宽高同比放大，否则放大后会被拉扁。
- 调用方显式传了 HEIGHT（比如直接拿 `frame-char-height' 算出贴满一整行所需的
  真实像素行高）——这个高度已经是按当前行高精算出来的，
  跟位图宽度毫无关系，绝不能再乘一次宽度缩放比例。之前不分青红皂白地
  连高度也一起按宽度比例拉伸，会把「贴满一行」的位图拉得比实际行高还高，
  多出来的部分溢到下一行的 fringe 里——bookmark 等的 fringe 图标错位、
  显示成锯齿状的问题根源就在这。"
  (let* ((bitmap (nth 0 r))
         (bits (nth 1 r))
         (explicit-height (nth 2 r))
         (height (or explicit-height (length bits)))
         (width (or (nth 3 r) 8))
         (align (or (nth 4 r) 'center)))
    (when (< width iys/fringe-scale-width)
      (let* ((new-width iys/fringe-scale-width)
             ;; ⚠ mapcar 返回 list，须 vconcat 成 vector
             (bits-w-scaled (vconcat (mapcar (lambda (x) (iys/fringe-scale--scale-width x width new-width)) bits))))
        (if explicit-height
            (setq bits bits-w-scaled
                  width new-width)
          (let ((new-height (floor (* height (/ (float new-width) width)))))
            (setq bits (iys/fringe-scale--scale-height bits-w-scaled height new-height)
                  height new-height
                  width new-width)))))
    (funcall orig-func bitmap bits height width align)))

(add-hook 'after-init-hook
          (lambda () (advice-add 'define-fringe-bitmap :around #'iys--fringe-scale-advice)))

;; 按 cursor-type 发 DECSCUSR，TTY 下 evil 切状态才看得见光标形状
(setq xterm-update-cursor 'type)

;; ⚠ Windows 终端类型是 w32console，跑不到 `terminal-init-xterm'；VTP 可用时手动装同一套钩子
(defun iys/ui--tty-cursor-init ()
  "TTY 下让光标形状跟随 `cursor-type'（即 evil 状态）。"
  (when (and (eq system-type 'windows-nt)
             (not (display-graphic-p))
             (fboundp 'w32-use-virtual-terminal-p)
             (w32-use-virtual-terminal-p))
    (require 'term/xterm)
    (xterm--init-update-cursor)))

(add-hook 'window-setup-hook #'iys/ui--tty-cursor-init)

(provide 'init-ui)


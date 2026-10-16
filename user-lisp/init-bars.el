;; init-bars.el 	-*- lexical-binding: t -*-
(defun my-ui--glyph-displayable-p (str)
  "STR 里的字符是否都能在当前 frame 上找到字体显示。
nerd-icons 的私用区图标即使字体族没装/没那个码位，`nerd-icons-*' 调用本身
也不报错——只会插入一个没人认得的码位，渲染成豆腐块 □。`ignore-errors' 兜
不住这种情况，得用 `char-displayable-p' 显式探测，探测不到就别用这个字符串，
回退纯文本比顶着豆腐块强。mode-line（user-lisp/mode-line/init-mode-line.el）和
tab-line（user-lisp/tab-line/init-tab-line.el）两边的图标缓存函数都用得到，故放在
这个共享文件里。"
  (and (stringp str)
       (not (string-empty-p str))
       (display-graphic-p)
       (seq-every-p #'char-displayable-p str)))

(require 'init-mode-line)
(require 'init-tab-line)

;; ⚠ 别挂 after-make-frame-functions（初始 frame 不触发），用 after-init + enable-theme-functions
(defconst my-ui-mode-line-height 1.0
  "mode-line / tab-line 字号，相对 default face 的**倍数**。
1.0 = 与正文等大。必须是浮点数才是相对值；写成整数会变成绝对磅值，
在不同 DPI 的机器上会走形。")

(defconst my-ui-bar-padding 2
  "两条 bar 的上下内边距（像素）。mode-line 与 tab-line 用同一个值，厚度才一致。
设 0 则不加 box，退化成最细的一条线。")

(defconst my-ui-tab-current-tint 20
  "选中标签背景相对 bar 背景「浮起」的幅度（百分比，见 `my-ui--tab-block-bg'）。
悬浮态用这个值的一半，选中/悬浮/未选中三态才有渐进层次。深色主题上实测 12 太淡、
选中块几乎看不出来，调到 20 才有清晰对比又不刺眼。")

(defconst my-ui-tab-inactive-tint 6
  "未选中标签 / 分组名（\"Other\" 之类）背景相对 bar 背景「浮起」的幅度
（百分比，同样用 `my-ui--tab-block-bg' 算）。之前这两者背景跟整条 bar 完全一样
（视觉上不可见）——没有自己的可见色块，标签内部的空格 padding 就没有颜色可以
「撑开」，看着仍会像空白。给它们也叠一层比选中态（`my-ui-tab-current-tint'）
淡得多的背景，padding 才有着落。")

(defvar my-ui--tab-accent "#4c9eff"
  "选中标签下划线 / 悬浮高亮 / 修改标记的 accent 色。
主题相关，每次 `my-ui-setup-bars' 时按当前主题重算。")

(defun my-ui--real-color (c)
  "C 是真实颜色名就返回它，否则 nil。
`face-background' 在没有实际背景时会返回伪值 \"unspecified-bg\"，
拿它当 box 颜色会渲染成**可见边框**而非内边距，正是要避免的。"
  (and (stringp c)
       (not (member c '("unspecified-bg" "unspecified-fg")))
       c))

(defun my-ui--bg-of (face)
  "取 FACE 背景色（含继承）；取不到则回退 default 背景，再不行用兜底色。"
  (or (my-ui--real-color (face-background face nil t))
      (my-ui--real-color (face-background 'default nil t))
      "#1e1e1e"))

(defun my-ui--v-box (color)
  "给 COLOR 生成「只当上下内边距、不显边框」的 box 规格（左右线宽固定 1px）。
padding 为 0 则返回 nil。
⚠ 左右不靠这个撑内边距：实测 tab-line 下 `:box' 的水平 line-width 不会用
`:color' 真正填充那片区域——那里会透出 tab-line 整条 bar 自己的背景色，而不是
标签自己的颜色，达不到\"padding 属于标签自己\"的效果（`:box' 的垂直 line-width
则没这个问题，上下 padding 正常）。标签左右内边距因此改成文本里嵌字面空格
（见 `user-lisp/tab-line/init-tab-line.el' 的 `my/tab-line-tab-name'）：
空格字符必然跟标签名共享同一个容器 face（由 `tab-line-tab-name-format-default'
统一套用），颜色不会错，是更可靠的写法。"
  (if (> my-ui-bar-padding 0)
      `(:line-width (1 . ,my-ui-bar-padding) :color ,color)
    nil))

(defun my-ui--bar-box (face)
  "给 FACE 生成「只当内边距、不显边框」的 box 规格；padding 为 0 时返回 nil。"
  (my-ui--v-box (my-ui--bg-of face)))

(defun my-ui--tab-block-bg (bg percent)
  "在 BG 基础上「浮起一层」：深色主题调亮、浅色主题调暗 PERCENT%，
用作选中/悬浮标签的高亮填充色——不管当前主题深浅，视觉上都是一致的层次感，
不用为深浅主题分别写两套颜色。复用内置 `color.el' 的 `color-dark-p'/
`color-lighten-name'/`color-darken-name'，不自己写颜色插值。"
  (if (color-dark-p (color-name-to-rgb bg))
      (color-lighten-name bg percent)
    (color-darken-name bg percent)))

(defun my-ui-setup-bars (&rest _)
  "把 mode-line 与 tab-line 调成字号一致、厚度一致的一对。"
  (require 'tab-line nil t)                       ; 确保 tab-line-* face 已定义
  ;; mode-line-active 是 Emacs 29+，故逐个 facep 判断
  (dolist (f '(mode-line mode-line-active mode-line-inactive))
    (when (facep f)
      (set-face-attribute f nil :height my-ui-mode-line-height
                          :box (my-ui--bar-box f))))
  ;; ⚠ tab-line defface 写死 :inherit variable-pitch，不设 :family 就是比例字体
  (let* ((bar-bg (my-ui--bg-of 'mode-line))
         (bar-fg (or (my-ui--real-color (face-foreground 'mode-line nil t))
                     (my-ui--real-color (face-foreground 'default nil t))
                     "white"))
         (bar-box (my-ui--v-box bar-bg))
         (bar-family (face-attribute 'default :family)))
    (dolist (f '(tab-line tab-line-active tab-line-inactive))
      (when (facep f)
        (set-face-attribute f nil :height my-ui-mode-line-height
                            :family bar-family
                            :background bar-bg :foreground bar-fg
                            :box bar-box)))
    (dolist (f '(tab-line-tab tab-line-tab-current tab-line-tab-inactive tab-line-tab-group))
      (when (facep f)
        (set-face-attribute f nil :height my-ui-mode-line-height
                            :family bar-family
                            :background bar-bg :foreground bar-fg
                            :box bar-box)))
    (when (facep 'tab-line-highlight)
      (set-face-attribute 'tab-line-highlight nil
                          :background bar-bg :box bar-box)))
  (setq my-ui--tab-accent
        (or (my-ui--real-color (face-foreground 'font-lock-function-name-face nil t))
            (my-ui--real-color (face-foreground 'font-lock-keyword-face nil t))
            "#4c9eff"))
  ;; ⚠ :box 颜色须跟背景同色，否则 padding 边缘露出旧背景缝
  ;; ⚠ set-face-attribute 不清空旧值；换主题重跑须显式 :underline nil
  (let* ((bar-bg (my-ui--bg-of 'mode-line))
         (tab-current-bg (my-ui--tab-block-bg bar-bg my-ui-tab-current-tint)))
    (when (facep 'tab-line-tab-current)
      (set-face-attribute 'tab-line-tab-current nil
                          :weight 'bold
                          :underline nil
                          :background tab-current-bg
                          :box (my-ui--v-box tab-current-bg)))
    (when (facep 'tab-line-highlight)
      (let ((hover-bg (my-ui--tab-block-bg bar-bg (/ my-ui-tab-current-tint 2))))
        (set-face-attribute 'tab-line-highlight nil
                            :background hover-bg
                            :box (my-ui--v-box hover-bg)
                            :foreground my-ui--tab-accent))))
  (let* ((bar-bg (my-ui--bg-of 'mode-line))
         (inactive-bg (my-ui--tab-block-bg bar-bg my-ui-tab-inactive-tint))
         (inactive-box (my-ui--v-box inactive-bg))
         (dim-fg (or (my-ui--real-color (face-foreground 'shadow nil t)) 'unspecified)))
    (when (facep 'tab-line-tab-inactive)
      (set-face-attribute 'tab-line-tab-inactive nil
                          :weight 'normal
                          :background inactive-bg
                          :box inactive-box
                          :foreground dim-fg))
    (when (facep 'tab-line-tab-group)
      (set-face-attribute 'tab-line-tab-group nil
                          :background inactive-bg
                          :box inactive-box
                          :foreground dim-fg)))
  (when (facep 'tab-line-tab-modified)
    (set-face-attribute 'tab-line-tab-modified nil
                        :foreground my-ui--tab-accent :slant 'italic))
  (when (facep 'tab-line-close-highlight)
    (set-face-attribute 'tab-line-close-highlight nil :foreground "#e06c75")))

(add-hook 'after-init-hook #'my-ui-setup-bars t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'my-ui-setup-bars))

(provide 'init-bars)

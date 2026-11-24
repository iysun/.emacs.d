;; init-bars.el 	-*- lexical-binding: t -*-
(require 'init-mode-line)
(require 'init-tab-line)

;; ⚠ 别挂 after-make-frame-functions（初始 frame 不触发），用 after-init + enable-theme-functions
(defconst iys/ui-mode-line-height 1.0
  "mode-line / tab-line 字号，相对 default face 的**倍数**。
1.0 = 与正文等大。必须是浮点数才是相对值；写成整数会变成绝对磅值，
在不同 DPI 的机器上会走形。")

(defconst iys/ui-bar-padding 2
  "两条 bar 的上下内边距（像素）。mode-line 与 tab-line 用同一个值，厚度才一致。
设 0 则不加 box，退化成最细的一条线。")

(defconst iys/ui-tab-current-tint 12
  "悬浮标签相对 bar 背景浮起的幅度（百分比）。
选中标签不用这层：它改用正文底色，靠 accent 下划线区分，见 `iys/ui-setup-bars'。")

(defvar iys/ui--tab-accent "#4c9eff"
  "选中标签下划线 / 悬浮高亮 / 修改标记的 accent 色。
主题相关，每次 `iys/ui-setup-bars' 时按当前主题重算。")

(defun iys/ui--real-color (c)
  "C 是真实颜色名就返回它，否则 nil。
`face-background' 在没有实际背景时会返回伪值 \"unspecified-bg\"，
拿它当 box 颜色会渲染成**可见边框**而非内边距，正是要避免的。"
  (and (stringp c)
       (not (member c '("unspecified-bg" "unspecified-fg")))
       c))

(defun iys/ui--bg-of (face)
  "取 FACE 背景色（含继承）；取不到则回退 default 背景，再不行用兜底色。"
  (or (iys/ui--real-color (ignore-errors (face-background face nil t)))
      (iys/ui--real-color (ignore-errors (face-background 'default nil t)))
      "#1e1e1e"))

(defun iys/ui--v-box (color)
  "给 COLOR 生成「只当上下内边距、不显边框」的 box 规格（左右线宽固定 1px）。
padding 为 0 则返回 nil。
⚠ 左右不靠这个撑内边距：实测 tab-line 下 `:box' 的水平 line-width 不会用
`:color' 真正填充那片区域——那里会透出 tab-line 整条 bar 自己的背景色，而不是
标签自己的颜色，达不到\"padding 属于标签自己\"的效果（`:box' 的垂直 line-width
则没这个问题，上下 padding 正常）。标签左右内边距因此改成文本里嵌字面空格
（见 `user-lisp/tab-line/init-tab-line.el' 的 `iys/tab-line-tab-name'）：
空格字符必然跟标签名共享同一个容器 face（由 `tab-line-tab-name-format-default'
统一套用），颜色不会错，是更可靠的写法。"
  (if (> iys/ui-bar-padding 0)
      `(:line-width (1 . ,iys/ui-bar-padding) :color ,color)
    nil))

(defun iys/ui--bar-box (face)
  "给 FACE 生成「只当内边距、不显边框」的 box 规格；padding 为 0 时返回 nil。"
  (iys/ui--v-box (iys/ui--bg-of face)))

(defun iys/ui--tab-block-bg (bg percent)
  "在 BG 基础上「浮起一层」：深色主题调亮、浅色主题调暗 PERCENT%，
用作选中/悬浮标签的高亮填充色——不管当前主题深浅，视觉上都是一致的层次感，
不用为深浅主题分别写两套颜色。复用内置 `color.el' 的 `color-dark-p'/
`color-lighten-name'/`color-darken-name'，不自己写颜色插值。"
  (if (color-dark-p (color-name-to-rgb bg))
      (color-lighten-name bg percent)
    (color-darken-name bg percent)))

(defun iys/ui--divider-color ()
  "分割线用亮色。深色背景大幅提亮，浅色背景用浅灰。"
  (let ((bg (or (iys/ui--real-color (face-background 'default nil t)) "#1e1e1e")))
    (if (color-dark-p (color-name-to-rgb bg))
        (color-lighten-name bg 70)
      "#d0d0d0")))

(defun iys/ui--style-window-divider ()
  "右侧 1px 只用 first-pixel，设成亮色。
底部更宽时，first-pixel 仍是那条亮线，其余像素用 tab-line 的背景。
这截和 tab-line 的上内边距是同一块颜色、同一个像素数。"
  (let ((line (iys/ui--divider-color))
        (bg (iys/ui--bg-of 'tab-line)))
    (when (facep 'window-divider-first-pixel)
      (set-face-attribute 'window-divider-first-pixel nil
                          :foreground line :background line))
    (dolist (f '(window-divider window-divider-last-pixel))
      (when (facep f)
        (set-face-attribute f nil :foreground bg :background bg)))))

(defun iys/ui-setup-bars (&rest _)
  "把 mode-line 与 tab-line 调成字号一致、厚度一致的一对。
托盘开着时 mode-line 不显示，分割线是 1px 的 window divider。"
  (require 'tab-line nil t)                       ; 确保 tab-line-* face 已定义
  ;; mode-line-active 是 Emacs 29+，故逐个 facep 判断
  (dolist (f '(mode-line mode-line-active mode-line-inactive))
    (when (facep f)
      (set-face-attribute f nil :height iys/ui-mode-line-height
                          :box (iys/ui--bar-box f))))
  (let ((bar-bg (iys/ui--bg-of 'mode-line))
        (bar-fg (or (iys/ui--real-color (face-foreground 'mode-line nil t))
                    (iys/ui--real-color (face-foreground 'default nil t))
                    "white")))
  ;; ⚠ tab-line defface 写死 :inherit variable-pitch，不设 :family 就是比例字体
  (let* ((bar-box (iys/ui--v-box bar-bg))
         (bar-family (face-attribute 'default :family)))
    (dolist (f '(tab-line tab-line-active tab-line-inactive
                 tab-line-tab tab-line-tab-current tab-line-tab-inactive tab-line-tab-group))
      (when (facep f)
        (set-face-attribute f nil :height iys/ui-mode-line-height
                            :family bar-family
                            :background bar-bg :foreground bar-fg
                            :box bar-box))))
  (setq iys/ui--tab-accent
        (or (iys/ui--real-color (face-foreground 'font-lock-function-name-face nil t))
            (iys/ui--real-color (face-foreground 'font-lock-keyword-face nil t))
            "#4c9eff"))
  ;; ⚠ set-face-attribute 不清空旧值；换主题重跑须显式清掉上一次的 underline / weight
  ;; 选中标签用正文底色，底部一条 accent，看起来是从正文里伸上来的（centaur-tabs 的 bar）。
  ;; 未选中贴在 bar 上，不再各做一块浮起的色块。
  (let* ((body-bg (iys/ui--bg-of 'default))
         (body-fg (or (iys/ui--real-color (face-foreground 'default nil t)) bar-fg))
         (body-box (iys/ui--v-box body-bg))
         (dim-fg (or (iys/ui--real-color (face-foreground 'shadow nil t)) 'unspecified)))
    (when (facep 'tab-line-tab)
      (set-face-attribute 'tab-line-tab nil
                          :weight 'normal :slant 'normal :underline nil
                          :background body-bg :foreground body-fg
                          :box body-box))
    (when (facep 'tab-line-tab-current)
      (set-face-attribute 'tab-line-tab-current nil
                          :weight 'normal :slant 'normal
                          :underline `(:color ,iys/ui--tab-accent :position 2)
                          :background body-bg :foreground body-fg
                          :box body-box))
    (when (facep 'tab-line-highlight)
      (let ((hover-bg (iys/ui--tab-block-bg bar-bg iys/ui-tab-current-tint)))
        (set-face-attribute 'tab-line-highlight nil
                            :background hover-bg
                            :box (iys/ui--v-box hover-bg)
                            :underline nil
                            :foreground iys/ui--tab-accent)))
    (when (facep 'tab-line-tab-inactive)
      (set-face-attribute 'tab-line-tab-inactive nil
                          :weight 'normal :slant 'normal :underline nil
                          :background bar-bg
                          :box (iys/ui--v-box bar-bg)
                          :foreground dim-fg))
    (when (facep 'tab-line-tab-group)
      (set-face-attribute 'tab-line-tab-group nil
                          :weight 'normal :slant 'normal :underline nil
                          :background bar-bg
                          :box (iys/ui--v-box bar-bg)
                          :foreground iys/ui--tab-accent)))
  (when (facep 'tab-line-tab-modified)
    (set-face-attribute 'tab-line-tab-modified nil
                        :foreground iys/ui--tab-accent :slant 'italic))
  (when (facep 'tab-line-close-highlight)
    (set-face-attribute 'tab-line-close-highlight nil :foreground "#e06c75"))
  (iys/ui--style-window-divider)))

(defun iys/ui--setup-new-frame-bars (frame)
  "在新建 frame 上重跑两条 bar 的设置，取该 frame 的 default face/背景。"
  (unless (frame-parameter frame 'parent-frame)
    (with-selected-frame frame
      (iys/ui-setup-bars))))

(add-hook 'after-init-hook #'iys/ui-setup-bars t)
(add-hook 'after-make-frame-functions #'iys/ui--setup-new-frame-bars 95)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'iys/ui-setup-bars))

(provide 'init-bars)

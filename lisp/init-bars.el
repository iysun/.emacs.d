;; init-bars.el 	-*- lexical-binding: t -*-
;;
;; 两条「bar」：底部 mode-line 与顶部 tab-line。
;; 从 init-ui.el / init-window.el 抽出来单独成模块——这两者要在字号、内边距上
;; 保持一致（见文件末尾的 `my-ui-setup-bars'），放在一起改才不会顾此失彼。
;;
;; 结构：
;;   1. 两条 bar 共用的工具函数（图标可显示性探测等）
;;   2. `extensions/mode-line/mode-line.el' / `extensions/tab-line/tab-line.el' ——
;;      各自实现的本体，各占一个子目录（约定：`extensions/' 下每个扩展独立一层目录，
;;      不直接放 .el 文件，方便以后每个扩展各带自己的资源/测试文件），各文件顶部有
;;      自己的说明。用 `load' 而非 `require'：两个文件按当前用途各自 `provide' 了
;;      `init-mode-line' / `init-tab-line'（tab-line 那个特意不叫 `tab-line'，免得
;;      跟同名内置库撞名），但它们不在 `load-path' 上（`extensions/' 没加进去，
;;      没必要为两个文件多一层全局搜索路径），直接按文件本身的相对位置 `load' 更直接。
;;      `extensions/' 与 `lisp/' 同级（仓库根目录下），故下面用 `..' 回到根目录再拼路径。
;;   3. 两条 bar 的尺寸 —— 字号与上下 padding 统一设置，两边都要用，故留在这里。
(defun my-ui--glyph-displayable-p (str)
  "STR 里的字符是否都能在当前 frame 上找到字体显示。
nerd-icons 的私用区图标即使字体族没装/没那个码位，`nerd-icons-*' 调用本身
也不报错——只会插入一个没人认得的码位，渲染成豆腐块 □。`ignore-errors' 兜
不住这种情况，得用 `char-displayable-p' 显式探测，探测不到就别用这个字符串，
回退纯文本比顶着豆腐块强。mode-line（extensions/mode-line/mode-line.el）和
tab-line（extensions/tab-line/tab-line.el）两边的图标缓存函数都用得到，故放在
这个共享文件里。"
  (and (stringp str)
       (not (string-empty-p str))
       (display-graphic-p)
       (seq-every-p #'char-displayable-p str)))

(let ((dir (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))))
  (load (expand-file-name "extensions/mode-line/mode-line" dir))
  (load (expand-file-name "extensions/tab-line/tab-line" dir)))

;; ================= 两条 bar 的尺寸 =================
;; 上下两条 bar（顶部 tab-line、底部 mode-line）做成**一对**：
;;   - 字号都跟正文一样（不缩小）
;;   - 上下内边距都取同一个值，厚度一致
;; 之前照抄 zdn 把 mode-line 设成 0.87 且去掉 box，结果字偏小、且与仍带 padding
;; 的 tab-line 一薄一厚，两条不像一套——就是这个问题。
;;
;; 上下 padding 用 box 实现，颜色取各自背景色 → 呈现为内边距而不是可见边框。
;; 左右 padding **不**用 box（见 `my-ui--v-box' 的说明——tab-line 下 box 的水平
;; line-width 实测不会用 :color 真正填充，会透出整条 bar 的背景色），标签内部的
;; 左右留白改成文本里嵌字面空格，见 `extensions/tab-line/tab-line.el' 的
;; `my/tab-line-tab-name'。
;;
;; 想再回到 zdn 那种细窄状态条：把 `my-ui-mode-line-height' 改成 0.87、
;; `my-ui-bar-padding' 改成 0（mode-line 会退化成无 box 的一条细线）。
;;
;; 注：zdn 是挂在 `after-make-frame-functions' 上的，那个钩子**对初始 frame 不触发**，
;; 所以它的字号实际只对后开的 frame 生效。这里沿用本仓库的 after-init +
;; enable-theme-functions，初始 frame 也能正确应用。
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
（见 `extensions/tab-line/tab-line.el' 的 `my/tab-line-tab-name'）：
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
  ;; mode-line：字号与正文一致 + 与 tab-line 相同的上下 padding。
  ;; mode-line-active 是 Emacs 29+ 才有的 face，故用 facep 逐个判断。
  (dolist (f '(mode-line mode-line-active mode-line-inactive))
    (when (facep f)
      (set-face-attribute f nil :height my-ui-mode-line-height
                          :box (my-ui--bar-box f))))
  ;; tab-line 整条 + 每个标签：同字号、同上下 padding，且**统一背景/前景到 mode-line**。
  ;; 关键坑：nn-world 主题（跟大多数主题一样）根本没定义任何 tab-line-* face，
  ;; 于是 tab-line/tab-line-tab/tab-line-tab-current 全落回 Emacs 内建 defface 里
  ;; 硬编码的 "grey20"/"grey40" 之类通用灰——跟主题配色毫无关系，选中标签因此顶着一块
  ;; 突兀的灰色方框（视觉上像原生 Emacs 按钮），和左边不带底色的分组名 "Other" 明显不是
  ;; 一套。以前只设 :box 不设 :background，注释说"不动背景免得跟主题打架"，实际效果正相反：
  ;; 不设等于放任 Emacs 的硬编码灰色顶替主题色，才是真正在打架。这里先统一取
  ;; mode-line 的背景/前景当基线（两条 bar 本来就该是一对），下面几段再按选中/
  ;; 悬浮/未选中三态各自叠一层不同幅度的高亮色，层次靠色块深浅区分。
  ;; tab-line-active / tab-line-inactive 是 Emacs 31 新增（选中窗口用 active，其余用
  ;; inactive），目前定义为纯继承 `((t :inherit tab-line))'，所以只设 tab-line 也生效；
  ;; 但主题一旦给它们设了显式属性，继承链就断了，两条 bar 会厚度/颜色不一致，故仍逐个设。
  ;; tab-line-tab-group（分组名，如 "Other"）原生 `:box nil'，不在标签三件套里，
  ;; 于是尺寸/颜色都跟标签对不上——这里把它一起纳入，观感上才像同一条 bar 的一部分。
  ;;
  ;; 字体：Emacs 内置 `tab-line' face（`faces.el'）defface 里写死了
  ;; `:inherit variable-pitch'（比例字体），`tab-line-active'/`tab-line-inactive'/
  ;; `tab-line-tab'/`tab-line-tab-current'/`tab-line-tab-inactive'/`tab-line-tab-group'
  ;; 全部经继承链带上了这个字体族。`mode-line' 的 defface 没有任何 `:inherit'，
  ;; 未设的属性直接落到 `default'（等宽正文字体）——这就是两条 bar 字体本该一样、
  ;; 实际却一个等宽一个比例的根源。上面几处 `set-face-attribute' 一直没显式设
  ;; `:family'，继承来的比例字体因此一直没被盖掉。这里统一显式设成 `default' 的
  ;; 字体族，跟 mode-line 对齐。
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
    ;; 鼠标悬浮标签同样有硬编码灰底 + released-button 边框，一并中和。
    (when (facep 'tab-line-highlight)
      (set-face-attribute 'tab-line-highlight nil
                          :background bar-bg :box bar-box)))
  ;; ---- tab-line：选中标签用背景高亮块（browser / centaur-tabs 观感）----
  ;; accent 色取主题里的强调色，回退固定蓝；下面悬浮高亮、修改标记都复用它。
  (setq my-ui--tab-accent
        (or (my-ui--real-color (face-foreground 'font-lock-function-name-face nil t))
            (my-ui--real-color (face-foreground 'font-lock-keyword-face nil t))
            "#4c9eff"))
  ;; 选中标签：填充一块比 bar 背景「浮起一层」的颜色 + 加粗，不再靠下划线表达选中态——
  ;; 背景块本身已经是清晰的选中信号，叠加下划线反而显乱。:box 颜色必须跟着换成同一个
  ;; 高亮色（而不是上面统一设的 bar-bg），否则标签上下 padding 和它自己的文字背景会
  ;; 露出一圈旧背景色的缝，达不到"一整块"的观感。显式 :underline nil 清掉旧属性——
  ;; `set-face-attribute' 不做值清空，这个函数每次换主题都会重跑，上一次设过的
  ;; underline 不显式清掉会一直留着。
  (let* ((bar-bg (my-ui--bg-of 'mode-line))
         (tab-current-bg (my-ui--tab-block-bg bar-bg my-ui-tab-current-tint)))
    (when (facep 'tab-line-tab-current)
      (set-face-attribute 'tab-line-tab-current nil
                          :weight 'bold
                          :underline nil
                          :background tab-current-bg
                          :box (my-ui--v-box tab-current-bg)))
    ;; 鼠标悬浮标签：选中色一半幅度的过渡色，让「未选中 → 悬浮 → 选中」三态渐进，
    ;; 不是"透明突然跳一大块"。:box 同理换成悬浮色，避免缝隙。
    (when (facep 'tab-line-highlight)
      (let ((hover-bg (my-ui--tab-block-bg bar-bg (/ my-ui-tab-current-tint 2))))
        (set-face-attribute 'tab-line-highlight nil
                            :background hover-bg
                            :box (my-ui--v-box hover-bg)
                            :foreground my-ui--tab-accent))))
  ;; 非选中标签 + 分组名（"Other" 之类）：前景调暗（取 shadow 前景）与选中拉开
  ;; 对比；背景叠一层很淡的高亮（`my-ui-tab-inactive-tint'），:box 颜色跟着换成
  ;; 同一个淡色，道理跟选中标签那段一样：颜色跟标签自己的背景得是同一块，标签
  ;; 文本里嵌的字面空格 padding 才有色块可以"撑开"，而不是纯粹的空白间距。
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
    ;; 分组名不是可点的 tab，靠前景调暗标明这点；背景/box 待遇跟非选中标签
    ;; 保持一致，才不会显得像"没跟上"其它标签的观感。
    (when (facep 'tab-line-tab-group)
      (set-face-attribute 'tab-line-tab-group nil
                          :background inactive-bg
                          :box inactive-box
                          :foreground dim-fg)))
  ;; 改动未存的标签（原生 `tab-line-tab-face-modified' 会自动套 `tab-line-tab-modified'）：
  ;; accent 色 + 斜体，与标签名后的 ● 呼应（颜色/斜体 + 小圆点双保险）。
  (when (facep 'tab-line-tab-modified)
    (set-face-attribute 'tab-line-tab-modified nil
                        :foreground my-ui--tab-accent :slant 'italic))
  ;; 关闭按钮 × 悬浮时变红，醒目。
  (when (facep 'tab-line-close-highlight)
    (set-face-attribute 'tab-line-close-highlight nil :foreground "#e06c75")))

(add-hook 'after-init-hook #'my-ui-setup-bars t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'my-ui-setup-bars))

(provide 'init-bars)

;; init-bars.el 	-*- lexical-binding: t -*-
;;
;; 两条「bar」：底部 mode-line 与顶部 tab-line。
;; 从 init-ui.el / init-window.el 抽出来单独成模块——这两者要在字号、内边距上
;; 保持一致（见文件末尾的 `my-ui-setup-bars'），放在一起改才不会顾此失彼。
;;
;; 结构：
;;   1. 两条 bar 共用的工具函数（图标可显示性探测等）
;;   2. `lisp/extensions/mode-line/mode-line.el' / `lisp/extensions/tab-line/tab-line.el' ——
;;      各自实现的本体，各占一个子目录（约定：`extensions/' 下每个扩展独立一层目录，
;;      不直接放 .el 文件，方便以后每个扩展各带自己的资源/测试文件），各文件顶部有
;;      自己的说明。用 `load' 而非 `require'：两个文件按当前用途各自 `provide' 了
;;      `init-mode-line' / `init-tab-line'（tab-line 那个特意不叫 `tab-line'，免得
;;      跟同名内置库撞名），但它们不在 `load-path' 上（`lisp/extensions/' 没加进去，
;;      没必要为两个文件多一层全局搜索路径），直接按文件本身的相对位置 `load' 更直接。
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

(let ((dir (file-name-directory (or load-file-name buffer-file-name))))
  (load (expand-file-name "extensions/mode-line/mode-line" dir))
  (load (expand-file-name "extensions/tab-line/tab-line" dir)))

;; ================= 两条 bar 的尺寸 =================
;; 上下两条 bar（顶部 tab-line、底部 mode-line）做成**一对**：
;;   - 字号都跟正文一样（不缩小）
;;   - 上下内边距都取同一个值，厚度一致
;; 之前照抄 zdn 把 mode-line 设成 0.87 且去掉 box，结果字偏小、且与仍带 padding
;; 的 tab-line 一薄一厚，两条不像一套——就是这个问题。
;;
;; padding 用 box 实现，颜色取各自背景色 → 呈现为内边距而不是可见边框。
;; 线宽 cons 语义：(左右 . 上下)。
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

(defconst my-ui-tab-side-padding 8
  "tab-line 每个标签的左右内边距（像素），让标签之间松一些。")

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

(defun my-ui--bar-box (face)
  "给 FACE 生成「只当内边距、不显边框」的 box 规格；padding 为 0 时返回 nil。"
  (if (> my-ui-bar-padding 0)
      `(:line-width (1 . ,my-ui-bar-padding) :color ,(my-ui--bg-of face))
    nil))

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
  ;; 不设等于放任 Emacs 的硬编码灰色顶替主题色，才是真正在打架。这里统一取 mode-line
  ;; 的背景/前景（两条 bar 本来就该是一对），tab 的选中态改由下面的下划线+加粗承担，
  ;; 不再依赖背景色差异。
  ;; tab-line-active / tab-line-inactive 是 Emacs 31 新增（选中窗口用 active，其余用
  ;; inactive），目前定义为纯继承 `((t :inherit tab-line))'，所以只设 tab-line 也生效；
  ;; 但主题一旦给它们设了显式属性，继承链就断了，两条 bar 会厚度/颜色不一致，故仍逐个设。
  ;; tab-line-tab-group（分组名，如 "Other"）原生 `:box nil'，不在标签三件套里，
  ;; 于是尺寸/颜色都跟标签对不上——这里把它一起纳入，观感上才像同一条 bar 的一部分。
  (let* ((bar-bg (my-ui--bg-of 'mode-line))
         (bar-fg (or (my-ui--real-color (face-foreground 'mode-line nil t))
                     (my-ui--real-color (face-foreground 'default nil t))
                     "white"))
         (bar-box (and (> my-ui-bar-padding 0)
                       `(:line-width (1 . ,my-ui-bar-padding) :color ,bar-bg)))
         (tab-box (and (> my-ui-bar-padding 0)
                       `(:line-width (,my-ui-tab-side-padding . ,my-ui-bar-padding)
                         :color ,bar-bg))))
    (dolist (f '(tab-line tab-line-active tab-line-inactive))
      (when (facep f)
        (set-face-attribute f nil :height my-ui-mode-line-height
                            :background bar-bg :foreground bar-fg
                            :box bar-box)))
    (dolist (f '(tab-line-tab tab-line-tab-current tab-line-tab-inactive tab-line-tab-group))
      (when (facep f)
        (set-face-attribute f nil :height my-ui-mode-line-height
                            :background bar-bg :foreground bar-fg
                            :box tab-box)))
    ;; 鼠标悬浮标签同样有硬编码灰底 + released-button 边框，一并中和。
    (when (facep 'tab-line-highlight)
      (set-face-attribute 'tab-line-highlight nil
                          :background bar-bg :box tab-box)))
  ;; ---- tab-line：找回 centaur-tabs 观感（选中下划线 accent + 选中/非选中对比）----
  ;; accent 色取主题里的强调色，回退固定蓝；下面选中下划线、悬浮、修改标记都复用它。
  (setq my-ui--tab-accent
        (or (my-ui--real-color (face-foreground 'font-lock-function-name-face nil t))
            (my-ui--real-color (face-foreground 'font-lock-keyword-face nil t))
            "#4c9eff"))
  ;; 选中标签：底部 accent 下划线 + 加粗。背景已在上面统一成与 bar 相同，
  ;; 选中态完全靠下划线 + 加粗表达，不再靠背景色块——这是 centaur-tabs 观感里
  ;; "选中下划线" 那部分，也顺带避开了 Emacs 内建灰色块的问题。
  ;; （:box 的下 padding 仍在，下划线落在文字底、padding 之上，呈现为一条底部彩条。）
  (when (facep 'tab-line-tab-current)
    (set-face-attribute 'tab-line-tab-current nil
                        :weight 'bold
                        :underline `(:color ,my-ui--tab-accent :style line)))
  ;; 非选中标签：前景调暗（取 shadow 前景），与选中拉开对比。
  (when (facep 'tab-line-tab-inactive)
    (set-face-attribute 'tab-line-tab-inactive nil
                        :weight 'normal
                        :foreground (or (my-ui--real-color (face-foreground 'shadow nil t))
                                        'unspecified)))
  ;; 分组名（"Other" 之类）：跟非选中标签一样调暗前景，标明它不是可点的 tab。
  (when (facep 'tab-line-tab-group)
    (set-face-attribute 'tab-line-tab-group nil
                        :foreground (or (my-ui--real-color (face-foreground 'shadow nil t))
                                        'unspecified)))
  ;; 鼠标悬浮标签：accent 前景高亮。
  (when (facep 'tab-line-highlight)
    (set-face-attribute 'tab-line-highlight nil :foreground my-ui--tab-accent))
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

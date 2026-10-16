;;; -*- lexical-binding: t; -*-

;; tree-sitter 模式路由（Emacs 31 内置 `treesit-enabled-modes'，替代第三方 treesit-auto）。
;;
;; ⚠ **必须用 `setopt'，不能用 `setq'**。`treesit-enabled-modes' 的 defcustom 带 `:set'
;; 处理器，真正干活的是那个 `:set'——它按 `treesit-major-mode-remap-alist' 去填
;; `major-mode-remap-alist'。`setq' 只改变量值、不触发 `:set'，于是一条 remap 都不会生成，
;; 而且**没有任何报错**。实测（31.0.91）：setq → 0 条，setopt → 26 条。
;; 连带后果是下面的 `eglot-ensure' 全部失效（它们只挂在 *-ts-mode-hook 上）。
;;
;; 这里显式列出要启用的 mode，而不是图省事写 t：t 会把 26 个 ts-mode 全部 remap，
;; 包括本机没装 grammar 的，打开对应文件就会被 `treesit-auto-install-grammar'（默认 'ask）
;; 拦下来问要不要现场编译 grammar。列白名单等价于旧版逐语言 `treesit-ready-p' 把关：
;; 缺 grammar 的语言留在原生 mode，安静且可预期。
;; （Windows 上 grammar DLL 常因 ABI 不匹配加载失败，这一点尤其重要。）
;;
;; 下面这份是「`~/.emacs.d/tree-sitter/` 下实际可用的 grammar」∩「31 能 remap 的 ts-mode」，
;; 用 `treesit-language-available-p' 逐个验过。装了新 grammar 后记得往这里加。
;; ⚠ 这份白名单只对**非 maybe 路由**的语言是硬开关（C/C++/Python/JS/Java/Ruby/Lua/CSS/
;; TOML/JSON/HTML 靠它生成的 remap 才会走 ts-mode）；maybe 路由的语言（go/go.mod/go.work/
;; rust/typescript/tsx/yaml/php/elixir/heex/dockerfile…）由 `<x>-ts-mode-maybe' 自己看
;; grammar——grammar 在就直接选 ts-mode，所以 typescript/tsx 装完 grammar 后不必写进来。
;; 当前仍缺 grammar 故未进的：bash、csharp、cmake。
;; `setopt' 会自动 require treesit，无需手动 require。
;; 延迟到启动后设置：treesit 是内置但未预载，`setopt' 会加载它并生成一批 remap，
;; 这一步占 init 的可观时间。放到 `emacs-startup-hook'（首帧/用户输入之前）既让 init
;; 更快，又保证打开代码文件前 remap 已生效。
(add-hook 'emacs-startup-hook
          (lambda ()
            (setopt treesit-enabled-modes
                    '(go-ts-mode go-mod-ts-mode go-work-ts-mode
                      python-ts-mode js-ts-mode json-ts-mode
                      c++-ts-mode
                      css-ts-mode mhtml-ts-mode php-ts-mode
                      java-ts-mode lua-ts-mode ruby-ts-mode rust-ts-mode
                      yaml-ts-mode toml-ts-mode dockerfile-ts-mode
                      elixir-ts-mode heex-ts-mode)))
          -90)

;; 补充 ts-mode 不自带 grammar 源的语言。31 里大多数语言的 recipe 直接写在对应
;; `*-ts-mode.el' 里（带 `:commit' pin：typescript/tsx 见 typescript-ts-mode.el、
;; php/phpdoc 见 php-ts-mode.el、rust/toml/yaml/dockerfile/go/c/cpp/json… 同理），
;; 只有下面的 python / javascript 这类要在这里补。缺 grammar 时
;; `M-x treesit-install-language-grammar' 按 recipe 拉取即可（typescript/tsx/phpdoc 已装）。
;; ⚠ `add-to-list' 是**头插**，而自带 recipe 都用 append 插到尾部：下面与自带 recipe 同名的
;; 语言（go/gomod/c/cpp）会盖掉 Emacs 那条带 pin 的，装到的是默认分支而非验过的版本。
(setq treesit-language-source-alist
      '((go         "https://github.com/tree-sitter/tree-sitter-go")
        (gomod      "https://github.com/camdencheek/tree-sitter-go-mod")
        (python     "https://github.com/tree-sitter/tree-sitter-python")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
        (c          "https://github.com/tree-sitter/tree-sitter-c")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")))

(setq completion-ignore-case t)                   ; capf 匹配时不区分大小写
(setq read-process-output-max (* 4 1024 1024))    ; 4MB，减少 LSP 大响应的分批 I/O

;; xref 用 ripgrep 而非默认 grep（本机 rg 已装）。影响 xref-find-references
;; 在无 LSP 时的回退搜索，以及 project 相关的查找。
(when (executable-find "rg")
  (setq xref-search-program 'ripgrep))

;; 不再 eager (require 'eglot)（省 ~1.1s 启动）。
;; 下面的 eglot-ensure 钩子会在打开对应代码文件时自动加载 eglot。
;;
;; ⚠ **每个语言两条 hook 都挂**：`<x>-ts-mode' 与它的原生 mode。只挂 ts-mode 那条必漏——
;; 文件最终落到哪个 mode 由「grammar 是否可用」+上面的 `treesit-enabled-modes' 白名单
;; 共同决定，同一个语言有三种落点：
;;   1. 原生 mode：Emacs 31 只给部分语言装了 `<x>-ts-mode-maybe' 路由（C/C++/Python/JS/
;;      Java/Ruby/Lua/CSS/TOML/JSON/HTML… 都没有），这些语言的 ts-mode 只能靠白名单生成的
;;      remap；不在白名单就落原生 mode——实测 c-ts-mode 不在白名单、.c 落 c-mode（e6ee817）。
;;   2. `fundamental-mode'：有 maybe 路由的语言在 grammar 缺失、又不在白名单时，兜底是
;;      fundamental-mode 而**不是**原生 mode（实测 .ts/.tsx 现在就是这样：typescript
;;      grammar 本机没装）。这种落点没有任何 mode hook 能兜，只能把 grammar 装上。
;;   3. 第三方原生 mode：go-mode / rust-mode / typescript-mode…（装了对应包才会走到）。
;; 故按语言成对列在下面这张表里，两条都挂；加语言只加一行。
;; （java/ruby/lua/css/toml/yaml/php/elixir/dockerfile/json/html 故意没列：本机没装对应
;;   server（jdtls/solargraph/lua-language-server/…），挂上只会在打开文件时报
;;   "None of … are valid executables"；装了 server 再往表里加行即可。）
(defconst my/lsp-modes
  '((c-ts-mode          c-mode)        ; clangd（.h 走 c-or-c++-mode，内部会调 c/c++-mode）
    (c++-ts-mode        c++-mode)
    (python-ts-mode     python-mode)   ; pyright
    (js-ts-mode         js-mode)       ; typescript-language-server
    (typescript-ts-mode typescript-mode)
    (tsx-ts-mode        nil)           ; 无原生对应 mode
    (go-ts-mode         go-mode)       ; gopls
    (go-mod-ts-mode     go-dot-mod-mode)
    (go-work-ts-mode    go-dot-work-mode)
    (rust-ts-mode       rust-mode))    ; rust-analyzer
  "开了 eglot 的语言，每个元素是 (TS-MODE 原生-MODE)；原生-MODE 为 nil 表示没有对应 mode。

同一语言可能落到哪个 mode 取决于 grammar 与 `treesit-enabled-modes'，故两条都要挂
`eglot-ensure'——只挂 ts-mode 那条会在 grammar 缺失或未 remap 时完全不起 LSP。")

(dolist (modes my/lsp-modes)
  (dolist (m modes)
    (when m (add-hook (intern (format "%s-hook" m)) 'eglot-ensure))))

;; eglot 专属设置移进 with-eval-after-load，避免 setq 早于 defcustom 定义的不确定性。
(with-eval-after-load 'eglot
  (setq eglot-autoshutdown t)
  ;; 关闭事件日志（省内存 + 省每条消息的日志构造开销）。
  ;; ⚠ 这里**必须**设 `eglot-events-buffer-config'，不能设旧的 `eglot-events-buffer-size'：
  ;; 后者自 eglot 1.16 起废弃，全 eglot 只在 `eglot-events-buffer-config' 的 defcustom
  ;; 默认值表达式里被读一次，即 **eglot 加载那一刻**。写在 with-eval-after-load 里必然太晚，
  ;; 静默无效（本仓库此前就是这样，"关掉事件日志"其实一直没生效）。
  (setq eglot-events-buffer-config '(:size 0 :format short))
  (setq eglot-sync-connect 0)               ; 异步连接，打开文件不阻塞
  (setq eglot-send-changes-idle-time 0.5)   ; 停止输入 0.5s 后才把变更推给 LSP（默认值，显式写出）
  (setq eglot-ignored-server-capabilities   ; 关掉这几项高频、低收益的服务端推送
        '(:inlayHintProvider                ; inlay hints：通知量大
          :documentHighlightProvider        ; 光标停留就高亮同名符号，每次移动都发请求
          :foldingRangeProvider))           ; 折叠区间：本配置没用折叠
  (setq eldoc-idle-delay 0.5)               ; 延迟 eldoc hover 请求（= 默认值，显式写出；调小会明显增加 LSP 请求）

  ;; gopls 专项调优：关闭代价高的静态分析，按需开启
  (setq-default eglot-workspace-configuration
                '(:gopls (:staticcheck       :json-false
                          :analyses          (:unusedparams t :shadow t)
                          :usePlaceholders   t
                          :completeUnimported t)))

  (add-to-list 'eglot-server-programs '((c++-ts-mode c++-mode c-ts-mode c-mode) "clangd"))
  (add-to-list 'eglot-server-programs '((python-ts-mode python-mode) "pyright-langserver" "--stdio"))
  ;; TS/JS 这条必须**把每个可能落到的 mode 都列上**（同 clangd 那条的理由），否则
  ;; js-mode / typescript-mode 在 grammar 缺失时会退回 eglot 内置 entry。
  ;; 另外这里**必须显式写 :language-id**：内置那条（(js-mode :language-id "javascript") …）
  ;; 本来是齐的，但被本 entry 头插顶掉了，而 eglot 的默认 language-id 是从 mode 名剥掉
  ;; `-mode'/`-ts-mode' 推出来的（js-ts-mode→"js"、tsx-ts-mode→"tsx"），tsserver 只认
  ;; javascript/javascriptreact/typescript/typescriptreact，故照内置的写法抄全。
  ;; （钉死 typescript-language-server，不走内置 eglot-alternatives 的 rass 选择。）
  (add-to-list 'eglot-server-programs
               '(((js-mode            :language-id "javascript")
                  (js-ts-mode         :language-id "javascript")
                  (tsx-ts-mode        :language-id "typescriptreact")
                  (typescript-ts-mode :language-id "typescript")
                  (typescript-mode    :language-id "typescript"))
                 "typescript-language-server" "--stdio"))
  (require 'consult-eglot)

  (defun my/lsp-complete ()
    "手动触发补全（C-M-i）。
eglot-managed-mode-hook 已经把 completion-at-point-functions 换成了
`cape-capf-super' 合并出的单个 capf（eglot + 本地 capf 一起给候选），
自动弹出的 corfu 用的也是同一个，这里直接调 `completion-at-point' 即可，
留这个命令只是为了在 corfu-auto 关闭的补全风格下也有手动触发入口。"
    (interactive)
    (call-interactively #'completion-at-point))

  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              ;; 原先用 `remq' 把 eglot-completion-at-point 从默认列表里摘掉，
              ;; 只在 C-M-i 手动触发时才合并 LSP 候选——因为 completion-at-point-functions
              ;; 逐个尝试、第一个返回非 nil 就停，eglot 的 capf 一旦排在前面会
              ;; 挡住 cape-dabbrev/cape-file 这些本地源。现在改成用 `cape-capf-super'
              ;; 把 eglot 和本地 capf 合并成一个 capf 放在列表最前面，让自动弹出
              ;; 的 corfu 也能同时看到 LSP + 本地候选，不用每次都按 C-M-i。
              (setq-local completion-at-point-functions
                          (cons (cape-capf-super
                                 #'eglot-completion-at-point
                                 #'cape-dabbrev
                                 #'cape-keyword
                                 #'cape-file)
                                (remq 'eglot-completion-at-point
                                      completion-at-point-functions)))
              (local-set-key (kbd "C-M-i") #'my/lsp-complete)
              ;; ⚠ 把 citre 的 xref backend 抢回 eglot 前面：eglot--managed-mode 启用时
              ;; 会往 buffer-local `xref-backend-functions' 头插 `eglot-xref-backend'
              ;; （见 eglot.el），而 citre-mode 更早（prog-mode-hook 阶段）就已经头插了
              ;; `citre-xref-backend'——`add-hook' 不 append 时后来者居上，于是 eglot
              ;; 排到 citre 前面，`xref-find-backend'（gd/M-./M-?/C-M-. 都走它）永远先
              ;; 问 eglot，答不出直接放弃，不会退到 citre 的 tags/global 兜底。
              ;; `citre-xref-backend' 内部本来就会先试 eglot（citre-find-definition-backends
              ;; 默认 `(eglot tags global)'），所以把它排回最前面，LSP 语义结果不受影响，
              ;; 只是多了 LSP 答不出时的 tags/global 兜底。只有 citre-mode 确实开着
              ;; （buffer-local 列表里能找到 `citre-xref-backend'）才重排，避免在没装
              ;; readtags 时对着不存在的 backend 瞎折腾。
              (when (memq 'citre-xref-backend xref-backend-functions)
                (setq-local xref-backend-functions
                            (cons 'citre-xref-backend
                                  (remq 'citre-xref-backend
                                        xref-backend-functions)))))))

;; jsonrpc 每条 LSP 消息都会调 `jsonrpc--log-event' 构造日志对象。上面已把事件缓冲区
;; 设为 0（不保留内容），但**构造开销仍在**——直接 fset 成 ignore 才能整条掐掉。
;; 代价：`M-x eglot-events-buffer' 里永远是空的。要抓 LSP 协议时把这行注释掉，
;; 并把 eglot-events-buffer-config 的 :size 调大。
(with-eval-after-load 'jsonrpc
  (fset #'jsonrpc--log-event #'ignore))

;; Workaround: eglot 的 track-changes 回调有时把 marker 对象直接放进 LSP 消息结构，
;; 导致 jsonrpc--json-encode 在序列化时报 "Wrong type argument: consp, #<marker>"。
;; 上游 bug，在修复合并前用此 advice 兜底：递归把 marker 替换为整数位置再编码。
(with-eval-after-load 'jsonrpc
  (defun my/jsonrpc-sanitize-markers (obj)
    (cond
     ((markerp obj) (marker-position obj))
     ((consp obj)
      (cons (my/jsonrpc-sanitize-markers (car obj))
            (my/jsonrpc-sanitize-markers (cdr obj))))
     ((vectorp obj)
      (cl-map 'vector #'my/jsonrpc-sanitize-markers obj))
     (t obj)))
  (advice-add 'jsonrpc--json-encode :filter-args
              (lambda (args) (list (my/jsonrpc-sanitize-markers (car args))))))

;; Workaround: `eglot--find-buffer-visiting' 用 `equal' 逐字符比较 `buffer-file-name'
;; 来找诊断该报给哪个 buffer（见 eglot--flymake-handle-push），大小写敏感。
;; gopls 在 Windows 上返回的 publishDiagnostics URI 盘符是系统规范化后的大写
;; （如 file:///D:/...），而 Emacs buffer-file-name 保留你打开文件时实际用的大小写
;; （通常是小写 d:/...）。两边大小写一对不上，`eglot--find-buffer-visiting' 就找不到
;; 已经打开的 buffer——整条 gopls → eglot 链路看起来完全正常（*eglot events* 里能看到
;; publishDiagnostics 正常送达），诊断却被静默塞进 `flymake-list-only-diagnostics'，
;; 从不出现在实际打开的 buffer 里，flymake 计数器和波浪线全程无反应。
;; 上游 bug，用 :around advice 兜底：精确匹配失败时，Windows 下再做一次大小写不敏感的重试。
(with-eval-after-load 'eglot
  (define-advice eglot--find-buffer-visiting (:around (orig server abspath) my/case-insensitive-fallback)
    (or (funcall orig server abspath)
        (when (eq system-type 'windows-nt)
          (cl-loop for b in (eglot--managed-buffers server)
                   when (with-current-buffer b
                          (and buffer-file-name
                               (eq t (compare-strings abspath nil nil
                                                       buffer-file-name nil nil t))))
                   return b)))))

(provide 'init-lsp)

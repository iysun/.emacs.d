;;; init-externals.el --- 本配置依赖的外部程序（手动检测，不自动跑）  -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun iys/externals--im-select ()
  (and (boundp 'iys/im-select-path)
       (file-exists-p iys/im-select-path)
       iys/im-select-path))

(defconst iys/external-programs
  '((:bin "git" :class core :why "VC、eshell 提示符、consult-git-grep")
    (:bin "rg" :class feature :why "xref 搜索、consult-ripgrep（M-s r）")
    (:bin "fd" :class feature :why "consult-fd（M-s f）、fd-dired。Debian 二进制常叫 fdfind，PATH 上要有名为 fd 的入口")
    (:bin "locate" :class feature :why "consult-locate（M-s c）")
    (:bin "ctags" :class feature :why "Universal Ctags；lspmux 建/增量符号索引（不写仓库 tags 文件）")
    (:bin "shfmt" :class feature :why "apheleia 格式化 sh-mode")
    (:bin "node" :class feature :why "npm 语言服务器（html/css/ts/pyright）的运行时")
    (:bin "lspmux" :class lang :why "eglot 唯一入口；源在 vendor/lspmux submodule，cargo install 后进 PATH")
    (:bin "vscode-html-language-server" :class lang :why "HTML（lspmux 上游）")
    (:bin "vscode-css-language-server" :class lang :why "CSS buffer，以及 HTML 里的 <style>")
    (:bin "typescript-language-server" :class lang :why "JS/TS/TSX，以及 HTML 里的 <script>")
    (:bin "clangd" :class lang :why "C/C++")
    (:bin "pyright-langserver" :class lang :why "Python")
    (:bin "gopls" :class lang :why "Go")
    (:bin "rust-analyzer" :class lang :why "Rust")
    (:bin "cc" :class feature :why "treesit-install-language-grammar 编译 grammar")
    (:bin "fcitx5-remote" :class feature :os (gnu/linux darwin) :why "退出插入态切英文；C-SPC 开输入法")
    (:bin "im-select.exe" :class feature :os (windows-nt)
          :find iys/externals--im-select :why "退出插入态切英文（路径见 iys/im-select-path）")
    (:bin "pwsh" :class feature :os (windows-nt) :why "ghostel 默认 shell")
    (:bin "xdg-open" :class feature :os (gnu/linux) :why "dired 打开 pdf/图片/视频"))
  "本配置会调用的外部程序。

不在启动时检查。换机器或怀疑 PATH 时用 `iys/check-external-programs'。
改这个列表时同步 `docs/notes/external-programs.md`。")

(defun iys/externals--applies-p (entry)
  (let ((os (plist-get entry :os)))
    (or (null os) (memq system-type os))))

(defun iys/externals--resolve (entry)
  "返回找到的路径字符串，找不到返回 nil。"
  (let ((finder (plist-get entry :find)))
    (cond
     (finder (funcall finder))
     (t (executable-find (plist-get entry :bin))))))

(defun iys/externals--class-label (class)
  (pcase class
    ('core "核心")
    ('feature "功能")
    ('lang "语言")
    (_ (symbol-name class))))

(defun iys/check-external-programs (&optional missing-only)
  "检查 `iys/external-programs' 是否在 PATH（或自定路径）上。

不自动运行。前缀参数（C-u）只列出缺失项。"
  (interactive "P")
  (let* ((buf (get-buffer-create "*iys-external-programs*"))
         (applicable (cl-remove-if-not #'iys/externals--applies-p iys/external-programs))
         (rows (mapcar (lambda (e)
                         (cons e (iys/externals--resolve e)))
                       applicable))
         (missing (cl-count-if-not #'cdr rows)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "本机第三方程序  %s  缺失 %d / 适用 %d\n"
                        (symbol-name system-type) missing (length applicable)))
        (insert "不在启动时自动检查。C-u M-x iys/check-external-programs 只看缺失。\n\n")
        (dolist (class '(core feature lang))
          (let ((group (cl-remove-if-not
                        (lambda (row) (eq (plist-get (car row) :class) class))
                        rows)))
            (when group
              (insert (iys/externals--class-label class) "\n")
              (dolist (row group)
                (let* ((e (car row))
                       (path (cdr row))
                       (ok (and path t)))
                  (when (or (not missing-only) (not ok))
                    (insert (format "  %-3s %-32s %s\n        %s\n"
                                    (if ok "OK" "缺")
                                    (plist-get e :bin)
                                    (or path "")
                                    (plist-get e :why))))))
              (insert "\n"))))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buf)
    (message "外部程序：适用 %d，缺失 %d%s"
             (length applicable) missing
             (if missing-only "（只显示缺失）" ""))))

(provide 'init-externals)

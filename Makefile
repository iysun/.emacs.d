EMACS ?= emacs
ROOT := $(CURDIR)
DUMP := $(ROOT)/emacs.pdmp

.PHONY: all dump compile clean distclean

# 默认构建：生成自定义 portable dump（emacs.pdmp），用 --dump-file 启动可大幅加速。
all: dump

# 预加载重包并转储成 emacs.pdmp（脚本见 dump.el）。
# 启动：emacs --dump-file=$(DUMP)  或用 emacs-dump.cmd。
# 注意：装/删包或重编升级 emacs 后必须重跑 `make dump`，否则映像不兼容。
dump:
	@echo "Building portable dump -> emacs.pdmp ..."
	@$(EMACS) --batch -Q -l "$(ROOT)/dump.el"

# 字节编译作语法检查（非默认；产物 .elc 仅供检查，别留在工作区，见 /build）。
compile:
	@echo "Compiling Emacs Lisp files to .elc..."
	@$(EMACS) --batch -Q \
		--eval "(setq user-emacs-directory (file-name-as-directory \"$(ROOT)\"))" \
		--eval "(add-to-list 'load-path (expand-file-name \"lisp\" user-emacs-directory))" \
		--eval "(setq package-user-dir (expand-file-name \"elpa\" user-emacs-directory))" \
		--eval "(require 'package)" \
		--eval "(package-initialize)" \
		--eval "(byte-recompile-directory user-emacs-directory 0)" \
		--eval "(message \"Byte compilation finished\")"

# 清掉本仓库自己的 .elc（**不动** emacs.pdmp）。
# 这是高频操作：`make compile' 只用于语法检查，检查完必须清掉产物——交互会话
# load-prefer-newer 为 nil，残留旧 .elc 会悄悄盖过更新的 .el。
# 用 Emacs 自己删而不是 find/rm：GNU find 语法在 Windows 会命中 system32\find.exe
# 而静默失效（旧版 clean 就一直是坏的）。走 emacs --batch 三平台行为一致。
clean:
	@echo "Removing generated .elc ..."
	@$(EMACS) --batch --eval "(let ((root (file-name-as-directory \"$(ROOT)\")) (n 0)) (dolist (f (directory-files-recursively root \"[.]elc$$\" nil (lambda (d) (not (member (file-name-nondirectory d) '(\"elpa\" \".git\" \"eln-cache\" \"straight\")))))) (delete-file f) (setq n (1+ n))) (message \"Removed %d .elc file(s)\" n))"

# 连 emacs.pdmp 一起删。单独一个 target：pdmp 重建要几十秒，不该被高频的
# 「清 .elc」顺手毁掉。
distclean: clean
	@echo "Removing emacs.pdmp ..."
	@$(EMACS) --batch --eval "(let ((dump (expand-file-name \"emacs.pdmp\" (file-name-as-directory \"$(ROOT)\")))) (if (file-exists-p dump) (progn (delete-file dump) (message \"Removed emacs.pdmp\")) (message \"emacs.pdmp not present\")))"

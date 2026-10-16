"""HTML: rass 聚合 vscode-html + vscode-css + typescript-language-server。

Windows 下 rass 用 create_subprocess_exec，不解析 npm 的 .cmd/.ps1 壳，故经 cmd /c。
"""

import sys


def _cmd(*argv):
    return ["cmd", "/c", *argv] if sys.platform == "win32" else list(argv)


def servers():
    return [
        _cmd("vscode-html-language-server", "--stdio"),
        _cmd("vscode-css-language-server", "--stdio"),
        _cmd("typescript-language-server", "--stdio"),
    ]

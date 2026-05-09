#!/bin/bash
# Claude Desktop ローカルセットアップスクリプト
# 使い方: bash setup_local_claude.sh

set -e

echo "=== Claude Desktop ローカル環境セットアップ ==="

# --- 1. Claude Desktop がインストール済みか確認 ---
CLAUDE_APP="/Applications/Claude.app"
if [ ! -d "$CLAUDE_APP" ]; then
  echo ""
  echo "Claude Desktop が見つかりません。"
  echo "以下のURLからダウンロードしてインストールしてください:"
  echo "  https://claude.ai/download"
  echo ""
  echo "インストール後、このスクリプトを再実行してください。"
  exit 1
fi
echo "[OK] Claude Desktop が確認できました: $CLAUDE_APP"

# --- 2. Node.js / npx の確認（MCP サーバー用）---
if ! command -v npx &> /dev/null; then
  echo ""
  echo "npx が見つかりません。Node.js をインストールしてください:"
  echo "  https://nodejs.org/"
  echo ""
  exit 1
fi
echo "[OK] npx が利用可能です"

# --- 3. Python 仮想環境のセットアップ ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
  echo "Python 仮想環境を作成中..."
  python3 -m venv "$VENV_DIR"
fi

echo "依存パッケージをインストール中..."
"$VENV_DIR/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt"
echo "[OK] Python 環境セットアップ完了"

# --- 4. Claude Desktop の設定ファイルを配置 ---
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

mkdir -p "$CONFIG_DIR"

# プロジェクトの絶対パスを取得
ESTIMATE_APP_PATH="$SCRIPT_DIR"
KONKATSU_PATH="$(dirname "$SCRIPT_DIR")/konkatsu-blog-automation"

cat > "$CONFIG_FILE" <<EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$ESTIMATE_APP_PATH",
        "$KONKATSU_PATH"
      ]
    }
  }
}
EOF

echo "[OK] Claude Desktop 設定ファイルを配置しました:"
echo "     $CONFIG_FILE"

# --- 5. デスクトップにエイリアス（ショートカット）を作成 ---
DESKTOP="$HOME/Desktop"
ALIAS_PATH="$DESKTOP/Claude.app"

if [ ! -e "$ALIAS_PATH" ]; then
  osascript -e "
    tell application \"Finder\"
      make alias file to POSIX file \"$CLAUDE_APP\" at POSIX file \"$DESKTOP\"
    end tell
  " 2>/dev/null && echo "[OK] デスクトップに Claude のエイリアスを作成しました" \
                 || echo "[!] エイリアス作成をスキップ（既に存在するか権限エラー）"
else
  echo "[OK] デスクトップに Claude のエイリアスは既に存在します"
fi

# --- 6. Claude Desktop を起動 ---
echo ""
echo "Claude Desktop を起動します..."
open "$CLAUDE_APP"

echo ""
echo "=== セットアップ完了 ==="
echo "Claude Desktop が起動しました。"
echo "MCPサーバー（filesystem）経由でこのプロジェクトにアクセスできます。"

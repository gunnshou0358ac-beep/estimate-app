# estimate-app

見積書作成アプリ（Python / Flask）。OCRでPDFを読み込み、Claude APIを使って見積もりを自動生成する。

## ローカル起動手順

```bash
# 仮想環境を作成してパッケージをインストール
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# アプリを起動
python app.py
```

## Claude Desktop ローカルセットアップ

```bash
bash setup_local_claude.sh
```

このスクリプトは以下を自動で行う:
- Python 仮想環境の作成と依存パッケージのインストール
- `~/Library/Application Support/Claude/claude_desktop_config.json` の設定
- デスクトップへの Claude アイコン（エイリアス）の作成
- Claude Desktop の起動

設定ファイルのサンプルは `claude_desktop_config.json.example` を参照。

## ファイル構成

| ファイル | 説明 |
|---|---|
| `app.py` | Flask アプリ本体 |
| `index.html` | フロントエンド |
| `ocr_pdf.swift` | PDF OCR 処理（Swift） |
| `requirements.txt` | Python 依存パッケージ |
| `templates/` | HTML テンプレート |

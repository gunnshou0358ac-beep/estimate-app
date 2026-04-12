# 新商品発表会PDF → 見積書Excel 自動転記アプリ 構築プロンプト

## 前提ファイル（同フォルダに配置）
- `[新商品一覧PDF].pdf`  ← 商品データ源泉（スキャンPDFも対応）
- `[見積書テンプレート].xlsx`  ← 転記先テンプレート

---

## Phase 1: PDFから商品データを抽出する

対象PDFに含まれる商品一覧表から全商品を抽出してください。

### 抽出する列（7項目）
| PDF列名 | 抽出対象 |
|---------|---------|
| 商品名 | ✅ |
| 規格（入り数） | ✅ |
| 荷姿 | ✅ |
| 営業売（単価） | ✅ |
| JANコード | ✅（なければ空欄） |
| 賞味期限 | ✅ |
| 備考 | ✅ |

### PDF読み取り方針
- まず `pdfplumber` でテキスト抽出を試みる
- テキストが取れないページ（スキャン画像）は **macOSのVision OCR（Swift経由）** で対応する
- OCRは座標ベースで行を再構成し、列ヘッダーのx座標を基準にセルをマッピングする
- 列形式が2種類ある場合に対応すること：
  - **統合型**：商品コードと商品名が1セルに入っている（例：`548130（E）チャック...`）
  - **分離型**：商品コードと商品名が別列（商品コード列 + 商品名列）

---

## Phase 2: 見積書Excelへ転記する

### 列マッピングルール
| 見積書の列 | 転記するデータ |
|----------|--------------|
| 商品名 | PDFの「商品名」 |
| 規格 | PDFの「規格/入り数」 |
| 荷姿 | PDFの「荷姿」（"10 x 8"等は"10×8"に正規化） |
| 単位 | 固定値「＠」（全商品共通） |
| 単価 | PDFの「営業売」（数値型で入力・円記号除去） |
| 賞味期限 | PDFの「賞味期限」 |
| JANコード | PDFの「JANコード」（なければ空欄・文字列型） |
| 備考 | PDFの「備考」 |

### Sheetの扱い方
- 既存のSheet1のヘッダー行（書式・列幅・結合セル）を保持する
- 1Sheetに入る行数（通常10行）を超えた場合は **Sheet2, Sheet3...を自動追加**
- 追加SheetはSheet1を `copy_worksheet()` で複製し、データ行のみクリアして使う
- テンプレートの書式（フォント・罫線・背景色・結合セル）を崩さないこと

### ファイル出力
- 出力ファイル名: `見積書_完成版_YYYYMMDD.xlsx`（日付は実行日）

---

## Phase 3: Webアプリを作成する

### アプリ要件
- フロントエンド: HTML + JavaScript（単一ファイル・外部CDN不要）
- バックエンド: Python（Flask）
- ポート: **5001**（macOSはポート5000がAirPlayに占有されるため）

### 機能
1. PDFをドラッグ&ドロップ or ファイル選択でアップロード
2. アップロード後、自動でPhase1・Phase2を実行
3. 完成した見積書Excelをブラウザからダウンロード
4. 処理状況を表示（「PDF読み取り中...」→「転記中...」→「完了」）
5. エラー時は内容を画面に表示

### 使用ライブラリ
```
pdfplumber      # PDF読み取り（テキストPDF）
openpyxl        # Excel操作
flask           # Webサーバー
flask-cors      # CORS対応
```

### ファイル構成
```
estimate-app/
├── app.py              # Flaskサーバー + PDF・Excel処理ロジック
├── index.html          # フロントエンドUI
├── ocr_pdf.swift       # Swift製Vision OCRスクリプト
└── requirements.txt
```

テンプレートファイルは以下の優先順で自動検索すること：
1. `~/Desktop/[会社名フォルダ]/テンプレート/[テンプレートファイル名].xlsx`
2. `estimate-app/templates/[テンプレートファイル名].xlsx`（フォールバック）

---

## Swift OCRスクリプト（ocr_pdf.swift）の仕様

```
Usage: swift ocr_pdf.swift <pdf_path> <page_index>
Output: JSON配列 [{text, x, y, w, h}]  ※座標はVision正規化座標（0〜1）
```

- PDFページを200DPIで画像レンダリング
- `VNRecognizeTextRequest` で日本語・英語を認識（recognitionLevel: .accurate）
- 各認識結果のバウンディングボックス座標も返す

---

## OCRパース処理の重要ポイント

### 行再構成ロジック
```python
# Vision座標はy=0が下端のため降順ソート
items.sort(key=lambda x: -x['y'])
# y座標が0.018以内のアイテムを同一行とみなす
rows = group_by_y(items, threshold=0.018)
# 各行内はx座標で左→右にソート
rows = [sorted(row, key=lambda x: x['x']) for row in rows]
```

### 列マッピングロジック
- ヘッダー行の各セルのx座標を列の基準位置として記録
- データ行の各セルを「最も近い列ヘッダー」にマッピング

### 単価のクリーニング
```python
# "円"付き → "2,300円" → 2300
m = re.search(r'k?([\d,]+)円', text)
# カンマ区切り数値 → "2,300" → 2300（円なしでもOK）
m = re.search(r'\b(\d{1,3}(?:,\d{3})+)\b', text)
```

### 荷姿のクリーニング
```python
# "10 x 8" / "10X8" → "10×8"
re.sub(r'(\d+)\s*[xXｘ×]\s*(\d+)', r'\1×\2', text)
# 末尾に混入した価格を除去 → "12×4 270円" → "12×4"
re.sub(r'\s+k?[\d,]+円\s*$', '', text)
```

### スキップすべき行のパターン
```python
SKIP = ['工場出荷目標', '出荷目標', '諸条件', '改訂版', '【拡販商品】',
        '甲単位', '1/1', '07.04']
# 末尾が「N甲」の行もスキップ
re.search(r'[^\d]\d+甲$', combined)
```

---

## 実行手順
```bash
# 1. ライブラリインストール
pip install pdfplumber openpyxl flask flask-cors

# 2. アプリ起動
cd estimate-app
python3 app.py

# 3. ブラウザでアクセス
open http://localhost:5001
```

---

## 注意事項
- macOSのポート5000はAirPlay Receiverが占有するため **5001を使用**
- `render_template_from_string` はFlaskに存在しない → `render_template_string` または削除
- JANコードは文字列型（先頭ゼロ保持）で保存
- openpyxlで結合セルを扱う場合は **左上セルのみに書き込む**
- `copy_worksheet()` 後のシートでデータをクリアする際も左上セルのみ操作

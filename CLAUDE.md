# プロジェクトルール

## 見積書自動生成アプリ

新商品一覧表のPDFをアップロードすると、Excel見積書を自動生成するツール。

- `app.py` … Flask アプリ本体（PDF読み取り → 商品データ抽出 → Excel生成）
- `index.html` … アップロード用のフロントエンド画面
- `ocr_pdf.swift` … Swift/Vision によるスキャンPDFのOCR処理
- `templates/見積書サンプル.xlsx` … 出力Excelのテンプレート

### 起動方法

```
pip install -r requirements.txt
python app.py
```

`http://localhost:5001` で起動する。

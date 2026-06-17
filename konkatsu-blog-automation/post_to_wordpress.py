import os
import re
import glob
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

load_dotenv()

WP_URL  = os.getenv("WP_URL", "").rstrip("/")
WP_USER = os.getenv("WP_USER", "")
WP_PASS = os.getenv("WP_PASS", "")

def parse_md(filepath):
    with open(filepath, encoding="utf-8") as f:
        text = f.read()

    # フロントマターからtitleとdateを取得
    title = re.search(r'^title:\s*"?(.+?)"?\s*$', text, re.MULTILINE)
    date  = re.search(r'^date:\s*(\S+)',           text, re.MULTILINE)

    title = title.group(1).strip() if title else os.path.basename(filepath)
    date  = date.group(1).strip()  if date  else ""

    # フロントマター（---〜---）を除いた本文
    body = re.sub(r'^---[\s\S]+?---\s*', '', text).strip()

    return title, date, body

def post_draft(title, date, content):
    endpoint = f"{WP_URL}/wp-json/wp/v2/posts"
    payload = {
        "title":   title,
        "content": content,
        "status":  "draft",
        "date":    f"{date}T09:00:00",
    }
    resp = requests.post(
        endpoint,
        json=payload,
        auth=HTTPBasicAuth(WP_USER, WP_PASS),
        timeout=30,
    )
    return resp

def main():
    if not all([WP_URL, WP_USER, WP_PASS]):
        print("❌ .envにWP_URL / WP_USER / WP_PASSを設定してください")
        return

    md_files = sorted(glob.glob(os.path.join(os.path.dirname(__file__), "*.md")))
    if not md_files:
        print("❌ .mdファイルが見つかりません")
        return

    print(f"▶ {len(md_files)}本の記事をWordPressに下書き投稿します\n")

    for path in md_files:
        title, date, body = parse_md(path)
        print(f"  投稿中: {title} ({date}) ... ", end="", flush=True)
        resp = post_draft(title, date, body)
        if resp.status_code in (200, 201):
            post_id  = resp.json().get("id")
            edit_url = f"{WP_URL}/wp-admin/post.php?post={post_id}&action=edit"
            print(f"✅ 完了 → {edit_url}")
        else:
            print(f"❌ 失敗 [{resp.status_code}] {resp.text[:200]}")

if __name__ == "__main__":
    main()

# Learning Workspace ガジェット（配布用）

Learning Workspace を Windows のデスクトップに常駐させて操作するアプリのインストーラー置き場です（ソースコードは含みません）。

## インストール（おすすめ）

PowerShell を開いて、次の 1 行を貼り付けて Enter を押します。ブラウザを通さないので、「危険なファイル」の警告は出ません。

```powershell
irm https://raw.githubusercontent.com/oyuke/learning-workspace-gadget/540a160dde3027015f461ec08d6c88d8e49abfbe/install.ps1 | iex
```

最新版のダウンロード、署名とハッシュの検証、インストーラーの起動までを行います。URL の英数字40桁はこのリポジトリのコミットで、あとから中身を差し替えられません。リリースに付く `release-manifest.json` の署名と、EXE のハッシュ・サイズがすべて一致したときだけ起動し、過去の版への巻き戻しは拒否します。検証に失敗したときは、何もインストールしません。

## ブラウザからインストールする場合

[Releases](../../releases/latest) から `Learning-Workspace-Setup-x.y.z.exe` を取得して実行します。コード署名をしていないため、ブラウザや Windows が警告を出します。

- Chrome: ダウンロード欄の「⋮」→「保存」→「保存する」
- Windows の SmartScreen: 「詳細情報」→「実行」

## 使い方

起動するとログイン画面が出るので、Learning Workspace のアカウントでログインします。アクセス権（Cloudflare Access の許可）がないアカウントでは、中身は使えません。

- 画面右下の円にマウスを乗せると機能が展開し、クリックでカードが開きます。
- ショートカットキー（既定 Ctrl+Alt+Space）で表示・非表示。変更は「設定 → 環境設定」から。
- 新しい版は自動で見つかり、環境設定から再起動して更新できます。更新は、上の 1 行をもう一度実行しても行えます。

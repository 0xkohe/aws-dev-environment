# Contributing

小さな AWS 開発環境テンプレートとして維持します。変更の目的、利用例、検証結果を PR に記載してください。

```bash
terraform init -backend=false
terraform fmt -check
terraform validate
bash scripts/check.sh
```

バックエンドを使わない検証は新しい checkout で実施してください。実環境の `.terraform/` は流用しません。CI は AWS にログインせず、リソースを作成・変更しません。実環境の plan は管理者が別途確認します。

個人設定、state、plan、秘密鍵、認証トークン、会話ログをコミットしないでください。Git の差分に加え `git diff --cached` で公開対象を確認してください。

Terraform の resource 名やタグの変更は既存環境の再作成や操作対象の変更につながります。移行方法と plan の確認を含めてください。cloud-init の変更は既存 OS に自動適用されません。

コードは MIT License で提供します。インストールされる各ツールにはそれぞれのライセンス・利用条件が適用されます。

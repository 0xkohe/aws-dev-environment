# Security

秘密鍵・SSO トークン・Codex 認証情報・Terraform state・会話ログは公開しないでください。state や EBS snapshot も機密データとして扱います。

脆弱性は、公開先 GitHub リポジトリの Security → Report a vulnerability から非公開で報告してください。この窓口は管理者が公開前に Private vulnerability reporting を有効化して提供します。利用できない場合は、公開 Issue に詳細や秘密情報を載せず、管理者に非公開の連絡方法を確認してください。

対象は最新の main ブランチです。対応期限や稼働保証はありません。

EC2 は受信ルールなし、SSM 経由の SSH を使います。SSM 接続権限と SSH 鍵を持つ利用者、SSM Run Command 権限を持つ管理者はサーバーにアクセスできます。Docker グループの利用者は実質的に root 権限を持つため、信頼できる個人用環境を想定しています。SSM 経由の SSH 内容は Session Manager のセッションログ対象ではありません。

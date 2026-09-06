# ASOBI — AWS development environment

Codex CLI などの AI CLI を、SSH を切断しても動かせる個人用 AWS 開発環境です。Terraform で EC2 を構築し、VS Code Remote SSH と tmux で開発します。OpenAI・AWS の公式プロジェクトではありません。

## 構成

| 項目 | 内容 |
| --- | --- |
| EC2 | 既定は m7i.2xlarge（8 vCPU / 32GiB）、オンデマンド |
| OS | Canonical Ubuntu 24.04 LTS、x86_64、AMI を指定して固定 |
| ディスク | 暗号化 gp3 100GiB、終了時も保持 |
| 接続 | AWS SSO → Session Manager → SSH、受信ポートなし |
| 通信 | 既存の公開サブネット、自動割り当て公開 IPv4 |
| 管理 | Terraform、S3 state + versioning + lockfile |
| 稼働 | 手動起動・停止、自動停止なし |

Git、GitHub CLI、Docker Engine / Compose、Node.js、Python / uv、AWS CLI、Codex CLI、tmux、ビルドツールを導入します。Node.js `v24.20.0` と Codex CLI `0.153.4` は固定。他のパッケージは初回インストール時のリポジトリから取得するため、完全な再現ビルドではありません。導入バージョンは `/var/log/asobi-tool-versions.txt` に記録します。

対応範囲は商用 AWS リージョン、Ubuntu amd64、手元の Linux x86_64 + Bash です。macOS・Windows・ARM は自動セットアップの検証対象外です。SSM Agent を含む Canonical AMI と、IGW への公開ルート・DNS 解決・外向き通信を許可するネットワーク ACL が必要です。VPC とサブネットは作成・変更しません。

## 初回セットアップ

### 1. 手元の準備

Terraform `>=1.10,<2.0`、AWS CLI v2、jq、OpenSSH、curl、dpkg-deb を用意します。VS Code を使う場合は Remote - SSH 拡張機能も必要です。IAM Identity Center で対象アカウントへの権限を用意し、手元で実行します。

```bash
aws configure sso --profile my-dev
aws sso login --profile my-dev
aws sts get-caller-identity --profile my-dev
```

構築には EC2・IAM・S3 の管理権限が必要です。EC2 自身には SSM 用の権限のみを付与します。開発・デプロイに必要な AWS 権限は EC2 内で別途 SSO にログインして取得してください。

### 2. 個人設定を作る

clone したリポジトリで実行します。

```bash
cp config.example.json config.auto.tfvars.json
```

JSON を自分の環境に合わせて編集します。個人設定は Git 管理対象外です。認証情報は記入しません。

| 設定 | 内容 |
| --- | --- |
| `account_id`, `aws_profile`, `region` | 対象アカウント、手元の SSO プロファイル、リージョン |
| `name` | リソース名・タグ・SSH 接続名。例：`asobi-dev` |
| `vpc_id`, `subnet_id` | 同じ VPC 内の公開サブネット |
| `ami_id` | 選択リージョンの Canonical Ubuntu 24.04 amd64 AMI |
| `ssh_public_key_path` | 公開鍵の絶対パス、または `~/.ssh/asobi-dev.pub` |
| `state_bucket` | 新規の専用 S3 バケット名（世界で一意） |
| `state_key` | state 保存キー。例：`dev/terraform.tfstate` |
| `instance_type`, `root_volume_size` | 任意。既定は 8 vCPU / 32GiB、100GiB |

プロファイル名は英数字・ハイフン・アンダースコアを使います。SSH 自動設定は HOME と AWS CLI パスに空白・シェル特殊文字がない手元環境を対象にします。

AMI は EC2 コンソールで所有者が Canonical（`099720109477`）である Ubuntu Server 24.04 LTS x86_64 を確認します。AMI、インスタンスタイプ、サブネットは同じリージョンで利用できるものを指定してください。

既存の鍵を上書きせず、専用鍵を作ります。以下は `name=asobi-dev` の例です。

```bash
ssh-keygen -t ed25519 -f ~/.ssh/asobi-dev -C asobi-dev
```

秘密鍵は手元だけに保持します。パスフレーズを付けた場合は `ssh-add ~/.ssh/asobi-dev` で ssh-agent に追加します。

### 3. 構築する

```bash
./scripts/bootstrap-state.sh
./scripts/init.sh
terraform validate
terraform plan -out=asobi.tfplan
# 作成対象・料金を確認してから適用
terraform apply asobi.tfplan
./scripts/asobi start
./scripts/setup-local.sh
```

専用 state バケットは暗号化・バージョニング・公開アクセス禁止・TLS 強制を設定します。bootstrap は既存バケットにもこれらを適用するため、他用途のバケットを指定しないでください。S3 Object Lock ではなく Terraform の S3 lockfile を使います。

`init.sh` は個人設定から管理外の `backend.local.json` を作ります。backend を使うときは `terraform init` の代わりにこのスクリプトを使います。Terraform の `-var` や `TF_VAR_*` で運用値を上書きせず、JSON を更新してください。既存のバケット・キーを変更すると別の state を参照するので、日常操作では変更しません。

`setup-local.sh` は手元の Session Manager plugin と `~/.ssh/config.d/NAME.conf` を設定します。既存 SSH 設定はバックアップします。

### 4. 接続確認

初回のホスト鍵は SSM Run Command から確認します。`terraform output -raw instance_id` の ID を使い、AWS コンソールの Systems Manager → Run Command → `AWS-RunShellScript` で次を実行します。

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

手元の `ssh asobi-dev` に表示される fingerprint と一致することを確認します。登録済みの鍵が変わったら原因を確認せず削除しないでください。

```bash
ssh asobi-dev
cloud-init status --wait
test -f /var/lib/asobi-bootstrap-complete
cat /var/log/asobi-tool-versions.txt
docker run --rm hello-world
```

手元の `terraform plan` で差分なしを確認します。`start` は EC2 と SSM の準備を待ちますが、全ツールの初回インストール完了までは保証しません。

## 起動・停止

手元でリポジトリのディレクトリから実行します。

```bash
aws sso login --profile my-dev  # 認証期限切れ時
./scripts/asobi start
./scripts/asobi status
ssh asobi-dev
```

終了時は未保存データと実行中の処理を確認して、手元で停止します。

```bash
./scripts/asobi stop
```

`name` を変えた場合は SSH 接続名も変わります。`./scripts/asobi ssh` でも接続できます。停止後も保存済みファイルは残ります。`terraform destroy` は停止用コマンドではありません。

## SSH を閉じても Codex を動かす

EC2 で本人のアカウントにログインします。

```bash
codex login --device-auth
codex login status
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
cd ~/projects
gh repo clone OWNER/REPOSITORY
```

tmux を開始し、その中で Codex を起動します。

```bash
tmux new -As dev
cd ~/projects/REPOSITORY
codex
```

`Ctrl-b` を押して離し、`d` を押すと切り離せます。その後 `exit` で SSH を閉じて構いません。切り離し操作をせずにターミナルを閉じたり、手元 PC の電源を切ったりしても、EC2 が稼働していれば tmux 内の処理は続きます。戻るときは、手元から SSH で接続し、接続先で同じセッションに入ります。

```bash
ssh asobi-dev
tmux attach -t dev
```

SSH がまだつながっている場合は、接続先で `tmux attach -t dev` だけ実行します。`attach` は既存のセッションに戻るコマンドです。`tmux new -As dev` は、`dev` があれば戻り、なければ新しく作成します。

### Ghostty で端末エラーが出る場合

`missing or unsuitable terminal: xterm-ghostty` と表示されたら、接続先に Ghostty の端末情報がありません。接続先で次のように起動できます。

```bash
TERM=xterm-256color tmux new -As dev
```

`TERM=...` は、このコマンドに限って一般的な256色対応端末として扱う指定です。設定ファイルは変更しません。SSH を閉じた後の再接続も同じ指定を使います。

```bash
ssh asobi-dev
TERM=xterm-256color tmux attach -t dev
```

Ghostty の端末情報を登録して通常のコマンドを使えるようにするには、**手元 PC の Ghostty の別ターミナル**で次を実行します（手元に `infocmp`、接続先に `tic` が必要です）。

```bash
infocmp -x xterm-ghostty | ssh asobi-dev 'tic -x -'
```

これは端末の色やキー入力などの情報を接続先ユーザーの terminfo に登録します。登録後は `tmux new -As dev` や `tmux attach -t dev` をそのまま使えます。

### tmux 内でスクロールする

`Ctrl-b` を押して離し、`[` を押すとコピーモードに入ります。矢印キーや `Page Up` / `Page Down` で履歴をスクロールし、`q` で通常の操作に戻ります（標準設定）。

マウスやトラックパッドでスクロールするには、接続先の tmux 内のシェルで実行します。

```bash
TERM=xterm-256color tmux set -g mouse on
```

今動いている tmux に反映されます。tmux サーバーの再起動後も有効にするには、接続先の `~/.tmux.conf` に `set -g mouse on` を追記します。既存の設定を残し、同じ行の重複を避けるには次を実行します。

```bash
touch ~/.tmux.conf
grep -Fxq 'set -g mouse on' ~/.tmux.conf || printf '\nset -g mouse on\n' >> ~/.tmux.conf
TERM=xterm-256color tmux source-file ~/.tmux.conf
```

`source-file` は起動中の tmux に設定を読み直させます。tmux が起動していない場合は、次回起動時に自動で読み込まれるため実行不要です。Ghostty の端末情報を登録済みなら、`TERM=xterm-256color` は省略できます。

### 接続・停止と処理の関係

| 操作・状態 | 処理の状態 |
| --- | --- |
| tmux 内で起動して SSH を切断 | 継続 |
| 手元 PC の電源を切る | EC2 の tmux 内では継続 |
| tmux を使わず通常の SSH 内で起動 | 切断で終了する可能性あり |
| EC2 の停止・再起動 | 終了。保存済みファイルは保持 |
| Codex が承認・質問・認証待ち | 入力するまで作業は進まない |

tmux はネットワークエラー・利用制限からの自動復旧や、EC2 再起動後の処理再開を保証しません。承認を無効化する設定は加えません。

Device code 認証は ChatGPT の個人・ワークスペース設定で許可されている必要があります。使えない場合は手元で `ssh -L 1455:localhost:1455 asobi-dev`、接続先で `codex login` を実行し、表示 URL を手元で開きます。[OpenAI の認証手順](https://learn.chatgpt.com/docs/auth)

## VS Code・ポート転送・Bash

VS Code の `Remote-SSH: Connect to Host...` で `asobi-dev` を選び、`/home/ubuntu/projects` を開きます。Web アプリは localhost に bind し、Ports タブで転送します。SSH の場合は手元で実行します。

```bash
ssh -L 127.0.0.1:3000:localhost:3000 asobi-dev
```

任意の Bash 設定は Git ブランチ表示、履歴5万件と端末間共有、入力後の↑↓履歴検索、大小文字を区別しない補完を追加します。独自の短縮 alias は追加しません。

```bash
scp shell/asobi.bash scripts/setup-shell.sh asobi-dev:/home/ubuntu/
ssh asobi-dev 'bash ~/setup-shell.sh ~/asobi.bash'
```

反映後は SSH に入り直します。既存セッションの alias は設定の削除だけでは消えません。Ubuntu 標準の alias は変更しません。バックアップは `~/.config/asobi/backup.*` に保存します。無効化は `~/.bashrc` 末尾の ASOBI 用 source 行を削除して再接続します。

## 費用・保護・バックアップ

EC2 稼働時間、公開 IPv4、EBS、S3、通信、スナップショット等に課金されます。Codex / ChatGPT の料金は別です。自動停止はありません。SSH の切断では課金は止まらず、EC2 停止後も EBS・バックアップ・S3 の保存料金は続きます。[EC2 料金](https://aws.amazon.com/ec2/pricing/on-demand/)、[VPC 料金](https://aws.amazon.com/vpc/pricing/)、[EBS 料金](https://aws.amazon.com/ebs/pricing/)

EC2 終了保護、Terraform `prevent_destroy`、root volume の `delete_on_termination=false` を設定しています。リソース定義そのものを消すと `prevent_destroy` は機能しません。保護設定はバックアップの代わりではありません。

バックアップは手動です。保存して停止し、手元で実行します。

```bash
./scripts/asobi stop
./scripts/asobi snapshot
aws ec2 wait snapshot-completed --profile my-dev --region ap-northeast-1 --snapshot-ids SNAPSHOT_ID
./scripts/asobi start
```

snapshot の自動削除はありません。認証キャッシュも含むため非公開で扱います。復元手順：

1. snapshot が completed であることを確認し、EC2 を停止する。
2. 元の root volume ID・device 名・AZ を記録し、同じ AZ に snapshot から暗号化 gp3 volume を作る。
3. 元の root volume を detach し、復元した volume を同じ device（この Ubuntu 構成では `/dev/sda1`）に attach する。元の volume は保持する。
4. `DeleteOnTermination=false`、容量・IOPS・throughput・タグを元に合わせ、起動して SSH とデータを確認する。
5. `terraform plan -refresh-only` で確認し、`terraform apply -refresh-only` で state に反映する。通常の plan も確認する。

失敗時は停止して元の volume に戻します。確認完了まで元の volume と snapshot は削除しません。cloud-init の変更は既存 OS に自動適用されません。AMI 変更や OS 更新はバックアップ・復元を含めて行います。

## 検証・公開

初期の東京環境では SSH、Docker、GitHub 通信、ポート転送、tmux、停止・起動後のファイル保持を確認しています。他のリージョン・新規アカウントでの構築、バックアップ復元の実行、Codex の本人認証後の応答は検証範囲外です。

CI は AWS 認証なしで Terraform の整形・検証、シェル静的チェック、操作ガードのモックテストを実行します。ローカルでは `bash scripts/check.sh`。詳細は [CONTRIBUTING.md](CONTRIBUTING.md)。

個人設定、state、plan、鍵、会話ログは Git 対象外です。`.gitignore` は過去のコミットには作用しません。公開前に全履歴も確認してください。個人用の過去コミットを公開したくない場合は、元リポジトリを保持し、`git archive HEAD` で現在の公開対象のみを取り出して新規リポジトリにします。

ライセンスは [MIT](LICENSE)。セキュリティ報告は [SECURITY.md](SECURITY.md)。公開時に GitHub の Private vulnerability reporting を有効化してください。

参考: [SSH over SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)、[Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)

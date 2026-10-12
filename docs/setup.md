# セットアップ手順

GCP の土台（`infra/bootstrap`）を手元から作成し、GitHub 側を設定するまでの手順と、検証を終えるときの後片付けの手順（6 章）。

所要時間の目安: 30〜60 分

## 0. 事前準備

### 必要なもの

| もの | 確認方法 |
| --- | --- |
| Google Cloud SDK（`gcloud`） | `gcloud version` |
| Terraform 1.16 系 | `terraform version` |
| GitHub CLI（`gh`、任意。Variables の登録に使う） | `gh --version` |
| 課金アカウント ID（`XXXXXX-XXXXXX-XXXXXX`） | [お支払い](https://console.cloud.google.com/billing) の「請求先アカウント ID」 |

### 確認しておくこと

- 課金アカウントに **プロジェクトを 3 つ** リンクできる空きがあること。個人の課金アカウントは上限が小さい場合があり、上限に達していると apply が途中で失敗する。
- [Firebase コンソール](https://console.firebase.google.com/) を一度開いて、利用規約に同意していること。

### ログイン

```sh
gcloud auth login                       # gcloud コマンド用
gcloud auth application-default login   # Terraform 用（ADC）
```

## 1. bootstrap の初回 apply

作業ディレクトリは `infra/bootstrap`。

```sh
cd infra/bootstrap

# 変数ファイルを作り、billing_account_id を書き換える（Git 管理外）
cp terraform.tfvars.example terraform.tfvars

# 初回だけ state をローカルに置く（state バケットがまだないため）
cp backend_override.tf.example backend_override.tf

terraform init
```

### 1-1. プロジェクトだけを先に作る

ADC（ユーザー認証）で API を有効化するには「クォータプロジェクト」の設定が必要。その対象にする admin プロジェクトがまだないので、先にプロジェクトだけを作る。

```sh
terraform apply -target='google_project.this'
```

3 つのプロジェクト（`fhcl-admin-xxxx` / `fhcl-stg-xxxx` / `fhcl-prod-xxxx`）が作成されることを確認して `yes`。

### 1-2. admin プロジェクトをクォータプロジェクトにする

```sh
ADMIN_PROJECT=$(echo 'google_project.this["admin"].project_id' | terraform console | tr -d '"')
echo "$ADMIN_PROJECT"

# クォータプロジェクトとして使うために必要な API を有効にする（すでに有効なら何もしない）
gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com --project="$ADMIN_PROJECT"

gcloud auth application-default set-quota-project "$ADMIN_PROJECT"
```

### 1-3. 残りを作る

```sh
terraform apply
```

API の有効化、state バケット、Workload Identity Pool、Terraform 用 SA と権限が作成される（全部で約 40 リソース）。

## 2. state を GCS バケットへ移す

```sh
# backend_override.tf を消す前にバケット名を控える
BUCKET=$(terraform output -raw tfstate_bucket)
echo "bucket = \"$BUCKET\"" > backend.tfbackend   # Git 管理外。2 回目以降の init で使う

rm backend_override.tf
terraform init -migrate-state -backend-config=backend.tfbackend
```

「Do you want to copy existing state to the new backend?」に `yes`。移行後、次のコマンドで差分が出ないことを確認する。

```sh
terraform plan   # No changes. となれば OK
```

確認できたら、ローカルの state を削除する（課金アカウント ID などを含むため残さない）。

```sh
rm terraform.tfstate terraform.tfstate.backup
```

## 3. GitHub の設定

ここまでで GCP 側の準備はできた。この章では GitHub 側に、次の 3 つを設定する。

| 設定 | ひとことで言うと |
| --- | --- |
| Environments | デプロイ先ごとの「関所」。どのブランチから実行できるか、誰の承認が必要かを決める |
| Variables | ワークフローが読む設定値（GCP のプロジェクト ID など）。コードに直接書かずにここに置く |
| ルールセット | `main` ブランチとリリース用タグを、うっかり壊されないように守るルール |

### 3-1. Environments

**何をしているか**: GitHub Actions のジョブは `environment: prod` のように Environment を指定して動く。Environment ごとに「このブランチ（タグ）からしか実行できない」「誰かが承認するまで待つ」という条件を付けられる。GCP 側も、どの Environment のジョブかを見て使えるサービスアカウントを決めている（例: prod へデプロイする SA は Environment `prod` のジョブしか使えない）。そのため、ここで作る名前は GCP 側の設定と一致している必要がある。

| Environment | 使い道 |
| --- | --- |
| `stg` | stg へのページのデプロイ（`main` へのマージで自動実行） |
| `prod` | prod へのページのデプロイ（タグの push で実行。承認が必要） |
| `infra-stg` | stg のインフラ（Terraform）の変更 |
| `infra-prod` | prod のインフラ（Terraform）の変更（承認が必要） |

リポジトリの **Settings → Environments → New environment** で 4 つ作る。

| 名前 | Required reviewers | Deployment branches and tags |
| --- | --- | --- |
| `stg` | なし | Selected branches and tags: ブランチ `main` |
| `prod` | 自分（`tsatolol`）。「Prevent self-review」はオフ | Selected branches and tags: タグ `v*`、ブランチ `main` |
| `infra-stg` | なし | Selected branches and tags: ブランチ `main` |
| `infra-prod` | 自分（`tsatolol`）。「Prevent self-review」はオフ | Selected branches and tags: ブランチ `main` |

- **Required reviewers**: 指定した人が画面で「Approve」を押すまで、ジョブが待機する。prod 系だけに付けて、本番への反映前に人の確認を挟む。
- **Prevent self-review**: オンにすると「自分で起動したジョブを自分で承認できない」。承認できる人が自分しかいないので、オフにしておく。
- **Deployment branches and tags**: ここに挙げたブランチ・タグ以外から起動したジョブは、この Environment を使えない（たとえば作業ブランチから prod にデプロイすることはできない）。

### 3-2. Variables

**何をしているか**: ワークフローが GCP にアクセスするときに必要な値（プロジェクト ID、使うサービスアカウント、state を置くバケット名など）を登録する。どれも bootstrap が作ったもので、パスワードのような秘密の値ではない。リポジトリ全体で共通の値は「Repository」、環境ごとに違う値は各「Environment」に登録する。同じ名前（例: `GCP_PROJECT_ID`）でも、どの Environment のジョブかによって違う値が読まれる。

`infra/bootstrap` で次を実行すると、登録用の `gh` コマンドが表示される。

```sh
terraform output -raw github_variables_commands
```

リポジトリのルートで、表示されたコマンドをそのまま実行する（`gh auth login` 済みであること）。`gh` を使わない場合は、**Settings → Secrets and variables → Actions → Variables** で同じ名前と値を登録する。

| スコープ | 変数 |
| --- | --- |
| Repository | `GCP_WIF_PROVIDER`, `TF_STATE_BUCKET`, `TF_PLAN_SA`, `STG_PROJECT_ID`, `PROD_PROJECT_ID` |
| Environment `stg` / `prod` | `GCP_PROJECT_ID`（`DEPLOY_SA` はフェーズ 4 の apply 後に追加する。手順 4） |
| Environment `infra-stg` / `infra-prod` | `GCP_PROJECT_ID`, `TF_APPLY_SA` |

> Secrets は使わない（Workload Identity 連携のため不要）。GitHub Actions は実行のたびに GitHub が発行する一時的な証明書で GCP にログインするので、パスワードや鍵を保存しておく必要がない。

### 3-3. ルールセット

**何をしているか**: `main` ブランチは stg に自動でデプロイされ、`v*` タグは prod へのデプロイのきっかけになる。どちらも誤って変更されると困るので、ルールで守る。

- `main`: 直接 push できなくし、必ず PR を通す。さらに、CI（`ci` チェック）が成功していないとマージできないようにする。
- `v*` タグ: リリースの印なので、管理者（自分）以外は作成・変更・削除できないようにする。

**Settings → Rules → Rulesets → New ruleset** で 2 つ作る。

1. ブランチ用（New branch ruleset）
   - Name: `main`、Enforcement status: Active
   - Target branches: Include default branch（**これだけにする**。「All branches」などを足すと、作業ブランチにも PR 必須がかかり、PR の元になるブランチへ push できなくなる）
   - Rules:
     - Restrict deletions
     - Block force pushes
     - Require a pull request before merging（Required approvals: 0）
     - Require status checks to pass: `ci` を追加
2. タグ用（New tag ruleset）
   - Name: `release-tags`、Enforcement status: Active
   - Bypass list: Repository admin
   - Target tags: Include by pattern `v*`
   - Rules: Restrict creations、Restrict updates、Restrict deletions

## 4. デプロイ用 SA の登録（フェーズ 4 の apply 後）

`terraform.yml` の apply が成功すると、ジョブのサマリー（Actions の実行画面の Summary）に `deployer_service_account` が表示される。これを各 Environment の `DEPLOY_SA` に登録する。

```sh
gh variable set DEPLOY_SA --env stg --body 'deployer@fhcl-stg-xxxx.iam.gserviceaccount.com'
gh variable set DEPLOY_SA --env prod --body 'deployer@fhcl-prod-xxxx.iam.gserviceaccount.com'
```

## 5. 2 回目以降に bootstrap を変更するとき

```sh
cd infra/bootstrap
terraform init -backend-config=backend.tfbackend   # backend.tfbackend がなければ手順 2 と同じ内容で作る
terraform plan
terraform apply
```

`infra/bootstrap` は CI からは実行しない（ローカルでのみ apply する）。

## 6. 後片付け（検証を終えるとき）

GCP のプロジェクトを削除すると、その中のもの（Firebase Hosting、サービスアカウント、Workload Identity Pool、state バケット）はまとめて消える。Terraform の `destroy` は使わない（プロジェクトや prod の Hosting サイトに削除保護が付いているうえ、bootstrap の state 自体が削除対象のバケットにあるため）。

### 6-1. GCP のプロジェクトを削除する

```sh
gcloud auth login

# 3 つのプロジェクトを削除する（ID は環境に合わせる）
gcloud projects delete fhcl-stg-xxxx
gcloud projects delete fhcl-prod-xxxx
gcloud projects delete fhcl-admin-xxxx
```

- 削除したプロジェクトは課金が止まり、30 日後に完全に消える。それまでは `gcloud projects undelete <ID>` で元に戻せる。
- 同じプロジェクト ID は二度と使えない。もう一度セットアップするときは、bootstrap が別のサフィックスで作り直す（手元の `terraform.tfstate` や `backend.tfbackend` は削除しておく）。

### 6-2. GitHub 側の設定を消す（任意）

リポジトリを残す場合でも、GCP がなくなるとデプロイ系のワークフローは失敗するようになる。必要に応じて次を消す。

| 対象 | 場所 |
| --- | --- |
| Environments（`stg` / `prod` / `infra-stg` / `infra-prod`） | Settings → Environments |
| Variables（Repository の 5 つ） | Settings → Secrets and variables → Actions → Variables |
| ルールセット（`main` / `release-tags`） | Settings → Rules → Rulesets |
| タグ（`v1.0.0` など） | `git push origin :refs/tags/v1.0.0`（`release-tags` のルールセットを消すか、管理者として実行する） |

ワークフローだけ止めたい場合は、Actions の画面で各ワークフローを **Disable workflow** にする。

### 6-3. 手元の後片付け

```sh
cd infra/bootstrap
rm -rf .terraform terraform.tfvars backend.tfbackend
gcloud auth application-default revoke   # Terraform 用の ADC を削除する
```

## トラブルシューティング

| 症状 | 原因と対処 |
| --- | --- |
| `The serviceusage.googleapis.com API requires a quota project` | 手順 1-2 のクォータプロジェクト設定がされていない。1-2 を実行してから再度 `terraform apply` |
| `Cloud billing quota exceeded` / 課金アカウントにリンクできない | 課金アカウントのプロジェクト数の上限。不要なプロジェクトのリンクを外すか、上限の引き上げを申請する |
| プロジェクト ID やバケット名が既に使われている | まれにサフィックスが他と衝突する。プロジェクトがまだ 1 つも作成されていなければ、`terraform apply -replace='random_id.suffix' -target='google_project.this'` で別のサフィックスにする。作成済みのプロジェクトがある場合は削除保護（`deletion_policy = "PREVENT"`）で止まるので、状況を確認してから対処する |
| Workload Identity Pool `github` が作れない（already exists） | 削除したプールは 30 日間同じ ID を使えない。削除前のプールを復元するか、ID を変える |
| `terraform init` で backend の初期化を求められる | `-backend-config=backend.tfbackend` を付けて init する |
| GitHub Actions で `Permission 'iam.serviceAccounts.getAccessToken' denied` | OIDC トークンの `sub` と SA の WIF 紐付けが一致していない。ワークフローの「Show OIDC token claims」ステップに出る `sub` と、`terraform output` などで分かる principal を比べる。リポジトリやオーナーの ID が変わった場合は `github_repository_id` / `github_repository_owner_id` を直して bootstrap を apply し直す。紐付けの直後は反映まで数分かかることもある |

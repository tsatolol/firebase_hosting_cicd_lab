# CLAUDE.md

Firebase Hosting と GitHub Actions で、単一の HTML ページを stg / prod にデプロイするパイプラインの検証用リポジトリ。インフラは Terraform で管理する。

設計の詳細と決定の理由は `docs/spec.md` にある。仕様に関わる変更をするときは先に読み、決定事項が変わったら spec.md も更新すること。

その他のドキュメント: `README.md`（概要と使い方）、`docs/setup.md`（セットアップと後片付け）、`docs/verification.md`（動作確認の結果と分かったこと）、`TODO.md`（実行計画と進捗）。

## 構成

- `src/index.html` — 配信するページ。CSS/JS はこのファイルに内包する（外部ファイルに分けない）
- `scripts/build.sh` — `src/` を `dist/` にコピーし、`__APP_ENV__` などのプレースホルダーを置換する
- `scripts/smoke-test.sh` — デプロイ後の URL の HTTP 200 と `data-commit` の一致を確認する
- `scripts/show-oidc-claims.sh` — GitHub Actions の OIDC トークンのクレーム（`sub` など）を表示する（WIF のデバッグ用）
- `tests/` — Vitest + jsdom による単体テスト（`index.test.js`: ページ、`scripts.test.js`: build / smoke-test スクリプト）
- `infra/bootstrap/` — プロジェクト・state バケット・WIF・Terraform 用 SA。**ローカルでのみ apply する**
- `infra/modules/hosting-env/`, `infra/envs/{stg,prod}/` — Firebase / Hosting サイト / デプロイ用 SA。GitHub Actions で apply する
- `.github/workflows/` — `ci`, `preview`, `deploy-stg`, `deploy-prod`, `terraform`
- `.github/actions/deploy/` — ビルド → WIF 認証 → Firebase Hosting へのデプロイ → スモークテストをまとめた composite action（preview / stg / prod で共通）

## コマンド

```sh
npm ci
npm run lint     # HTMLHint / Stylelint(postcss-html) / ESLint(eslint-plugin-html)
npm test         # Vitest
npm run build    # dist/index.html を生成（APP_ENV などの環境変数で値を指定。省略時は local 用）
```

Terraform（envs）は CI で実行する。ローカルで確認するときは `terraform fmt -check -recursive infra` と `terraform -chdir=<dir> init -backend=false && terraform -chdir=<dir> validate` まで（CI の `ci` ジョブでも同じことをする）。`infra/bootstrap` の apply 手順は `docs/setup.md`。

## 環境とトリガー

| 環境 | GCP プロジェクト | トリガー |
| --- | --- | --- |
| preview | `fhcl-stg-xxxx` のチャネル `pr-<番号>` | 同一リポジトリからの PR |
| stg | `fhcl-stg-xxxx` | `main` への push |
| prod | `fhcl-prod-xxxx` | `v*.*.*` タグ push ＋ 承認。ロールバックは `workflow_dispatch` で旧タグを指定 |

Claude Code（Web 版）の環境からは作業ブランチ以外に push できないため、タグの push と承認は人が行う。Claude はワークフローの手動実行（ロールバック）と結果の確認までを行える。

## ルール

### セキュリティ

- サービスアカウントキーを作成・使用しない。GCP への認証は Workload Identity 連携（`google-github-actions/auth`）のみで行う。
- 課金アカウント ID、`*.tfvars`、`*.tfstate` をコミットしない（`terraform.tfvars.example` のみコミットする）。
- WIF の紐付けは OIDC の `sub`（`environment:<名前>` / `pull_request`）単位で行い、リポジトリ全体には許可しない。`sub` はオーナー・リポジトリに数値 ID が付いた形式（`repo:tsatolol@30972312/firebase_hosting_cicd_lab@1415534725:pull_request`）なので、principal はこの形式で組み立てる。

### GitHub Actions

- 外部アクションはコミット SHA で固定する（コメントにバージョンを書く）。
- `permissions` は最小限にし、`id-token: write` は OIDC を使うジョブにだけ付ける。
- デプロイは `firebase-tools`（devDependencies でバージョン固定）を直接使う。`FirebaseExtended/action-hosting-deploy` は使わない。
- fork からの PR では、OIDC を使うジョブ（プレビュー、terraform plan）をスキップする。
- `infra/bootstrap` を CI から実行しない。

### コンテンツ

- JS のロジックは純粋関数にして `window.App` に公開し、テストから呼べるようにする。
- デプロイ情報は `<body>` の `data-env` / `data-version` / `data-commit` / `data-deployed-at` に埋め込む。
- ビルド後にプレースホルダーが残っていたらビルドを失敗させる。

### Terraform

- プロバイダのバージョンを固定し、`.terraform.lock.hcl` をコミットする。ロックファイルには全プラットフォームのハッシュ（`zh:`）を含める（Mac / Windows でも init できるように）。
- state は GCS バケット `fhcl-tfstate-xxxx`（prefix: `bootstrap/`, `envs/stg/`, `envs/prod/`）。
- プロジェクトには `deletion_policy = "PREVENT"` を付ける。

## 書き方

- ドキュメント（`docs/`、README）は日本語で書く。
- コミットメッセージは Conventional Commits 形式（`feat:`, `fix:`, `docs:`, `ci:`, `infra:` など）。

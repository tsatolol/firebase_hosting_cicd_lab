# 実行計画（TODO）

`docs/spec.md` を実装し、動作確認するまでの計画。フェーズごとに 1 つの PR にまとめ、`main` へマージしてから次に進む。

- 担当: 🤖 = Claude（コードを書いて PR を作る）、👤 = あなた（GCP / GitHub の画面操作やローカルでの apply）
- 前のフェーズの完了条件を満たしてから次へ進む。

## 全体の流れ

| # | フェーズ | 主な担当 | GCP が必要か |
| --- | --- | --- | --- |
| 0 | 準備（`main` の作成、未決事項の決定） | 👤 | 不要 |
| 1 | ページ・lint・テスト・ビルドと `ci.yml` | 🤖 | 不要 |
| 2 | Terraform bootstrap のコード作成 | 🤖 | 不要 |
| 3 | bootstrap の apply と GitHub の設定 | 👤 | 必要 |
| 4 | Terraform envs と `terraform.yml` | 🤖 → 👤 承認 | 必要 |
| 5 | デプロイ用ワークフロー（preview / stg / prod） | 🤖 → 👤 承認 | 必要 |
| 6 | 動作確認シナリオの実施 | 👤 ＋ 🤖 | 必要 |
| 7 | 仕上げ（ドキュメント整備、後片付け手順） | 🤖 | 不要 |

フェーズ 1 と 2 は GCP がなくても進められるため、並行して作業できる。

---

## フェーズ 0: 準備

- [ ] 👤 仕様書（`docs/spec.md`）と `CLAUDE.md` の内容を確認する
- [x] 👤 `docs/spec.md` §12 の未決事項を決める
  - [x] プレビューチャネルの有効期限 → 7 日
  - [x] デプロイ失敗時の通知方法 → GitHub の標準通知のみ
  - [x] prod デプロイ後に GitHub Release を自動作成するか → 作成しない
  - [x] Terraform 用 SA の権限を owner から絞り込むか → owner のまま
- [x] 🤖 決定内容を `docs/spec.md` に反映する
- [x] 👤 `main` ブランチを作る
- [ ] 👤 GCP の課金アカウントに、プロジェクトを 3 つリンクできる空きがあるか確認する
- [ ] 👤 Firebase コンソールを一度開き、利用規約に同意しておく

**完了条件**: `main` に仕様書が入っていて、未決事項が決まっている。

---

## フェーズ 1: ページ・lint・テスト・ビルド（PR #1）

- [x] 🤖 `package.json`（scripts: `lint`, `test`, `build`）、`.nvmrc`、`.gitignore`（`node_modules/`, `dist/`, `*.tfstate*`, `*.tfvars`, `.terraform/`）
- [x] 🤖 `src/index.html`
  - [x] `<body data-env data-version data-commit data-deployed-at>` にプレースホルダーを置く
  - [x] 環境バッジ（色分け）、バージョン、コミットへのリンク、デプロイ日時（ローカル時刻＋「◯分前」）
  - [x] 「デプロイ情報をコピー」ボタン
  - [x] ロジックを `window.App` に公開（`formatRelativeTime`, `envTheme`, `buildDeployInfo` など）
- [x] 🤖 lint の設定: `.htmlhintrc`、`.stylelintrc.json`（postcss-html）、`eslint.config.js`（eslint-plugin-html）
- [x] 🤖 `tests/index.test.js`（Vitest ＋ jsdom）
  - [x] 純粋関数の単体テスト
  - [x] 初期化後の DOM（バッジ・表示値）の検証
- [x] 🤖 `scripts/build.sh`: 環境変数から値を受け取って置換し、プレースホルダーが残っていたら失敗する
- [x] 🤖 `scripts/smoke-test.sh`: URL と期待する SHA を受け取り、リトライ付きで HTTP 200 と `data-commit` を確認する
- [x] 🤖 `firebase.json`（`public: dist`、`index.html` に `Cache-Control: no-cache`）
- [x] 🤖 `.github/workflows/ci.yml`（lint / test / build。アクションは SHA で固定）
- [x] 🤖 ローカルで `npm run lint && npm test && npm run build` が通ることを確認する
- [x] 👤 PR をレビューしてマージする

**完了条件**: PR 上で `ci` が成功し、`main` にマージされている。

---

## フェーズ 2: Terraform bootstrap のコード（PR #2）

- [x] 🤖 `infra/bootstrap/`
  - [x] `versions.tf`（Terraform・google・random のバージョン固定。google-beta はフェーズ 4 の envs で使う）
  - [x] `random_id` とプロジェクト 3 つ（admin / stg / prod）、課金アカウントのリンク、`deletion_policy = "PREVENT"`
  - [x] API 有効化（全プロジェクトに WIF・IAM・Service Usage 系、admin に Cloud Storage）
  - [x] state バケット（`asia-northeast1`、バージョニング、均一アクセス、公開アクセス防止）
  - [x] Workload Identity Pool / Provider（属性条件: リポジトリ名＋オーナー ID）
  - [x] SA: `tf-plan`、`tf-apply-stg`、`tf-apply-prod` と各プロジェクト・バケットへの IAM（prefix 単位の IAM 条件）
  - [x] SA への `roles/iam.workloadIdentityUser`（`sub` 単位）
  - [x] `outputs.tf`（GitHub Variables に登録する値をまとめて出力）
  - [x] `terraform.tfvars.example`
- [x] 🤖 `docs/setup.md` に bootstrap の手順を書く
  - [x] 事前準備（`gcloud auth login`、`gcloud auth application-default login`、quota project）
  - [x] 初回 apply（ローカル state、`-target` でプロジェクト → クォータプロジェクト設定 → 残り）→ `backend_override.tf` を削除 → `terraform init -migrate-state`
  - [x] 出力値を GitHub Variables に登録する手順
- [x] 🤖 `ci.yml` に `terraform fmt -check` と `terraform validate` を追加する
- [ ] 👤 PR をレビューしてマージする

**完了条件**: `terraform validate` が通り、手順書だけを見て bootstrap を実行できる。

---

## フェーズ 3: bootstrap の apply と GitHub の設定（👤）

- [x] 👤 `docs/setup.md` に従って `infra/bootstrap` をローカルで apply する
- [x] 👤 state を GCS へ移行する
- [x] 👤 GitHub の Environments を作成する
  - [x] `stg`（ブランチ: `main`）
  - [x] `prod`（Required reviewers: 自分、ref: タグ `v*` とブランチ `main`）
  - [x] `infra-stg`（ブランチ: `main`）
  - [x] `infra-prod`（Required reviewers: 自分、ブランチ: `main`）
- [x] 👤 GitHub Variables を登録する（`docs/spec.md` §7.4）
- [x] 👤 ルールセットを設定する
  - [x] `main`: PR 必須、`ci` の成功が必須
  - [x] タグ `v*`: 作成・削除できるのは管理者のみ
- [x] 🤖 手順でつまずいた点があれば `docs/setup.md` を修正する（特になし）

**完了条件**: GCP に 3 プロジェクト・state バケット・WIF・Terraform 用 SA がある。GitHub の Environments・Variables・ルールセットが設定されている。

---

## フェーズ 4: Terraform envs と `terraform.yml`（PR #3）

- [x] 🤖 `infra/modules/hosting-env/`
  - [x] API の有効化（Firebase Management、Firebase Hosting など）
  - [x] `google_firebase_project`、`google_firebase_hosting_site`（サイト ID = プロジェクト ID）
  - [x] SA `deployer` と `roles/firebasehosting.admin`、`roles/serviceusage.serviceUsageConsumer`
  - [x] `deployer` への WIF の紐付け（変数で `sub` のリストを受け取る）
- [x] 🤖 `infra/envs/stg/`、`infra/envs/prod/`（backend の prefix、モジュールの呼び出し、`sub` の指定）
- [x] 🤖 `.github/workflows/terraform.yml`
  - [x] PR: `tf-plan` SA で stg / prod の plan（`-lock=false`）を実行し、結果を PR にコメントする
  - [x] main: `infra-stg` で apply → `infra-prod`（承認）で apply
  - [x] fork からの PR はスキップする
- [x] 👤 PR の plan コメントを確認してマージする
- [x] 👤 `infra-prod` の承認をする（※ 承認待ちにならずに実行されたため、`infra-prod` / `prod` の Required reviewers の設定を要確認）
- [x] 👤 出力された `deployer` SA を Environment `stg` / `prod` の `DEPLOY_SA` に登録する（apply ジョブのサマリーに表示される）

**完了条件**: stg / prod で Firebase と Hosting サイトが作成され、`terraform.yml` の plan と apply が成功している。

**検証ポイント**: `tf-plan` SA の権限で plan が通るか。足りなければ bootstrap に権限を追加する。

---

## フェーズ 5: デプロイ用ワークフロー（PR #4）

- [x] 🤖 共通処理（認証・ビルド・デプロイ・スモークテスト）を composite action（`.github/actions/deploy/`）にまとめる
- [x] 🤖 `.github/workflows/preview.yml`
  - [x] `hosting:channel:deploy pr-<番号> --expires <期限>` で `--json` の出力から URL を取得する
  - [x] スモークテストを実行し、PR に URL をコメントする（2 回目以降は同じコメントを更新する）
- [x] 🤖 `.github/workflows/deploy-stg.yml`（`main` への push、Environment `stg`、`concurrency`）
- [x] 🤖 `.github/workflows/deploy-prod.yml`
  - [x] タグ push と `workflow_dispatch`（入力 `tag`）
  - [x] タグが `main` 上のコミットであることを確認する
  - [x] Environment `prod`（承認）→ デプロイ → スモークテスト
- [x] 👤 この PR 自体でプレビューがデプロイされ、URL がコメントされることを確認してマージする

**完了条件**: この PR でプレビューが動き、マージ後に stg へデプロイされてスモークテストが成功している。

**検証ポイント**: `firebase-tools` が WIF の資格情報（ADC）でデプロイできるか。`roles/firebasehosting.admin` だけで足りるか。

---

## フェーズ 6: 動作確認シナリオ（`docs/spec.md` §10）

- [x] ページを変更する PR → lint・テスト・プレビュー URL のコメントを確認する
- [x] マージ → stg に反映され、スモークテストが成功する
- [x] `v1.0.0` タグを push → 承認 → prod に反映される
- [x] 変更して `v1.1.0` をリリース → `workflow_dispatch` で `v1.0.0` を指定してロールバックする
- [x] 異常系: lint エラーの PR で `ci` が失敗する
- [x] 異常系: `main` 上にないコミットへのタグで prod デプロイが失敗する
- [ ] 異常系: fork からの PR でプレビューと plan がスキップされる（任意。未実施）
- [x] 🤖 結果を `docs/verification.md` に記録する（実行した Actions のリンク、気づいた点）

**完了条件**: すべてのシナリオが想定どおりに動く。

---

## フェーズ 7: 仕上げ

- [ ] 🤖 `README.md`（概要、構成図、各ドキュメントへのリンク）
- [ ] 🤖 `docs/setup.md` に後片付けの手順を追加する（`deletion_policy` の解除 → `terraform destroy` → プロジェクトの削除）
- [ ] 🤖 `docs/spec.md` と `CLAUDE.md` を実装に合わせて更新する（検証で変わった点を反映する）
- [ ] 🤖 `TODO.md` を完了状態にする、または削除する

**完了条件**: 初めて見る人が README から構成を理解し、セットアップと後片付けができる。

# 動作確認の記録

`docs/spec.md` §10 の動作確認シナリオを実施した結果。

- 実施日: 2026-10-12
- GCP プロジェクト: `fhcl-admin-91cf` / `fhcl-stg-91cf` / `fhcl-prod-91cf`
- URL: stg https://fhcl-stg-91cf.web.app ／ prod https://fhcl-prod-91cf.web.app

## 結果のまとめ

| # | シナリオ | 結果 |
| --- | --- | --- |
| 1 | bootstrap の apply と GitHub の設定 | ✅（途中で WIF の `sub` の形式を修正し、bootstrap を apply し直した） |
| 2 | `infra/envs` の PR で plan → マージで stg を apply → 承認して prod を apply | ✅ |
| 3 | ページを変更する PR で、lint・テスト・プレビュー URL のコメント | ✅ |
| 4 | マージで stg に反映され、スモークテストが成功する | ✅ |
| 5 | `v1.0.0` タグを push → 承認 → prod に反映される | ✅ |
| 6 | `v1.1.0` をリリース → `workflow_dispatch` で `v1.0.0` にロールバック | ✅ |
| 7 | 異常系: lint エラーの PR で `ci` が失敗する | ✅ |
| 8 | 異常系: `main` 上にないコミットへのタグで prod デプロイが止まる | ✅ |
| 9 | 異常系: fork からの PR でプレビューと plan がスキップされる（任意） | 未実施 |

## 各シナリオの詳細

### 2. Terraform（infra/envs）

- PR #3 で `tf-plan` による stg（9 リソース作成）/ prod（8 リソース作成）の plan が PR にコメントされた
- マージ後、stg → prod の順に apply が成功した（[run 38276649681](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38276649681)）

### 3・7. ページ変更の PR と lint エラー（PR #5）

| コミット | 内容 | `ci` | プレビュー |
| --- | --- | --- | --- |
| `813bc97` | フッター追加＋わざと未使用の変数 | ❌ `no-unused-vars` で失敗（[run](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38279131499)） | デプロイされた（下の「気づいた点 3」） |
| `2bd8f53` | 未使用の変数を削除、テスト追加 | ✅（[run](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38279216045)） | ✅ 同じ PR コメントが新しいコミットの内容に更新された |

### 4. stg への反映

| きっかけ | 結果 |
| --- | --- |
| PR #4 のマージ（`d161d9a`） | ✅ [run 38278800657](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38278800657) |
| PR #5 のマージ（`c4adec0`） | ✅ [run 38280030101](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38280030101) |

### 5・6・8. prod へのリリースとロールバック

| 操作 | 対象コミット | 結果 |
| --- | --- | --- |
| タグ `v1.0.0` を push | `d161d9a`（フッターなし） | ✅ 承認待ち（約 1 分）→ 承認 → デプロイ（[run 38279751493](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38279751493)） |
| タグ `v0.9.0` を push（`main` にないコミット） | `813bc97` | ✅ 「main の履歴に含まれていません」で停止。承認待ちにもならず、prod は変わらない（[run 38279754239](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38279754239)） |
| タグ `v1.1.0` を push | `c4adec0`（フッターあり） | ✅ 承認待ち（約 1 分）→ 承認 → デプロイ（[run 38280514933](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38280514933)） |
| `workflow_dispatch`（`tag: v1.0.0`）でロールバック | `d161d9a` | ✅ 承認待ち（約 9 分）→ 承認 → デプロイ。スモークテストで `d161d9a` を確認（[run 38280805464](https://github.com/tsatolol/firebase_hosting_cicd_lab/actions/runs/38280805464)） |

## 気づいた点

1. **GitHub の OIDC トークンの `sub` に数値 ID が含まれる**
   `sub` は `repo:tsatolol@30972312/firebase_hosting_cicd_lab@1415534725:pull_request` の形式だった。`repo:<owner>/<repo>:…` で WIF を紐付けていたため、最初は SA へのなりすましが `iam.serviceAccounts.getAccessToken` で拒否された。principal を ID 付きの形式で組み立てるよう修正した（PR #3）。ワークフローに OIDC クレームを表示するステップを入れておいたことで、原因をすぐに特定できた。

2. **初回の plan は state がないと失敗する**
   GCS backend は init 時に空の state を書き込むため、読み取り専用の `tf-plan` では失敗した。state がない場合はローカルの空の state に対して plan するようにした（PR #3）。

3. **プレビューは `ci` の結果を待たずにデプロイされる**
   lint エラーのあるコミット（`813bc97`）でもプレビューが公開された。プレビューは stg プロジェクトの一時的な URL なので実害は小さいが、`ci` が通ったものだけを出したい場合は、プレビューのワークフローの前段に lint・テストのジョブを置く必要がある。（対応するかは未決）

4. **デプロイ直後は古い内容が返ることがある**
   ロールバックのスモークテストでは、1 回目のアクセスで直前のバージョン（`c4adec0`）が返り、約 6 秒後の 2 回目で `d161d9a` になった。スモークテストのリトライ（最大 10 回、6 秒間隔）が必要だった。

5. **Claude Code（Web 版）の環境からはタグを push できない**
   作業ブランチ以外への push はプロキシで拒否される（HTTP 403）。リリース用のタグの push は人が行う運用とした。

6. **`pull_request` の `paths` フィルタは PR 全体の差分で判定される**
   ドキュメントだけを変えるコミットを PR に push しても、PR 全体に `infra/` の変更が含まれていれば `terraform` が再実行される。

7. **`infra-prod` の承認待ちが見えなかった（フェーズ 4）**
   Terraform の prod の apply は、ジョブ作成の約 3 秒後に始まっていた。一方、フェーズ 6 のページの prod デプロイ（Environment `prod`）は 3 回とも承認待ちで止まり、承認後に実行された。`infra-prod` の Required reviewers の設定は、次に `infra/envs` を変更するときに再確認する。

8. **ブランチのルールセットの対象**
   `main` 用のルールセットが作業ブランチにも適用され、push が拒否された。Target branches を「Include default branch」だけにして解消した（`docs/setup.md` 3-3 に注意書きを追加済み）。

9. **`npm audit` の警告**
   開発用の依存（stylelint、firebase-tools）に high を含む警告が 18 件ある。配信するページには含まれない。

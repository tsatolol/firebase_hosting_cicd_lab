#!/usr/bin/env bash
# GitHub Actions の OIDC トークンのクレーム（sub など）を表示する。WIF の紐付けを確認するためのデバッグ用。
# トークン自体は表示しない。ジョブに permissions: id-token: write が必要。
set -euo pipefail

if [[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" || -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]]; then
  echo "OIDC トークンを取得できません（permissions: id-token: write がないか、fork からの PR です）" >&2
  exit 1
fi

token="$(curl -sSf -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=claims-debug" | jq -r .value)"

# JWT のペイロード（2 番目の要素）を base64url デコードし、主要なクレームだけを出す
python3 - "$token" <<'PY'
import base64, json, sys
payload = sys.argv[1].split(".")[1]
claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
keys = ["sub", "repository", "repository_owner_id", "repository_id", "event_name", "ref", "environment", "job_workflow_ref"]
print(json.dumps({k: claims.get(k) for k in keys}, indent=2, ensure_ascii=False))
PY

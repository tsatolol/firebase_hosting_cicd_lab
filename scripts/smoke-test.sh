#!/usr/bin/env bash
# デプロイ後の URL が HTTP 200 を返し、data-commit が期待するコミット SHA と一致することを確認する。
#
# 使い方: scripts/smoke-test.sh <URL> <期待するコミット SHA>
# 環境変数: SMOKE_RETRIES（既定: 10）、SMOKE_INTERVAL（秒、既定: 6）
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <url> <expected-commit-sha>" >&2
  exit 2
fi

URL="$1"
EXPECTED_SHA="$2"
RETRIES="${SMOKE_RETRIES:-10}"
INTERVAL="${SMOKE_INTERVAL:-6}"

for ((i = 1; i <= RETRIES; i++)); do
  body="$(curl --silent --show-error --fail --location --max-time 10 \
    --header 'Cache-Control: no-cache' "$URL")" && status=0 || status=$?

  if [[ $status -eq 0 ]]; then
    actual_sha="$(grep -oE 'data-commit="[^"]*"' <<<"$body" | head -n1 | cut -d'"' -f2 || true)"
    if [[ "$actual_sha" == "$EXPECTED_SHA" ]]; then
      echo "smoke-test: OK ($URL, commit=$actual_sha, attempt $i/$RETRIES)"
      exit 0
    fi
    echo "smoke-test: commit が一致しません (expected=$EXPECTED_SHA actual=${actual_sha:-<none>}, attempt $i/$RETRIES)" >&2
  else
    echo "smoke-test: リクエストに失敗しました (curl exit=$status, attempt $i/$RETRIES)" >&2
  fi

  if ((i < RETRIES)); then
    sleep "$INTERVAL"
  fi
done

echo "smoke-test: NG ($URL)" >&2
exit 1

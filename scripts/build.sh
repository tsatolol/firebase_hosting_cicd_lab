#!/usr/bin/env bash
# src/ を dist/ にコピーし、index.html のプレースホルダーをデプロイ情報で置換する。
#
# 環境変数（未指定時はローカル用の値になる）:
#   APP_ENV      prod | stg | preview | local（既定: local）
#   APP_VERSION  表示するバージョン（既定: dev）
#   COMMIT_SHA   コミット SHA（既定: git rev-parse HEAD）
#   DEPLOYED_AT  ISO 8601 の UTC 日時（既定: 現在時刻）
#   DIST_DIR     出力先（既定: dist。テストで一時ディレクトリを指定するために使う）
set -euo pipefail

cd "$(dirname "$0")/.."

SRC_DIR="src"
DIST_DIR="${DIST_DIR:-dist}"

APP_ENV="${APP_ENV:-local}"
APP_VERSION="${APP_VERSION:-dev}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
DEPLOYED_AT="${DEPLOYED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

fail() {
  echo "build: $*" >&2
  exit 1
}

[[ -n "$DIST_DIR" && "$DIST_DIR" != "/" ]] || fail "DIST_DIR が不正です: '$DIST_DIR'"

case "$APP_ENV" in
  prod | stg | preview | local) ;;
  *) fail "APP_ENV が不正です: '$APP_ENV'（prod / stg / preview / local のいずれか）" ;;
esac

# HTML 属性と sed の置換文字列に安全に埋め込める文字だけを許可する
SAFE_VALUE='^[A-Za-z0-9._:+-]+$'
[[ "$APP_VERSION" =~ $SAFE_VALUE ]] || fail "APP_VERSION に使えない文字が含まれています: '$APP_VERSION'"
[[ "$COMMIT_SHA" =~ ^([0-9a-f]{7,40}|unknown)$ ]] || fail "COMMIT_SHA が不正です: '$COMMIT_SHA'"
[[ "$DEPLOYED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
  || fail "DEPLOYED_AT は YYYY-MM-DDTHH:MM:SSZ 形式で指定してください: '$DEPLOYED_AT'"

rm -rf "$DIST_DIR"
cp -R "$SRC_DIR" "$DIST_DIR"

sed -i.bak \
  -e "s|__APP_ENV__|${APP_ENV}|g" \
  -e "s|__APP_VERSION__|${APP_VERSION}|g" \
  -e "s|__COMMIT_SHA__|${COMMIT_SHA}|g" \
  -e "s|__DEPLOYED_AT__|${DEPLOYED_AT}|g" \
  "$DIST_DIR/index.html"
rm -f "$DIST_DIR/index.html.bak"

if grep -nE '__(APP_ENV|APP_VERSION|COMMIT_SHA|DEPLOYED_AT)__' "$DIST_DIR/index.html"; then
  fail "置換されていないプレースホルダーがあります"
fi

echo "build: $DIST_DIR/index.html (env=$APP_ENV version=$APP_VERSION commit=$COMMIT_SHA deployed_at=$DEPLOYED_AT)"

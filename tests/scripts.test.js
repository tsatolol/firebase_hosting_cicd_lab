import { execFile } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { afterAll, afterEach, beforeAll, describe, expect, it } from "vitest";

const run = promisify(execFile);
const BUILD = fileURLToPath(new URL("../scripts/build.sh", import.meta.url));
const SMOKE = fileURLToPath(new URL("../scripts/smoke-test.sh", import.meta.url));
const SHA = "0123abcdef0123abcdef0123abcdef0123abcdef";

describe("scripts/build.sh", () => {
  let distDir;

  beforeAll(() => {
    distDir = join(mkdtempSync(join(tmpdir(), "fhcl-build-")), "dist");
  });

  afterAll(() => {
    rmSync(join(distDir, ".."), { recursive: true, force: true });
  });

  function build(env) {
    return run("bash", [BUILD], { env: { ...process.env, DIST_DIR: distDir, ...env } });
  }

  it("プレースホルダーをデプロイ情報で置換する", async () => {
    await build({
      APP_ENV: "prod",
      APP_VERSION: "v1.2.3",
      COMMIT_SHA: SHA,
      DEPLOYED_AT: "2026-10-12T12:00:00Z",
    });
    const html = readFileSync(join(distDir, "index.html"), "utf8");
    expect(html).toContain(
      `data-env="prod" data-version="v1.2.3" data-commit="${SHA}" data-deployed-at="2026-10-12T12:00:00Z"`,
    );
    expect(html).not.toMatch(/__(APP_ENV|APP_VERSION|COMMIT_SHA|DEPLOYED_AT)__/);
  });

  it.each([
    [{ APP_ENV: "dev" }, /APP_ENV が不正です/],
    [{ APP_VERSION: 'v1"><script>' }, /APP_VERSION に使えない文字/],
    [{ APP_VERSION: "a|b" }, /APP_VERSION に使えない文字/],
    [{ COMMIT_SHA: "xyz" }, /COMMIT_SHA が不正です/],
    [{ DEPLOYED_AT: "2026-10-12 12:00:00" }, /DEPLOYED_AT は/],
  ])("不正な値 %o では失敗する", async (env, message) => {
    await expect(build(env)).rejects.toMatchObject({ code: 1, stderr: expect.stringMatching(message) });
  });
});

describe("scripts/smoke-test.sh", () => {
  let server;
  let baseUrl;
  let response;

  beforeAll(async () => {
    server = createServer((_req, res) => {
      res.writeHead(response.status, { "Content-Type": "text/html" });
      res.end(response.body);
    });
    await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
    baseUrl = `http://127.0.0.1:${server.address().port}/`;
  });

  afterAll(() => new Promise((resolve) => server.close(resolve)));

  afterEach(() => {
    response = undefined;
  });

  function smoke(expectedSha) {
    return run("bash", [SMOKE, baseUrl, expectedSha], {
      env: { ...process.env, SMOKE_RETRIES: "2", SMOKE_INTERVAL: "0" },
    });
  }

  it("HTTP 200 で data-commit が一致すれば成功する", async () => {
    response = { status: 200, body: `<body data-env="stg" data-commit="${SHA}">` };
    const { stdout } = await smoke(SHA);
    expect(stdout).toContain("smoke-test: OK");
  });

  it("data-commit が一致しなければ失敗する", async () => {
    response = { status: 200, body: '<body data-commit="ffffffffffffffffffffffffffffffffffffffff">' };
    await expect(smoke(SHA)).rejects.toMatchObject({
      code: 1,
      stderr: expect.stringContaining("commit が一致しません"),
    });
  });

  it("HTTP エラーなら失敗する", async () => {
    response = { status: 404, body: "not found" };
    await expect(smoke(SHA)).rejects.toMatchObject({
      code: 1,
      stderr: expect.stringContaining("リクエストに失敗しました"),
    });
  });
});

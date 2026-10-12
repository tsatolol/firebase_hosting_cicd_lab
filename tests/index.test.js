import { readFileSync } from "node:fs";
import { JSDOM } from "jsdom";
import { afterEach, describe, expect, it, vi } from "vitest";

const SOURCE = readFileSync(new URL("../src/index.html", import.meta.url), "utf8");

const STG_DATA = {
  __APP_ENV__: "stg",
  __APP_VERSION__: "main-0123abc",
  __COMMIT_SHA__: "0123abcdef0123abcdef0123abcdef0123abcdef",
  __DEPLOYED_AT__: "2026-10-12T12:00:00Z",
};

let dom;

// build.sh と同じようにプレースホルダーを置換してから読み込む（data を省略すると未置換のまま）
async function loadPage(data = {}) {
  let html = SOURCE;
  for (const [placeholder, value] of Object.entries(data)) {
    html = html.replaceAll(placeholder, value);
  }
  dom = new JSDOM(html, { runScripts: "dangerously", url: "https://example.web.app/" });
  const { document } = dom.window;
  if (document.readyState === "loading") {
    await new Promise((resolve) => document.addEventListener("DOMContentLoaded", resolve));
  }
  return dom.window;
}

afterEach(() => {
  dom?.window.close();
  dom = undefined;
});

describe("App の関数", () => {
  it("isUnset: 未置換のプレースホルダーと空文字を未設定とみなす", async () => {
    const { App } = await loadPage();
    expect(App.isUnset("__APP_ENV__")).toBe(true);
    expect(App.isUnset("")).toBe(true);
    expect(App.isUnset(undefined)).toBe(true);
    expect(App.isUnset("stg")).toBe(false);
  });

  it("envTheme: 環境ごとのラベルとクラスを返し、未知の環境は UNKNOWN にする", async () => {
    const { App } = await loadPage();
    expect(App.envTheme("prod")).toEqual({ label: "PRODUCTION", className: "env-prod" });
    expect(App.envTheme("stg")).toEqual({ label: "STAGING", className: "env-stg" });
    expect(App.envTheme("preview")).toEqual({ label: "PREVIEW", className: "env-preview" });
    expect(App.envTheme("local")).toEqual({ label: "LOCAL", className: "env-local" });
    expect(App.envTheme("dev")).toEqual({ label: "UNKNOWN", className: "env-unknown" });
    expect(App.envTheme("toString").label).toBe("UNKNOWN");
    expect(App.envTheme(null).label).toBe("UNKNOWN");
  });

  it("commitUrl: SHA の形式のときだけ GitHub のコミット URL を返す", async () => {
    const { App } = await loadPage();
    expect(App.commitUrl("0123abc")).toBe(
      "https://github.com/tsatolol/firebase_hosting_cicd_lab/commit/0123abc",
    );
    expect(App.commitUrl("unknown")).toBeNull();
    expect(App.commitUrl("0123ab")).toBeNull();
    expect(App.commitUrl("0123ABC")).toBeNull();
  });

  it("buildDeployInfo: data-* 属性をデプロイ情報に変換し、未設定は null にする", async () => {
    const { App } = await loadPage();
    expect(
      App.buildDeployInfo({
        env: "prod",
        version: "v1.0.0",
        commit: "__COMMIT_SHA__",
        deployedAt: "",
      }),
    ).toEqual({ env: "prod", version: "v1.0.0", commit: null, deployedAt: null });
  });

  it.each([
    ["2026-10-12T12:00:00Z", "たった今"],
    ["2026-10-12T11:59:01Z", "たった今"],
    ["2026-10-12T11:59:00Z", "1 分前"],
    ["2026-10-12T11:01:00Z", "59 分前"],
    ["2026-10-12T11:00:00Z", "1 時間前"],
    ["2026-10-11T12:00:01Z", "23 時間前"],
    ["2026-10-11T12:00:00Z", "1 日前"],
    ["2026-10-12T12:05:00Z", "たった今"],
    ["invalid", ""],
  ])("formatRelativeTime(%s) は「%s」", async (iso, expected) => {
    const { App } = await loadPage();
    expect(App.formatRelativeTime(iso, new Date("2026-10-12T12:00:00Z"))).toBe(expected);
  });

  it("formatDateTime: 指定したタイムゾーンで日時を整形する", async () => {
    const { App } = await loadPage();
    expect(App.formatDateTime("2026-10-12T12:00:00Z", "Asia/Tokyo")).toBe("2026/10/12 21:00:00");
    expect(App.formatDateTime("2026-10-12T12:00:00Z", "UTC")).toBe("2026/10/12 12:00:00");
    expect(App.formatDateTime("invalid", "UTC")).toBe("");
  });
});

describe("初期表示", () => {
  it("デプロイ情報を表示し、環境に応じたクラスを付ける", async () => {
    const { document } = await loadPage(STG_DATA);
    expect(document.body.classList.contains("env-stg")).toBe(true);
    expect(document.getElementById("env-badge").textContent).toBe("STAGING");
    expect(document.getElementById("env").textContent).toBe("stg");
    expect(document.getElementById("version").textContent).toBe("main-0123abc");

    const commit = document.getElementById("commit");
    expect(commit.textContent).toBe("0123abc");
    expect(commit.getAttribute("href")).toBe(
      "https://github.com/tsatolol/firebase_hosting_cicd_lab/commit/0123abcdef0123abcdef0123abcdef0123abcdef",
    );

    const deployedAt = document.getElementById("deployed-at");
    expect(deployedAt.getAttribute("datetime")).toBe("2026-10-12T12:00:00Z");
    expect(deployedAt.textContent).not.toBe("未設定");
    expect(document.getElementById("deployed-ago").textContent).toMatch(/^（(.+前|たった今)）$/);
  });

  it("フッターにリポジトリへのリンクがある", async () => {
    const { document } = await loadPage(STG_DATA);
    expect(document.getElementById("repo-link").getAttribute("href")).toBe(
      "https://github.com/tsatolol/firebase_hosting_cicd_lab",
    );
  });

  it("プレースホルダーが未置換のときは「未設定」と UNKNOWN を表示する", async () => {
    const { document } = await loadPage();
    expect(document.body.classList.contains("env-unknown")).toBe(true);
    expect(document.getElementById("env-badge").textContent).toBe("UNKNOWN");
    expect(document.getElementById("env").textContent).toBe("未設定");
    expect(document.getElementById("version").textContent).toBe("未設定");
    expect(document.getElementById("commit").textContent).toBe("未設定");
    expect(document.getElementById("commit").hasAttribute("href")).toBe(false);
    expect(document.getElementById("deployed-at").textContent).toBe("未設定");
    expect(document.getElementById("deployed-ago").textContent).toBe("");
  });
});

describe("デプロイ情報のコピー", () => {
  it("成功したらデプロイ情報の JSON を書き込み、完了を表示する", async () => {
    const { App, document } = await loadPage(STG_DATA);
    const clipboard = { writeText: vi.fn().mockResolvedValue(undefined) };
    const info = App.buildDeployInfo(document.body.dataset);

    await expect(App.copyDeployInfo(document, info, clipboard)).resolves.toBe(true);
    expect(JSON.parse(clipboard.writeText.mock.calls[0][0])).toEqual({
      env: "stg",
      version: "main-0123abc",
      commit: "0123abcdef0123abcdef0123abcdef0123abcdef",
      deployedAt: "2026-10-12T12:00:00Z",
    });
    expect(document.getElementById("copy-status").textContent).toBe("コピーしました");
  });

  it("書き込みに失敗したら失敗を表示する", async () => {
    const { App, document } = await loadPage(STG_DATA);
    const clipboard = { writeText: vi.fn().mockRejectedValue(new Error("denied")) };

    await expect(App.copyDeployInfo(document, {}, clipboard)).resolves.toBe(false);
    expect(document.getElementById("copy-status").textContent).toBe("コピーできませんでした");
  });

  it("Clipboard API がないときはコピーできないことを表示する", async () => {
    const { App, document } = await loadPage(STG_DATA);

    await expect(App.copyDeployInfo(document, {}, undefined)).resolves.toBe(false);
    expect(document.getElementById("copy-status").textContent).toBe("このブラウザではコピーできません");
  });
});

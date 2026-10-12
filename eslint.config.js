import js from "@eslint/js";
import html from "eslint-plugin-html";
import globals from "globals";

export default [
  { ignores: ["dist/", "coverage/", "node_modules/"] },
  js.configs.recommended,
  {
    // index.html 内の <script>（ブラウザで実行される）
    files: ["src/**/*.html"],
    plugins: { html },
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "script",
      globals: globals.browser,
    },
  },
  {
    // 設定ファイル・テスト（Node.js で実行される）
    files: ["**/*.js"],
    languageOptions: {
      globals: globals.node,
    },
  },
];

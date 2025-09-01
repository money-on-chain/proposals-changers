// eslint.config.js
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import n from "eslint-plugin-n";
import importPlugin from "eslint-plugin-import";
import eslintConfigPrettier from "eslint-config-prettier";

export default [
  { ignores: ["node_modules/", "dist/", "build/", "artifacts/", "cache/", "out/", "typechain*/", "**/*.d.ts"] },

  js.configs.recommended,
  ...tseslint.configs.recommended, // rápido, sin type-check

  importPlugin.flatConfigs.recommended,

  {
    plugins: { n },
    rules: {
      "n/no-missing-import": "off",
      "n/no-unsupported-features/es-syntax": "off",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      "import/order": [
        "warn",
        {
          "newlines-between": "always",
          alphabetize: { order: "asc", caseInsensitive: true },
          groups: ["builtin", "external", "internal", ["parent", "sibling", "index"]],
        },
      ],
    },
    settings: { "import/resolver": { typescript: true } },
  },

  // Desactiva reglas que chocan con Prettier (no usamos eslint-plugin-prettier)
  eslintConfigPrettier,
];

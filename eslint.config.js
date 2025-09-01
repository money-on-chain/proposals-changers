// eslint.config.js
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import importPlugin from "eslint-plugin-import";
import n from "eslint-plugin-n";
import eslintConfigPrettier from "eslint-config-prettier";
import globals from "globals";

export default [
  // 1) Ignorar generados y artefactos
  {
    ignores: [
      "node_modules/",
      "dist/",
      "build/",
      "coverage/",
      "artifacts/",
      "cache/",
      "out/",
      "typechain*/",
      "types/ethers-contracts/**",
      "**/*.d.ts",
    ],
  },

  // 2) Base JS + TS (sin type-check para que sea rápido/estable)
  js.configs.recommended,
  ...tseslint.configs.recommended,

  // 3) Node + import plugin
  importPlugin.flatConfigs.recommended,
  {
    plugins: { n },
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      // Globals de Node para scripts y config (process, console, etc.)
      globals: {
        ...globals.node,
      },
    },
    rules: {
      "n/no-missing-import": "off",
      "n/no-unsupported-features/es-syntax": "off",
      // Orden de imports (ajustá si querés)
      "import/order": [
        "warn",
        {
          "newlines-between": "always",
          alphabetize: { order: "asc", caseInsensitive: true },
          groups: ["builtin", "external", "internal", ["parent", "sibling", "index"]],
        },
      ],
      // Si te molesta, podés desactivar no-console para scripts de CLI:
      // "no-console": "off",
    },
  },

  // 4) Overrides específicos
  // a) Tests: habilita globals de Mocha/Jest
  {
    files: ["test/**/*.{js,ts,tsx}", "tests/**/*.{js,ts,tsx}"],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.mocha, // describe, it, before, after...
        // ...globals.jest // si usás jest
      },
    },
    rules: {
      // ejemplos: relajar reglas verbosas en tests
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      "no-empty": "off",
    },
  },
  // b) Config/CLI scripts: permitir console
  {
    files: [
      "hardhat.config.{js,ts}",
      "scripts/**/*.{js,ts,mjs,cjs}",
      "tasks/**/*.{js,ts,mjs,cjs}",
      "scripts/**/*.js",
    ],
    rules: {
      "no-console": "off",
    },
  },

  // 5) Desactiva choques con Prettier
  eslintConfigPrettier,
];

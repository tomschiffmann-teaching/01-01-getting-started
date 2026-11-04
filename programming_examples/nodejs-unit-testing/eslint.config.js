// ESLint-Konfiguration ("flat config")
import js from "@eslint/js";
import globals from "globals";

export default [
  // Diese Ordner nicht prüfen
  { ignores: ["node_modules/", "dist/", "coverage/"] },

  // Empfohlene Standard-Regeln von ESLint
  js.configs.recommended,

  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module", // import/export
      globals: globals.node, // process, console, ...
    },
    rules: {
      // Hier können eigene Regeln definiert werden
      "max-len": ["error", { code: 84, ignoreUrls: true }],
      // max. 120 Zeichen pro Zeile
    },
  },
];

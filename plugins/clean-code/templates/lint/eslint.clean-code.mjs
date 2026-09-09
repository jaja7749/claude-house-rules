// Hard numbers referenced by CLAUDE.md (TS/JS). Change them here, not there.
//
// Usage: spread into eslint.config.mjs
//   import cleanCode from "./eslint.clean-code.mjs";
//   export default [...existing, cleanCode];
//
// naming-convention with types: ["boolean"] needs type information, so the config requires
// languageOptions.parserOptions.projectService = true (or project: "./tsconfig.json").
// For a plain JS project, drop the naming-convention rule.

export default {
  files: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
  rules: {
    // Targets (40 lines / 4 params / 400 lines / 3 levels) live in CLAUDE.md; these are the ceilings.
    "max-lines": ["error", { max: 500, skipBlankLines: true, skipComments: true }],
    "max-lines-per-function": ["error", { max: 60, skipBlankLines: true, skipComments: true }],
    "max-params": ["error", 6],
    "max-depth": ["error", 4],
    complexity: ["warn", 8],
    "no-magic-numbers": ["warn", { ignore: [0, 1, -1], ignoreArrayIndexes: true, enforceConst: true }],

    "no-restricted-syntax": [
      "error",
      {
        selector: "JSXAttribute[name.name='dangerouslySetInnerHTML']",
        message: "use the framework's default escaping instead of dangerouslySetInnerHTML",
      },
      {
        selector: "AssignmentExpression[left.property.name='innerHTML']",
        message: "do not assign to innerHTML",
      },
    ],

    "@typescript-eslint/naming-convention": [
      "error",
      {
        selector: "variable",
        types: ["boolean"],
        format: ["PascalCase"],
        prefix: ["is", "has", "should", "can"],
      },
      {
        selector: "typeLike",
        format: ["PascalCase"],
        custom: { regex: "(Manager|Helper|Utils?)$", match: false },
      },
    ],
  },
};

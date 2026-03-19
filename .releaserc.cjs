module.exports = {
  branches: [
    "main",
    {
      name: "develop",
      prerelease: "rc"
    }
  ],
  plugins: [
    [
      "@semantic-release/commit-analyzer",
      {
        preset: "conventionalcommits",
        releaseRules: [
          { type: "breaking", release: "major" },
          { type: "feat", release: "minor" },
          { type: "fix", release: "patch" },
          { type: "perf", release: "patch" },
          { type: "security", release: "patch" },
          { type: "revert", release: "patch" },
          { type: "refactor", release: false },
          { type: "docs", release: false },
          { type: "chore", release: false },
          { type: "ci", release: false },
          { type: "test", release: false },
          { type: "style", release: false },
          { scope: "deps", release: "patch" }
        ]
      }
    ],
    [
      "@semantic-release/release-notes-generator",
      {
        preset: "conventionalcommits",
        presetConfig: {
          types: [
            { type: "breaking", section: "⚠️ Breaking Changes", hidden: false },
            { type: "security", section: "🔒 Security", hidden: false },
            { type: "feat", section: "✨ Features", hidden: false },
            { type: "fix", section: "🐛 Bug Fixes", hidden: false },
            { type: "perf", section: "⚡ Performance", hidden: false },
            { type: "revert", section: "⏪ Reverts", hidden: false },
            { type: "refactor", section: "♻️ Refactoring", hidden: true },
            { type: "docs", section: "📚 Documentation", hidden: true },
            { type: "chore", section: "🔧 Maintenance", hidden: true },
            { type: "ci", section: "👷 CI/CD", hidden: true },
            { type: "test", section: "✅ Tests", hidden: true },
            { type: "style", section: "💄 Styling", hidden: true }
          ]
        },
        writerOpts: {
          groupBy: "type",
          commitPartial: "*{{#if scope}} **{{scope}}:**{{/if}} {{#if subject}}{{subject}}{{else}}{{header}}{{/if}}{{#if shortHash}} ({{shortHash}}){{/if}}\n",
        },
        parserOpts: {
          noteKeywords: ["BREAKING CHANGE", "BREAKING CHANGES", "BREAKING"]
        },
        linkCompare: false,
        linkReferences: false
      }
    ],
    [
      "@semantic-release/changelog",
      {
        changelogFile: "RELEASE_NOTES.md"
      }
    ],
    [
      "@semantic-release/exec",
      {
        successCmd: "echo \"version=${nextRelease.version}\" >> $GITHUB_OUTPUT && echo \"tag=${nextRelease.gitTag}\" >> $GITHUB_OUTPUT && echo \"released=true\" >> $GITHUB_OUTPUT"
      }
    ],
    [
      "@semantic-release/github",
      {
        successComment: false,
        failComment: false,
        releasedLabels: false,
        assets: [
          {
            path: "RELEASE_NOTES.md",
            label: "Release Notes"
          }
        ]
      }
    ]
  ]
};

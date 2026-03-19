import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebars: SidebarsConfig = {
  docsSidebar: [
    {
      type: "doc",
      id: "intro",
      label: "Introduction",
    },
    {
      type: "category",
      label: "Getting Started",
      collapsed: false,
      items: [
        "getting-started/quick-start",
        "getting-started/first-scan",
      ],
    },
    {
      type: "category",
      label: "User Guide",
      items: [
        "user-guide/core-concepts",
        "user-guide/targets",
        "user-guide/scanning",
        "user-guide/reports",
        "user-guide/probes",
        "user-guide/environment-variables",
        "user-guide/integrations",
        "user-guide/mock-llm",
      ],
    },
    {
      type: "category",
      label: "Deployment",
      items: [
        "deployment/docker-compose",
        "deployment/reverse-proxy",
        "deployment/database",
        "deployment/upgrading",
      ],
    },
    {
      type: "category",
      label: "Development",
      items: [
        "development/setup",
        "development/testing",
        "development/architecture",
        "development/extension-points",
        "development/engines",
        "development/monitoring",
        "development/conventions",
      ],
    },
    {
      type: "doc",
      id: "troubleshooting",
      label: "Troubleshooting",
    },
  ],
};

export default sidebars;

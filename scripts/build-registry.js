#!/usr/bin/env node

/**
 * Build the shadcn registry.
 *
 * Reads registry/registry.json, embeds file contents into each item,
 * and outputs individual JSON files + an index to registry/dist/
 *
 * Usage: node scripts/build-registry.js
 */

const fs = require("fs");
const path = require("path");

const REGISTRY_DIR = path.resolve(__dirname, "../registry");
const DIST_DIR = path.join(REGISTRY_DIR, "dist");
const MANIFEST = path.join(REGISTRY_DIR, "registry.json");

// Clean and create dist
if (fs.existsSync(DIST_DIR)) {
  fs.rmSync(DIST_DIR, { recursive: true });
}
fs.mkdirSync(DIST_DIR, { recursive: true });

// Read manifest
const registry = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));

const index = [];

for (const item of registry.items) {
  // Embed file contents
  const filesWithContent = item.files.map((file) => {
    const filePath = path.join(REGISTRY_DIR, file.path);
    if (!fs.existsSync(filePath)) {
      console.error(`  ERROR: File not found: ${file.path}`);
      process.exit(1);
    }
    const content = fs.readFileSync(filePath, "utf8");
    return {
      ...file,
      content,
      target: `components/${file.path}`,
    };
  });

  const output = {
    name: item.name,
    type: item.type,
    description: item.description || "",
    dependencies: item.dependencies || [],
    registryDependencies: item.registryDependencies || [],
    files: filesWithContent,
  };

  // Write individual component JSON
  const outPath = path.join(DIST_DIR, `${item.name}.json`);
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2) + "\n");
  console.log(`  Built: ${item.name}.json`);

  // Add to index
  index.push({
    name: item.name,
    type: item.type,
    description: item.description || "",
    dependencies: item.dependencies || [],
    registryDependencies: item.registryDependencies || [],
  });
}

// Write index
fs.writeFileSync(
  path.join(DIST_DIR, "index.json"),
  JSON.stringify(index, null, 2) + "\n"
);

console.log(`\n  Registry built: ${index.length} component(s) → registry/dist/`);

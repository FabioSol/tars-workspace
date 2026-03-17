#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# create-project.sh — Scaffold a new React + Vite + TS project with the full stack
#
# Usage: ./scripts/create-project.sh <project-name> [--repo <github-repo-name>]
#
# Stack: React, Vite, TypeScript, Tailwind v4, shadcn/ui, GSAP, Lucide React,
#        Playwright, GitHub Actions (Pages deploy)
#
# Order matters! Steps are sequenced to avoid config conflicts.
# =============================================================================

WORKSPACE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOILERPLATES="$WORKSPACE_ROOT/boilerplates"
APPROVED_COMPONENTS="$WORKSPACE_ROOT/approved-components.json"
PROJECTS_DIR="$WORKSPACE_ROOT/projects"

# --- Parse args ---
PROJECT_NAME="${1:-}"
REPO_NAME=""

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Usage: $0 <project-name> [--repo <github-repo-name>]"
  exit 1
fi

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

if [[ -d "$PROJECT_DIR" ]]; then
  echo "Error: Project '$PROJECT_NAME' already exists at $PROJECT_DIR"
  exit 1
fi

echo "================================================"
echo " Creating project: $PROJECT_NAME"
echo " Location: $PROJECT_DIR"
echo "================================================"
echo ""

# =============================================================================
# Step 1: Scaffold with Vite (React + TypeScript)
# =============================================================================
echo "[1/8] Scaffolding with Vite..."
mkdir -p "$PROJECTS_DIR"
cd "$PROJECTS_DIR"
# Pipe "n" to decline the "install and start now?" prompt — we handle install ourselves
# Use create-vite@6 to scaffold a Vite 7 project (Vite 8 not yet supported by @tailwindcss/vite)
echo "n" | npm create vite@6 "$PROJECT_NAME" -- --template react-ts
cd "$PROJECT_DIR"

echo "[1/8] Installing base dependencies..."
npm install

# =============================================================================
# Step 2: Install Tailwind CSS v4
# Tailwind v4 uses the Vite plugin — no config file needed.
# =============================================================================
echo "[2/8] Installing Tailwind CSS v4..."
npm install -D tailwindcss @tailwindcss/vite

# Replace vite.config.ts with our boilerplate (includes tailwind + path aliases)
cp "$BOILERPLATES/vite.config.ts" ./vite.config.ts

# Replace the default CSS with our tailwind-ready version
cp "$BOILERPLATES/index.css" ./src/index.css

# =============================================================================
# Step 3: Configure path aliases for TypeScript
# shadcn requires @ path alias to work
# =============================================================================
echo "[3/8] Configuring TypeScript path aliases..."

# Update tsconfig.json to add baseUrl and paths
cat > tsconfig.json << 'TSEOF'
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ],
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
TSEOF

# Update tsconfig.app.json — overwrite entirely because Vite's template has comments
# that break JSON.parse
cat > tsconfig.app.json << 'APPTSEOF'
{
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "verbatimModuleSyntax": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
APPTSEOF

# =============================================================================
# Step 4: Initialize shadcn/ui
# Must come after Tailwind + path aliases are configured
# =============================================================================
echo "[4/8] Initializing shadcn/ui..."
cp "$BOILERPLATES/components.json" ./components.json

# Create the lib/utils.ts that shadcn expects
mkdir -p src/lib
cat > src/lib/utils.ts << 'UTILSEOF'
import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
UTILSEOF

npm install clsx tailwind-merge class-variance-authority

# Create the ui directory
mkdir -p src/components/ui

# =============================================================================
# Step 5: Install approved shadcn components
# =============================================================================
echo "[5/8] Installing approved shadcn components..."
if [[ -f "$APPROVED_COMPONENTS" ]]; then
  # Extract component names from the JSON
  COMPONENTS=$(node -e "
    const data = JSON.parse(require('fs').readFileSync('$APPROVED_COMPONENTS', 'utf8'));
    console.log(data.components.map(c => c.name).join(' '));
  ")

  if [[ -n "$COMPONENTS" ]]; then
    echo "     Installing: $COMPONENTS"
    npx --yes shadcn@latest add $COMPONENTS --yes --overwrite
  fi
fi

# =============================================================================
# Step 6: Install GSAP + Lucide React
# =============================================================================
echo "[6/8] Installing GSAP and Lucide React..."
npm install gsap lucide-react

# =============================================================================
# Step 7: Set up Playwright
# =============================================================================
echo "[7/8] Setting up Playwright..."
npm install -D @playwright/test
npx playwright install

# Copy playwright config
cp "$BOILERPLATES/playwright.config.ts" ./playwright.config.ts

# Create e2e test directory with a starter test
mkdir -p e2e
cat > e2e/app.spec.ts << 'E2EEOF'
import { test, expect } from "@playwright/test";

test("homepage loads", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/Vite/);
});
E2EEOF

# =============================================================================
# Step 8: GitHub Actions for Pages deploy + Playwright
# =============================================================================
echo "[8/8] Setting up GitHub Actions..."
mkdir -p .github/workflows
cp "$BOILERPLATES/github/workflows/deploy.yml" .github/workflows/deploy.yml

# If repo name provided, set the vite base path
if [[ -n "$REPO_NAME" ]]; then
  sed -i '' "s|// base: \"/<repo-name>/\",|base: \"/$REPO_NAME/\",|" vite.config.ts
  echo "     Set vite base path to: /$REPO_NAME/"
fi

# =============================================================================
# Add convenience scripts to package.json
# =============================================================================
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = {
  ...pkg.scripts,
  'test:e2e': 'playwright test',
  'test:e2e:ui': 'playwright test --ui',
};
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "================================================"
echo " Project '$PROJECT_NAME' is ready!"
echo " Location: $PROJECT_DIR"
echo "================================================"
echo ""
echo " Quick start:"
echo "   cd projects/$PROJECT_NAME"
echo "   npm run dev"
echo ""
echo " Tests:"
echo "   npm run test:e2e"
echo "   npm run test:e2e:ui"
echo ""
if [[ -n "$REPO_NAME" ]]; then
  echo " GitHub Pages:"
  echo "   Base path set to /$REPO_NAME/"
  echo "   Push to main to trigger deploy"
  echo ""
fi
echo " To add more shadcn components:"
echo "   npx shadcn@latest add <component>"
echo ""
echo " To add components from the tars registry:"
echo "   npx shadcn@latest add \"<registry-url>/<component>\""
echo ""

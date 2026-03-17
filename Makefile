# ==============================================================================
# tars-workspace Makefile
# ==============================================================================

WORKSPACE_ROOT := $(shell pwd)
SCRIPTS := $(WORKSPACE_ROOT)/scripts

REGISTRY_URL := https://fabiosol.github.io/tars-workspace

.PHONY: help new list clean dev build test registry-build registry-serve registry-list approved

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# --- Project scaffolding ---

new: ## Create a new project: make new name=my-app [repo=my-app]
	@if [ -z "$(name)" ]; then echo "Usage: make new name=<project-name> [repo=<github-repo>]"; exit 1; fi
	@bash $(SCRIPTS)/create-project.sh $(name) $(if $(repo),--repo $(repo),)

list: ## List all projects
	@echo "Projects:"
	@ls -1 projects/ 2>/dev/null || echo "  (none)"

dev: ## Run dev server: make dev name=my-app
	@if [ -z "$(name)" ]; then echo "Usage: make dev name=<project-name>"; exit 1; fi
	@cd projects/$(name) && npm run dev

build: ## Build project: make build name=my-app
	@if [ -z "$(name)" ]; then echo "Usage: make build name=<project-name>"; exit 1; fi
	@cd projects/$(name) && npm run build

test: ## Run Playwright tests: make test name=my-app
	@if [ -z "$(name)" ]; then echo "Usage: make test name=<project-name>"; exit 1; fi
	@cd projects/$(name) && npm run test:e2e

clean: ## Remove a project: make clean name=my-app
	@if [ -z "$(name)" ]; then echo "Usage: make clean name=<project-name>"; exit 1; fi
	@echo "This will delete projects/$(name). Are you sure? [y/N]"
	@read confirm && [ "$$confirm" = "y" ] && rm -rf projects/$(name) && echo "Deleted." || echo "Cancelled."

# --- Registry ---

registry-build: ## Build registry JSON files from source
	@echo "Building registry..."
	@node $(SCRIPTS)/build-registry.js

registry-serve: registry-build ## Build and serve the registry locally (port 5555)
	@echo "Serving registry at http://localhost:5555"
	@echo "Add components with: npx shadcn@latest add http://localhost:5555/<component-name>.json"
	@cd registry/dist && npx --yes serve -l 5555 -C

registry-list: ## Show all registry components with install commands
	@node -e "\
		const r=JSON.parse(require('fs').readFileSync('registry/registry.json','utf8'));\
		console.log('Registry components:\n');\
		r.items.forEach(i=>{\
			console.log('  '+i.name);\
			console.log('    '+i.description);\
			console.log('    npx shadcn@latest add $(REGISTRY_URL)/'+i.name+'.json\n');\
		});\
	"

# --- Approved components ---

approved: ## Show approved shadcn components
	@node -e "const d=JSON.parse(require('fs').readFileSync('approved-components.json','utf8')); d.components.forEach(c=>console.log('  ' + c.name.padEnd(20) + c.note))"

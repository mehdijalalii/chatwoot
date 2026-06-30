# Variables
APP_NAME := chatwoot
RAILS_ENV ?= development

# Targets
setup:
	gem install bundler
	bundle install
	pnpm install

db_create:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:create

db_migrate:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:migrate

db_seed:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:seed

db_reset:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:reset

db:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:chatwoot_prepare

console:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails console

server:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails server -b 0.0.0.0 -p 3000

burn:
	bundle && pnpm install

run:
	@if [ -f ./.overmind.sock ]; then \
		echo "Overmind is already running. Use 'make force_run' to start a new instance."; \
	else \
		overmind start -f Procfile.dev; \
	fi

force_run:
	@echo "Cleaning up Overmind processes..."
	@lsof -ti:3036 2>/dev/null | xargs kill -9 2>/dev/null || true
	@lsof -ti:3000 2>/dev/null | xargs kill -9 2>/dev/null || true
	@rm -f ./.overmind.sock
	@rm -f tmp/pids/*.pid
	@echo "Cleanup complete"
	overmind start -f Procfile.dev

force_run_tunnel:
	lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid
	overmind start -f Procfile.tunnel

debug:
	overmind connect backend

debug_worker:
	overmind connect worker

docker: 
	docker build -t $(APP_NAME) -f ./docker/Dockerfile .

backup: ## Dump current database to backups/
	@mkdir -p backups
	@pg_dump -U mehdi -d chatwoot_dev > backups/chatwoot.sql
	@echo "Backup saved to backups/chatwoot.sql"

deploy: ## Start Docker and auto-restore backup if DB is empty
	docker compose up -d
	@echo "Waiting for PostgreSQL..."
	@until docker compose exec postgres pg_isready -q -U postgres 2>/dev/null; do sleep 1; done
	@echo "PostgreSQL is ready."
	@TABLES=$$(docker compose exec postgres psql -U postgres -d chatwoot -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null); \
	if [ "$$TABLES" = "0" ] && [ -f backups/chatwoot.sql ]; then \
		echo "Database is empty, restoring from backup..."; \
		docker compose exec -T postgres psql -U postgres -d chatwoot < backups/chatwoot.sql; \
		echo "Restore complete."; \
	else \
		echo "Database has $$TABLES tables, skipping restore."; \
	fi
	@echo "Deploy finished."

.PHONY: setup db_create db_migrate db_seed db_reset db console server burn docker run force_run force_run_tunnel debug debug_worker backup deploy

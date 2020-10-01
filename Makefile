default:
	@echo Please specify target name!
up:
	docker-compose up -d
build:
	docker-compose build --no-cache --force-rm
create-project:
	mkdir -p ./infrastructure/docker/php/bash/psysh
	touch ./infrastructure/docker/php/bash/.bash_history
	@make build
	@make up
	docker-compose exec app composer create-project --prefer-dist laravel/laravel .
init:
	mkdir -p ./infrastructure/docker/php/bash/psysh
	touch ./infrastructure/docker/php/bash/.bash_history
	docker-compose up -d --build
	docker-compose exec app composer install
	docker-compose exec app cp .env.example .env
	docker-compose exec app php artisan key:generate
	docker-compose exec app php artisan passport:keys
	docker-compose exec app php artisan storage:link
	docker-compose exec app php artisan migrate:fresh --seed
remake:
	@make destroy
	@make init
stop:
	docker-compose stop
down:
	docker-compose down
restart:
	@make down
	@make up
destroy:
	docker-compose down --rmi all --volumes
destroy-volumes:
	docker-compose down --volumes
ps:
	docker-compose ps
logs:
	docker-compose logs
logs-watch:
	docker-compose logs --follow
web:
	docker-compose exec web ash
app:
	docker-compose exec app bash
migrate:
	docker-compose exec app php artisan migrate
fresh:
	docker-compose exec app php artisan migrate:fresh
seed:
	docker-compose exec app php artisan db:seed
tinker:
	docker-compose exec app php artisan tinker
test:
	docker-compose exec app php artisan test
optimize:
	docker-compose exec app php artisan optimize
optimize-clear:
	docker-compose exec app php artisan optimize:clear
cache:
	docker-compose exec app composer dump-autoload -o
	@make optimize
cache-clear:
	@make optimize-clear
# yarn:
# 	docker-compose exec web yarn
# yarn-dev:
# 	docker-compose exec web yarn run dev
# yarn-generate:
# 	docker-compose exec web yarn run generate
# yarn-watch:
# 	docker-compose exec web yarn run watch
# yarn-watch-poll:
# 	docker-compose exec web yarn run watch-poll
# yarn-hot:
# 	docker-compose exec web yarn run hot
# db:
# 	docker-compose exec db bash
# mysql:
# 	docker-compose exec db bash -c 'mysql -u $$MYSQL_USER -p$$MYSQL_PASSWORD $$MYSQL_DATABASE'
# redis:
# 	docker-compose exec redis redis-cli
# ide-helper:
# 	docker-compose exec app php artisan clear-compiled
# 	docker-compose exec app php artisan ide-helper:generate
# 	docker-compose exec app php artisan ide-helper:meta
# 	docker-compose exec app php artisan ide-helper:models --nowrite
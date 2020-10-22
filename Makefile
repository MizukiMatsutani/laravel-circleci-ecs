include .env
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
ecr-deploy-app:
	docker-compose build app
	docker tag ${COMPOSE_PROJECT_NAME}_app:latest ${AWS_ECR_ACCOUNT_URL}/sample-php-fpm:latest
	docker push ${AWS_ECR_ACCOUNT_URL}/sample-php-fpm:latest
ecr-deploy-web:
	docker-compose build web
	docker tag ${COMPOSE_PROJECT_NAME}_web:latest ${AWS_ECR_ACCOUNT_URL}/sample-nginx:latest
	docker push ${AWS_ECR_ACCOUNT_URL}/sample-nginx:latest
ecr-deploy:
	@make ecr-deploy-app
	@make ecr-deploy-web
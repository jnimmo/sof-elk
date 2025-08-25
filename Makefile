# SOF-ELK Docker Makefile

.PHONY: help build up down logs clean test single multi status

# Default target
help:
	@echo "SOF-ELK Docker Commands:"
	@echo "  pull     - Pull latest Docker images"
	@echo "  up       - Run SOF-ELK with official images (recommended)"
	@echo "  test-elk - Run quick test with official images"
	@echo "  down     - Stop and remove containers"
	@echo "  logs     - Show container logs"
	@echo "  status   - Show container status"
	@echo "  health   - Test service health"
	@echo "  clean    - Remove containers and volumes"
	@echo "  restart  - Restart services"

# Pull images (no build needed with official images)
pull:
	docker-compose pull

# Main deployment using official images
up:
	docker-compose up -d
	@echo "SOF-ELK starting with official Elastic images..."
	@echo "This may take several minutes for initialization."
	@echo "Access Kibana at: http://localhost:5601"
	@echo "Access Elasticsearch at: http://localhost:9200"

# Stop containers
down:
	docker-compose down

# Show logs
logs:
	docker-compose logs -f

# Show status
status:
	docker-compose ps
	@echo ""
	@echo "Health Status:"
	@docker-compose exec -T sof-elk-elasticsearch curl -s http://localhost:9200/_cluster/health 2>/dev/null | jq .status || echo "Elasticsearch: Not responding"

# Test health
health:
	@echo "Testing SOF-ELK services..."
	@docker run --rm --network host curlimages/curl:latest curl -f http://localhost:9200/_cluster/health || echo "Elasticsearch: FAIL"
	@docker run --rm --network host curlimages/curl:latest curl -f http://localhost:5601/api/status || echo "Kibana: FAIL"
	@docker run --rm --network host curlimages/curl:latest curl -f http://localhost:9600 || echo "Logstash: FAIL"

# Clean up everything
clean:
	docker-compose down -v --remove-orphans
	docker system prune -f

# Restart services
restart:
	docker-compose restart

# Development commands
dev-build:
	docker-compose build --no-cache

dev-logs:
	docker-compose logs -f --tail=100

# Data management
backup:
	@echo "Creating backup of SOF-ELK data..."
	docker run --rm -v sof-elk_elasticsearch_data:/data -v $(PWD):/backup alpine \
		tar czf /backup/sof-elk-backup-$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "Backup created in current directory"

# Quick setup for testing
quick-test: build single
	@echo "Waiting for services to start..."
	@sleep 30
	@make test
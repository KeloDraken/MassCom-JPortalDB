pyenv:
	./scripts/set_python.sh;
	
db:
	./scripts/start_postgres.sh;

syncsql:
	./scripts/generate_jportal.sh;

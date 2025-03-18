@echo off
set WORKDIRDEVOPS=D:/dev/workspaces/HelloDevop

echo Definition du repertoire de travail : %WORKDIRDEVOPS%

echo Verification de Docker...
docker ps >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Docker n'est pas lance. Ouvre Docker Desktop puis relance ce script.
    exit /b
)

echo Suppression des anciens conteneurs...
docker rm -f postgres-db 2>nul

echo Demarrage de PostgreSQL avec volume persistant...
docker run --name postgres-db ^
  -e POSTGRES_USER=user ^
  -e POSTGRES_PASSWORD=password ^
  -e POSTGRES_DB=mydb ^
  -p 5432:5432 ^
  -v pgdata:/var/lib/postgresql/data ^
  -v "%WORKDIRDEVOPS%\init-db.sql:/docker-entrypoint-initdb.d/init-db.sql" ^
  -d --restart=always postgres

echo PostgreSQL est en cours d'execution !
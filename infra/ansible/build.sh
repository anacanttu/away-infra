#!/usr/bin/env bash
# Compila o backend (war executável) e o frontend (Angular) NA SUA MÁQUINA.
# Clona os repositórios em ./build (cópia de trabalho; seus repositórios locais não são tocados).
# Uso: ./build.sh            (usa https://away.aidados.co)
#      APP_URL=https://outro.dominio ./build.sh
set -euo pipefail
cd "$(dirname "$0")"
APP_URL="${APP_URL:-https://away.aidados.co}"
mkdir -p build

[ -d build/backend ]  || git clone --depth 1 https://github.com/anacanttu/Backend-AWAY  build/backend
[ -d build/frontend ] || git clone --depth 1 https://github.com/anacanttu/Frontend-AWAY build/frontend

echo ">> Backend (Maven dentro do Docker; não depende do Java instalado no Mac)"
docker run --rm -v "$PWD/build/backend":/app -v away-m2-cache:/root/.m2 -w /app \
  maven:3.9-eclipse-temurin-17 mvn -q clean package -DskipTests

echo ">> Frontend (Angular) apontando para ${APP_URL}/api"
cd build/frontend
sed -i.bak -E "s#apiUrl: '[^']*'#apiUrl: '${APP_URL}/api'#" src/environments/environment.prod.ts
npm ci
npm run build:prod

echo "Pronto:"
ls ../backend/target/away-0.0.1-SNAPSHOT.war
ls dist/away-sistema-patronato/browser | head -3

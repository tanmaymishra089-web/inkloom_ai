# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim AS frontend
WORKDIR /src
COPY frontend/package.json frontend/package-lock.json ./
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca; fi; \
    npm ci
COPY frontend/ ./
RUN npm run build

FROM python:3.11.12-slim
WORKDIR /app
COPY backend/requirements.txt ./
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export PIP_CERT=/run/secrets/proxy_ca; fi; \
    pip install --no-cache-dir -r requirements.txt
COPY --chown=10001:10001 backend/ ./
COPY --from=frontend --chown=10001:10001 /src/dist /app/frontend_dist
COPY --chown=10001:10001 scripts/start_release.py /app/start_release.py
ENV FRONTEND_DIST=/app/frontend_dist EXPOSE_API_DOCS=false DEMO_COOKIE_SECURE=true PYTHONUNBUFFERED=1
USER 10001:10001
EXPOSE 8000
CMD ["python", "/app/start_release.py"]

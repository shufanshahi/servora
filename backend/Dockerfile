# syntax=docker/dockerfile:1

# ---- build stage: compile TypeScript ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build

# ---- runtime stage: production dependencies and compiled output only ----
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY src/db/migrations ./src/db/migrations
COPY --chmod=755 docker-entrypoint.sh ./docker-entrypoint.sh

# Run as the unprivileged user that ships with the node image.
USER node
EXPOSE 3000
# No secrets are baked into the image: all configuration arrives as environment variables.
ENTRYPOINT ["./docker-entrypoint.sh"]

# syntax=docker/dockerfile:1.7
# ---- deps: install all dependencies once (cached layer) ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# ---- dev: used by the test runner (full sources + dev dependencies) ----
FROM deps AS dev
COPY . .
CMD ["npm", "run", "dev"]

# ---- build: compile TypeScript ----
FROM deps AS build
COPY . .
RUN npm run build

# ---- runtime: production dependencies + compiled output ----
FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm install --no-save tsx@^4 && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY db ./db
COPY scripts ./scripts
COPY src ./src
COPY tsconfig.json ./
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x ./docker-entrypoint.sh && mkdir -p /data/uploads && chown -R node:node /app /data
USER node
EXPOSE 4000
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["node", "dist/server.js"]

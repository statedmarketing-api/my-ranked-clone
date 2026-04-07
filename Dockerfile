# ---------- Builder ----------
FROM node:20-alpine AS builder
WORKDIR /app

# ---- Install backend dependencies (NestJS + Prisma) ----
COPY backend/package*.json ./
RUN npm ci

# ---- Copy the whole backend source and compile it ----
COPY backend/ .
RUN npx prisma generate && npm run build   # creates ./dist

# ---------- Runtime ----------
FROM alpine:3.18 AS runtime
# Install ffmpeg (needed by the background worker) and dumb‑init for proper signal handling
RUN apk add --no-cache ffmpeg dumb-init

WORKDIR /app
# Copy compiled NestJS code and node_modules from the builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma

# Also copy the worker source (the worker will be started in a separate Render service)
COPY worker ./worker

ENV NODE_ENV=production
EXPOSE 3001

# Render will override the command:
#   • Web Service → `node dist/main.js`
#   • Background Worker → `node worker/src/worker.js`
ENTRYPOINT ["dumb-init", "--"]

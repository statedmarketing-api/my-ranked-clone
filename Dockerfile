# --------------------------------------------------------------
#  1️⃣ Builder stage – compile NestJS, generate Prisma client, build TS
# --------------------------------------------------------------
FROM node:20-slim AS builder               # <-- this is the base image and the stage name

WORKDIR /app

# ---- Install OS packages needed to compile native modules (python, make, g++) ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy only the package‑json files first (caches this layer on rebuilds) ----
COPY backend/package*.json ./

# ---- Install **all** dependencies (dev‑deps are needed for Prisma) ----
RUN npm ci

# ---- Copy the rest of the backend source code ----
COPY backend/ .

# ---- Generate Prisma client and compile the NestJS TypeScript sources ----
RUN npx prisma generate && npm run build   # creates ./dist

# --------------------------------------------------------------
#  2️⃣ Runtime stage – the image that Render will actually run
# --------------------------------------------------------------
FROM node:20-slim AS runtime               # <-- a fresh, thin image for running

WORKDIR /app

# ---- Install only runtime system packages (ffmpeg for video processing,
#      dumb‑init for proper PID‑1 handling) ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg dumb-init && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy compiled output and node_modules from the **builder** stage ----
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma

# ---- Also copy the worker source (the same image is used for the background worker) ----
COPY worker ./worker

EXPOSE 3001

# Render will set the actual command:
#   • API service (web) → `node dist/main.js`
#   • Background worker → `node worker/src/worker.js`
ENTRYPOINT ["dumb-init", "--"]

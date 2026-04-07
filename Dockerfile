#--------------------------------------------------------------
#  1️⃣ Builder stage – compile NestJS + Prisma
#--------------------------------------------------------------
FROM node:20-slim AS builder          # Debian‑based (glibc) Node image

# set a working directory inside the container
WORKDIR /app

# Install OS packages needed to compile native modules (Python, make, g++)
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

# Copy only the package files first – this caches the layer when dependencies don't change
COPY backend/package*.json ./

# Install *all* dependencies (including devDeps needed for Prisma)
RUN npm ci

# Copy the rest of the backend source code
COPY backend/ .

# Generate Prisma client and compile the TypeScript sources
RUN npx prisma generate && npm run build   # creates ./dist

#--------------------------------------------------------------
#  2️⃣ Runtime stage – the image that Render actually runs
#--------------------------------------------------------------
FROM node:20-slim AS runtime          # same base image, but much smaller

# working directory for the runtime container
WORKDIR /app

# Install only what the runtime needs: ffmpeg (for video processing) and dumb‑init (proper PID 1 handling)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg dumb-init && \
    rm -rf /var/lib/apt/lists/*

# Copy the compiled app and its node_modules from the builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma

# Also copy the worker source (Render will start this container with a different command)
COPY worker ./worker

# expose the port the NestJS API listens on (Render forwards 443 → 3001 automatically)
EXPOSE 3001

# Render will override the command:
#   • API container → `node dist/main.js`
#   • Worker container → `node worker/src/worker.js`
ENTRYPOINT ["dumb-init", "--"]

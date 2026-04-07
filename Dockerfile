FROM node:20-slim
WORKDIR /app
# Install OS packages needed to compile native modules (python, make, g++)
RUN apt-get update && \
apt-get install -y --install-recommends python3 make g++ && \
rm -rf /var/lib/apt/lists/*

# Copy only the package-json files first (catches this layer on rerbuilds)
COPY backend/package*.json ./

# Install all dependencies (dev deps are needed for Prisma)
RUN npm ci 

# Copy the rest of the backend source
COPY backend/ .

# Generate Prisma client and compile the NestJS TypeScript sources
RUN npx prisma generate && npm run build   #creates ./dist

# Runtime Packages (ffmpeg for the worker, dumb-init for proper PID handling)
RUN apt-get update && \
apt-get install -y --no-install-recommeds ffmpeg dumb-inint && \
rm -rf /var/lib/apt/lists/*

# ---- Copy the compiled app and its node_modules from the builder stage ----
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma

# Copy the worker source (the same image is used for the background worker)
COPY worker ./worker

EXPOSE 3001
ENTRYPOINT ["dumb-init",   "--"]

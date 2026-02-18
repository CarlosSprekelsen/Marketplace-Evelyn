# Stage 1: Build (has ALL dependencies including dev)
FROM node:22-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src/ src/

RUN npm run build

# Stage 2: Test (reuses builder — has jest and all dev deps)
FROM builder AS test
CMD ["npm", "run", "test", "--", "--runInBand"]

# Stage 3: Production (lean — no dev deps)
FROM node:22-alpine AS production
WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /app/dist ./dist

USER node

EXPOSE 3000

CMD ["node", "dist/main.js"]

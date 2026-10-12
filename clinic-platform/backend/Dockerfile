FROM node:22-alpine
WORKDIR /app
COPY . .
RUN npm ci && npm run build -w backend
USER node
EXPOSE 3000
CMD ["node", "backend/dist/server.js"]

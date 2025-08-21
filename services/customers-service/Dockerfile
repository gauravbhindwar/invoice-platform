FROM node:20-alpine
WORKDIR /app
COPY packages/common /packages/common
RUN npm install --prefix /packages/common --omit=dev

COPY services/customers-service/package.json ./
COPY services/customers-service/src ./src
RUN npm install --omit=dev

ENV NODE_ENV=production
EXPOSE 3003
CMD ["node", "src/server.js"]
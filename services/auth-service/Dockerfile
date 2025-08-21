FROM node:20-alpine
WORKDIR /app
# copy local common package into image so file: dependency resolves
COPY packages/common /packages/common


# copy package.json and source, then install to avoid host lockfile interference
COPY services/auth-service/package.json ./
COPY services/auth-service/src ./src
RUN npm install --omit=dev

ENV NODE_ENV=production
EXPOSE 3001
CMD ["node", "src/server.js"]
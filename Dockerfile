# syntax=docker/dockerfile:1     
# syntax declare the Dockerfile version to use for the build

ARG NODE_VERSION=18.0.0   
# An ARG is a variable
# An ARG declared before a FROM is outside of a build stage.

FROM node:${NODE_VERSION}-alpine AS base    
# A FROM sets the base image
# A valid Dockerfile must start with a FROM instruction.
# A name can be given to a new build stage by adding AS name to the FROM instruction.

WORKDIR /usr/src/app
# The WORKDIR directive sets the execution path for any RUN, CMD, ENTRYPOINT, COPY, and ADD instructions

EXPOSE 3000
# Expose the port that the application listens on.

FROM base AS dev
# A FORM can use one build stage as a dependency for another.
# Each FROM clears any state created by previous instructions.

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    # Type bind allows binding file or directorie sources path to the container target path
    --mount=type=cache,target=/root/.npm \
    # Cache directories for compilers and package managers.
    npm ci --include=dev

USER node
# Set USER for secure https://www.docker.com/blog/understanding-the-docker-user-instruction/#:~:text=The%20USER%20instruction%20in%20a,can%20pose%20significant%20security%20risks.

COPY . .

CMD npm run dev

# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /root/.npm to speed up subsequent builds.
# Leverage a bind mounts to package.json and package-lock.json to avoid having to copy them into
# into this layer.

FROM base AS prod

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

# Run the application as a non-root user.
USER node

# Copy the rest of the source files into the image.
COPY . .

# Run the application.
CMD  node src/index.js

# Create a new test image from test stage
FROM base AS test
ENV NODE_ENV=test
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --include=dev
USER node
COPY . .
RUN npm run test
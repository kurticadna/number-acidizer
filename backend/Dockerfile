# Use the official AWS Lambda Node.js 18 base image
FROM public.ecr.aws/lambda/nodejs:18

# Set the working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/
COPY tsconfig.json ./

# Install dev dependencies and build
RUN npm install --save-dev typescript @types/node @types/aws-lambda && \
    npm run build && \
    npm prune --production

# Copy built files to Lambda task root
RUN cp -r dist/* ./ && rm -rf dist src tsconfig.json

# Ensure the handler file is executable
RUN chmod 755 handler.js

# Set the CMD to your handler
CMD [ "handler.handler" ]
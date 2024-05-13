# Use a Ruby base image
FROM ruby:latest

# Set the working directory inside the container
WORKDIR /app

ARG BUNDLE_GEMFILE=./gems/rails.gemfile


# # Copy the entire project directory into the container
COPY . .

# Remove any local .lock files after copying
RUN find . -type f -name "*.lock" -exec rm -f {} \;

# Install dependencies
RUN bundle install

ENV BUNDLE_GEMFILE=./gems/rails.gemfile

# Use a Ruby base image
ARG RUBY_VERSION=3.3
FROM ruby:$RUBY_VERSION

# Set the working directory inside the container
WORKDIR /app

ARG BUNDLE_GEMFILE=./gems/rails.gemfile

ENV VERSIONED_GEMFILE="$BUNDLE_GEMFILE.$RUBY_VERSION"
# # Copy the entire project directory into the container
COPY ./gems/rails.gemfile ./gems/rails.gemfile.$RUBY_VERSION
COPY . .

# Remove any local .lock files after copying
RUN find . -type f -name "*.lock" -exec rm -f {} \;

# Install dependencies
RUN bundle install

ENV BUNDLE_GEMFILE=$VERSIONED_GEMFILE

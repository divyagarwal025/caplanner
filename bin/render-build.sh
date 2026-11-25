#!/usr/bin/env bash
set -o errexit

bundle install

# Prepare primary database
bundle exec rails db:prepare

# Explicitly load secondary database schemas
bundle exec rails db:schema:load:queue
bundle exec rails db:schema:load:cable
bundle exec rails db:schema:load:cache

# Assets
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Seed data
bundle exec rails db:seed
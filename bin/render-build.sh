#!/usr/bin/env bash
set -o errexit

bundle install

# Prepare primary database
bundle exec rails db:prepare

# Assets
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Seed data
bundle exec rails db:seed
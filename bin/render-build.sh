#!/usr/bin/env bash
# Render build script. Installs gems, precompiles assets, prepares the DB
# (creates + loads schema for the primary DB and the Solid cache/queue/cable
# schemas) on the Supabase Postgres pointed to by DATABASE_URL.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Creates the database if missing, loads schema, runs pending migrations, and
# loads the Solid cache/queue/cable schemas into the same Postgres database.
bundle exec rails db:prepare

# Seeds the EXACT current domain data from db/seed_data.rb (subjects, revision
# topics, milestones, tasks, the 48 day-plan items + progress) and fetches the
# RubyLLM model catalog. Idempotent — upserts by natural keys, safe to re-run.
# Set SEED_USER_EMAIL / SEED_USER_PASSWORD in the environment for the user login.
bundle exec rails db:seed

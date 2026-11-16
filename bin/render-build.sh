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

# Seed CA Final subjects/goals only if the subjects table is empty (idempotent).
bundle exec rails db:seed

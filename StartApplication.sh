#!/usr/bin/env bash

bundle install
rm -f /rails/tmp/pids/server.pid

bin/dev

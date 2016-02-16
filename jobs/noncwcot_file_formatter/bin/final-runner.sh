#!/usr/bin/env bash

export RUNNER_PATH=/path/to/adc-ruby-scripts
export JOB_ORDER=Final

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

cd ~/path/to/adc-ruby-scripts/jobs/noncwcot_file_formatter/bin/
ruby noncwcot_file_formatter-runner.rb

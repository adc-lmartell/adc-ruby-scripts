#!/usr/bin/env bash

export RUNNER_PATH=/path/to/adc-ruby-scripts
export SELLER_MATRIX=SellerCodeMatrix.csv
export SELLER_DATATAPE=SellerDataTape.csv
export ASSET_LOAD=NonCWCOT-AssetLoad.csv

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

cd ~/path/to/adc-ruby-scripts/jobs/noncwcot_file_formatter/bin/
ruby noncwcot_file_formatter-runner.rb

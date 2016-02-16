#!/usr/bin/env bash

export RUNNER_PATH=/Users/Kelsen23/Documents/Ruby/Scripts/adc-ruby-scripts
export SELLER_MATRIX=SellerCodeMatrix.csv
export SELLER_DATATAPE=SellerDataTape.csv
export ASSET_LOAD=NonCWCOT-AssetLoad.csv

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

cd ~/Documents/Ruby/Scripts/adc-ruby-scripts/jobs/noncwcot_file_formatter/bin/
ruby noncwcot_file_formatter-runner.rb

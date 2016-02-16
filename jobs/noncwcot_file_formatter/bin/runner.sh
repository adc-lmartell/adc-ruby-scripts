#!/usr/bin/env bash

export RUNNER_PATH=
export SF_PROD_URL=
export SF_PROD_USER=
export SF_PROD_PWD=
export SF_PROD_TOKEN=
export SF_PROD_CID=
export SF_PROD_CLS=
export SELLER_MATRIX=SellerCodeMatrix.csv
export SELLER_DATATAPE=SellerDataTape.csv
export ASSET_LOAD=NonCWCOT-AssetLoad.csv

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

cd ~/path/to/adc-ruby-scripts/jobs/noncwcot_file_formatter/bin/
ruby noncwcot_file_formatter-runner.rb

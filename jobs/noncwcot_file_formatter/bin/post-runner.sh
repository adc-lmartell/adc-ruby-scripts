#!/usr/bin/env bash

export RUNNER_PATH=/path/to/adc-ruby-scripts
<<<<<<< HEAD:jobs/noncwcot_file_formatter/bin/post-runner.sh
export SF_PROD_URL=
export SF_PROD_USER=
export SF_PROD_PWD=
export SF_PROD_TOKEN=
export SF_PROD_CID=
export SF_PROD_CLS=
=======
export SELLER_MATRIX=SellerCodeMatrix.csv
export SELLER_DATATAPE=SellerDataTape.csv
>>>>>>> origin/master:jobs/noncwcot_file_formatter/bin/runner.sh
export ASSET_LOAD=NonCWCOT-AssetLoad.csv
export REO_AUC_LOAD=NonCWCOT-ReoAucLoad.csv
export JOB_ORDER=Post

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

cd ~/path/to/adc-ruby-scripts/jobs/noncwcot_file_formatter/bin/
ruby noncwcot_file_formatter-runner.rb

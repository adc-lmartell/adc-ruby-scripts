#!/usr/bin/env bash

export RUNNER_PATH=/Users/Kelsen23/Documents/Ruby/Scripts/adc-ruby-scripts
export SF_PROD_URL=
export SF_PROD_USER=lmartell@auction.com
export SF_PROD_PWD=L!11kM234
export SF_PROD_TOKEN=5o1MxJrZZQ0KupiMMthv2xzG
export SF_PROD_CID=3MVG9iTxZANhwHQt0j0oOGc9BodRJK74qbBIve_2lqR_vPBrpJMmz_scGKKTjqztvfmtPtBSLTfH5.tW3YVg3
export SF_PROD_CLS=2798385460059144056
export ASSET_LOAD=NonCWCOT-AssetLoad.csv
export REO_AUC_LOAD=NonCWCOT-ReoAucLoad.csv

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

cd ~/Documents/Ruby/Scripts/adc-ruby-scripts/jobs/noncwcot_post_file_formatter/bin/
ruby noncwcot_post_file_formatter-runner.rb

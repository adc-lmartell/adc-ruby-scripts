#!/bin/bash

export SF_PROD_CLS=2798385460059144056
export SF_PROD_USER=kdavis@auction.com
export SF_PROD_PWD="Rockdog5#"
export SF_PROD_TOKEN=KGwlhT2gmxizo59JmTzTXpK47
export SF_PROD_CID=3MVG9iTxZANhwHQt0j0oOGc9BodRJK74qbBIve_2lqR_vPBrpJMmz_scGKKTjqztvfmtPtBSLTfH5.tW3YVg3
export RUNNER_PATH=/home/salesfuser/Git/adc-ruby-scripts
export tSHELL=bin/bash
export rvm_path=/home/salesfuser/.rvm
export rvm_bin_path=/home/salesfuser/.rvm/bin
export rvm_prefix=/home/salesfuser
export GEM_PATH=/home/salesfuser/.rvm/gems/ruby-1.9.3-p551:/home/salesfuser/.rvm/gems/ruby-1.9.3-p551@global
export GEM_HOME=/home/salesfuser/.rvm/gems/ruby-1.9.3-p551
export MY_GEM_HOME=/home/salesfuser/.rvm/rubies/ruby-1.9.3-p551
export RUBY_VERSION=ruby-1.9.3-p551
export rvm_version=1.26.10

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" #Load RVM into shell session as function

rvm use 1.9.3-p551


cd /home/salesfuser/Git/adc-ruby-scripts/jobs/auction_seller_update/bin/
ruby auction_seller_update-runner.rb

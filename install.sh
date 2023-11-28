# use homebrew's ruby / gem version

. ./env.sh
gem install jekyll
# maybe remove the lock file
bundle install
bundle add webrick


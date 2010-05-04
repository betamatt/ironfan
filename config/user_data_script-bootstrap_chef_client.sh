#!/usr/bin/env bash
progresslog='/tmp/user_data-progress.log'

# A url directory with the scripts you'd like to stuff into the machine
REMOTE_FILE_URL_BASE="<%= bootstrap_scripts_url_base %>"

echo "`date` Broaden the apt universe" >> $progresslog
add-apt-repository 'deb http://archive.canonical.com/ <%= ubuntu_version %> partner'
add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu <%= ubuntu_version %> universe multiverse'

# wait for system dpkg to finish
while sudo fuser /var/lib/dpkg/lock ; do echo "`date` Waiting for apt to become free" >> $progresslog ;  sleep 5 ; done  

# Update package index and update the basic system files to newest versions
echo "`date` Apt update"  >> $progresslog 
apt-get -y update  ;
dpkg --configure -a
echo "`date` Apt upgrade, could take a while"  >> $progresslog 
apt-get -y upgrade ;
echo "`date` Apt install"  >> $progresslog 
apt-get -f install ;

echo "`date` Installing base packages"  >> $progresslog 
apt-get install -y ruby ruby1.8-dev libopenssl-ruby1.8 rubygems ri irb build-essential wget ssl-cert git-core zlib1g-dev libxml2-dev runit runit-services;
runsvdir-start &
echo "`date` Unchaining rubygems from the tyrrany of ubuntu"  >> $progresslog 
gem install --no-rdoc --no-ri rubygems-update --version=1.3.6 ; /var/lib/gems/1.8/bin/update_rubygems; gem update --no-rdoc --no-ri --system ; gem --version ;

echo "`date` Installing chef gems"  >> $progresslog 
gem install --no-rdoc --no-ri chef broham configliere ;
gem list >> $progresslog

echo "`date` Hostname"  >> $progresslog 
# This patches the ec2-set-hostname script to use /etc/hostname (otherwise it
# crams the ec2-assigned hostname in there regardless)
cp /usr/bin/ec2-set-hostname /usr/bin/ec2-set-hostname.`date "+%Y%m%d%H"`.orig ;
wget -nv ${REMOTE_FILE_URL_BASE}/ec2-set-hostname_replacement.py -O /usr/bin/ec2-set-hostname ;
chmod a+x /usr/bin/ec2-set-hostname

echo "`date` Bootstrap chef client scripts"  >> $progresslog 
echo '{ "bootstrap": { "chef": { "server_fqdn":"<%= chef_server_fqdn %>", "url_type":"http", "init_style":"runit", "path":"/srv/chef", "serve_path":"/srv/chef" } }, "run_list": [ "recipe[bootstrap::client]" ] }' > /tmp/chef_client.json ;
wget -nv ${REMOTE_FILE_URL_BASE}/chef_bootstrap.rb -O /tmp/chef_bootstrap.rb ;
sudo stop runsvdir ;
chef-solo -c /tmp/chef_bootstrap.rb -j /tmp/chef_client.json  >> $progresslog 

# pull in the client scripts that make this machine speak to the chef server
cp /etc/chef/client.rb /etc/chef/client-orig.rb ;
wget -nv ${REMOTE_FILE_URL_BASE}/client.rb -O /etc/chef/client.rb ;

# cleanup
apt-get autoremove;
updatedb;

echo "User data script (generic chef client) complete: `date`"

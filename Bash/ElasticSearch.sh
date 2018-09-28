#!/bin/bash
clear
echo "Add the Oracle Java PPP to apt repository"
sudo add-apt-repository -y ppa:webupd8team/java

echo "Update your apt package database:"
sudo apt-get Update

echo "Install the latest version of Oracle JDK 8"
sudo apt-get -y install oracle-java8-installer

echo "Download and Install ElasticSearch"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
sudo apt-get update && sudo apt-get install elasticsearch
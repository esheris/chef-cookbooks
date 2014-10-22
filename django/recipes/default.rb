#
# Cookbook Name:: django
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

#include_recipe 'base'

file = node["django"]["s3_file"]
download_path = node["django"]["download_location"]
base_file = file.split('.')[0]

template_vars = {
  :root_dir => File.join(download_path, base_file),
  :application => base_file
}

directory download_path do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

amazon_web_services_s3 "#{download_path}/#{file}" do
  action :download_file
  s3_bucket node["django"]["s3_bucket"]
  s3_file_path file
end

amazon_web_services_s3 "#{download_path}/#{node["django"]["rpm_file"]}" do
  action :download_file
  s3_bucket node["django"]["rpm_bucket"]
  s3_file_path node["django"]["rpm_file"]
end

%w{python python-devel python-setuptools gcc}.each do |pkg|
  package pkg do
    action :install
  end
end

easy_install_package "pip" do
  action :install
end

cookbook_file "nginx.repo" do
  path "/etc/yum.repos.d/nginx.repo"
  action :create
end

package 'nginx' do
  action :install
end

cookbook_file "nginx.conf" do
  path "/etc/nginx/nginx.conf"
  action :create
end

package node["django"]["rpm_file"] do
  source "#{download_path}/#{node["django"]["rpm_file"]}"
  action :install
end

file "/etc/nginx/conf.d/default.conf" do
  action :delete
end

template "/etc/nginx/conf.d/nginx-app.conf" do
  source "nginx.erb"
  mode '0440'
  owner 'root'
  group 'root'
  variables template_vars
end

execute "tar xvf #{file}" do
  cwd "#{download_path}"
end

template "#{File.join(download_path, base_file)}/docker/runit/uwsgi/run" do
  source "run.erb"
  mode '0751'
  owner 'root'
  group 'root'
  variables template_vars
end

execute "pip install uwsgi"

execute "pip install -r requirements.txt" do
  cwd "#{download_path}/#{base_file}"
  only_if { ::File.exist?(File.join(download_path, base_file, "requirements.txt"))}
end

service "runit" do
  action :nothing
end

execute "/sbin/runsvdir runit/ &" do
  cwd "#{download_path}/#{base_file}/docker"
end

#
## Copyright:: Copyright (c) 2014 GitLab.com
## License:: Apache License, Version 2.0
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
## http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
#
account_helper = AccountHelper.new(node)

git_user = account_helper.gitlab_user
git_group = account_helper.gitlab_group
gitlab_shell_dir = "/opt/gitlab/embedded/service/gitlab-shell"
gitlab_shell_var_dir = "/var/opt/gitlab/gitlab-shell"
git_data_directories = node['gitlab']['gitlab-shell']['git_data_directories']
repositories_storages = node['gitlab']['gitlab-rails']['repositories_storages']
ssh_dir = File.join(node['gitlab']['user']['home'], ".ssh")
authorized_keys = node['gitlab']['gitlab-shell']['auth_file']
log_directory = node['gitlab']['gitlab-shell']['log_directory']
hooks_directory = node['gitlab']['gitlab-rails']['gitlab_shell_hooks_path']
gitlab_shell_keys_check = File.join(gitlab_shell_dir, 'bin/gitlab-keys')

git_data_directories.each do |_name, git_data_directory|
  storage_directory git_data_directory do
    owner git_user
    mode "0700"
  end
end

repositories_storages.each do |_name, repositories_storage|
  storage_directory repositories_storage do
    owner git_user
    mode "2770"
  end
end

[
  ssh_dir,
  File.dirname(authorized_keys)
].uniq.each do |dir|
  storage_directory dir do
    owner git_user
    group git_group
    mode "0700"
  end
end

# All repositories under GitLab share one hooks directory under
# /opt/gitlab. Git-Annex wants write access to this hook directory, but
# this directory is owned by root in the package.
directory hooks_directory do
  owner git_user
  group git_group
  mode "0755"
end

[
  log_directory,
  gitlab_shell_var_dir
].each do |dir|
  directory dir do
    owner git_user
    mode "0700"
    recursive true
  end
end

# If no internal_api_url is specified, default to the IP/port Unicorn listens on
api_url = node['gitlab']['gitlab-rails']['internal_api_url']
api_url ||= "http://#{node['gitlab']['unicorn']['listen']}:#{node['gitlab']['unicorn']['port']}#{node['gitlab']['unicorn']['relative_url']}"

redis_port = node['gitlab']['gitlab-rails']['redis_port']
if redis_port
  # Leave out redis socket setting because in gitlab-shell, setting a Redis socket
  # overrides TCP connection settings.
  redis_socket = nil
else
  redis_socket = node['gitlab']['gitlab-rails']['redis_socket']
end

templatesymlink "Create a config.yml and create a symlink to Rails root" do
  link_from File.join(gitlab_shell_dir, "config.yml")
  link_to File.join(gitlab_shell_var_dir, "config.yml")
  source "gitlab-shell-config.yml.erb"
  variables({
    :user => git_user,
    :api_url => api_url,
    :authorized_keys => authorized_keys,
    :redis_host => node['gitlab']['gitlab-rails']['redis_host'],
    :redis_port => redis_port,
    :redis_socket => redis_socket,
    :redis_password => node['gitlab']['gitlab-rails']['redis_password'],
    :redis_database => node['gitlab']['gitlab-rails']['redis_database'],
    :redis_sentinels => node['gitlab']['gitlab-rails']['redis_sentinels'],
    :log_file => File.join(log_directory, "gitlab-shell.log"),
    :log_level => node['gitlab']['gitlab-shell']['log_level'],
    :audit_usernames => node['gitlab']['gitlab-shell']['audit_usernames'],
    :http_settings => node['gitlab']['gitlab-shell']['http_settings'],
    :git_annex_enabled => node['gitlab']['gitlab-shell']['git_annex_enabled'],
    :git_trace_log_file => File.join(log_directory, 'gitlab-shell-git-trace.log')
  })
end

link File.join(gitlab_shell_dir, ".gitlab_shell_secret") do
  to "/opt/gitlab/embedded/service/gitlab-rails/.gitlab_shell_secret"
end

execute "#{gitlab_shell_keys_check} check-permissions" do
  user git_user
  group git_group
end

# If SELinux is enabled, make sure that OpenSSH thinks the .ssh directory and authorized_keys file of the
# git_user is valid.
bash "Set proper security context on ssh files for selinux" do
  code <<-EOS
    chcon --recursive --type ssh_home_t #{ssh_dir}
    chcon --type sshd_key_t #{authorized_keys}
  EOS
  only_if "id -Z"
end

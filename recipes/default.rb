# coding: UTF-8
#
# Cookbook Name:: serf
# Recipe:: default
#

# Initializes the SerfHelper class by giving it access to `node`
helper = SerfHelper.new self

# Create serf user/group
group node["serf"]["group"] do
  action :create
end.run_action(:create) if node['serf']['compiletime']

user node["serf"]["user"] do
  gid node["serf"]["group"]
  action :create
end.run_action(:create) if node['serf']['compiletime']

# Create serf directories

# /opt/serf
directory node["serf"]["base_directory"] do
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
  recursive true
  action :create
end.run_action(:create) if node['serf']['compiletime']

# /opt/serf/event_handlers
directory helper.getEventHandlersDirectory do
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
  recursive true
  action :create
end.run_action(:create) if node['serf']['compiletime']

# /opt/serf/bin
directory helper.getBinDirectory do
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
  recursive true
  action :create
end.run_action(:create) if node['serf']['compiletime']

# /opt/serf/config
directory helper.getHomeConfigDirectory do
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
  recursive true
  action :create
end.run_action(:create) if node['serf']['compiletime']

# /opt/serf/log
directory helper.getHomeLogDirectory do
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
  recursive true
  action :create
end.run_action(:create) if node['serf']['compiletime']

# Create unix expected directories (/etc/serf, /var/log/serf, ...)

# /var/log/serf
link node["serf"]["log_directory"] do
  to helper.getHomeLogDirectory
end.run_action(:create) if node['serf']['compiletime']

# /etc/serf
link node["serf"]["conf_directory"] do
  to helper.getHomeConfigDirectory
end.run_action(:create) if node['serf']['compiletime']

download_auth = Base64.encode64(
  "#{node["serf"]["download_user"]}:#{node["serf"]["download_pass"]}")

# Download binary zip file
remote_file helper.getZipFilePath do
  action :create
  source node["serf"]["binary_url"]
  group node["serf"]["group"]
  owner node["serf"]["user"]
  headers({"AUTHORIZATION" => "Basic #{download_auth}"})
  mode 00644
  backup false
end.run_action(:create) if node['serf']['compiletime']

# Make sure unzip is available to us
package "unzip" do
  action :install
end.run_action(:install) if node['serf']['compiletime']

# Unzip serf binary
execute "unzip serf binary" do

  user node["serf"]["user"]
  cwd helper.getBinDirectory

  # -q = quiet, -o = overwrite existing files
  command "unzip -qo #{helper.getZipFilePath}"

  notifies :restart, "service[serf]" unless node['serf']['compiletime']
  only_if do
    currentVersion = helper.getSerfInstalledVersion
    if currentVersion != node["serf"]["version"]
      Chef::Log.info "Changing Serf Installation from [#{currentVersion}] to [#{node["serf"]["version"]}]"
    end
    currentVersion != node["serf"]["version"]
  end
end.run_action(:run) if node['serf']['compiletime']

# Ensure serf binary has correct permissions
file helper.getSerfBinary do
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
end.run_action(:create) if node['serf']['compiletime']

# Add serf to /usr/bin so it is on our path
link "/usr/bin/serf" do
  to helper.getSerfBinary
end.run_action(:create) if node['serf']['compiletime']

# Add entry to logrotate.d to log roll agents log files daily
template "/etc/logrotate.d/serf_agent" do
  source  "serf_log_roll.erb"
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
  variables(:agent_log_file => helper.getAgentLog)
  backup false
end.run_action(:create) if node['serf']['compiletime']

# Download and configure specified event handlers
node["serf"]["event_handlers"].each do |event_handler|

  unless event_handler.is_a? Hash
    raise "Event handler [#{event_handler}] is required to be a hash"
  end

  event_handler_command = ""
  if event_handler.has_key? "event_type"
    event_handler_option << "#{event_handler["event_type"]}="
  end

  if event_handler.has_key? "url"
    event_handler_path =  File.join helper.getEventHandlersDirectory, File.basename(event_handler["url"])
    event_handler_command << event_handler_path

    # Download event handler script
    remote_file event_handler_path do
      source event_handler["url"]
      group node["serf"]["group"]
      owner node["serf"]["user"]
      mode 00755
      backup false
    end.run_action(:create) if node['serf']['compiletime']

  else
    raise "Event handler [#{event_handler}] has no 'url'"
  end

  node.default["serf"]["agent"]["event_handlers"] << event_handler_command
end

# Create serf_agent.json
template helper.getAgentConfig do
  source  "serf_agent.json.erb"
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode 00755
  variables( :agent_json => helper.getAgentJson)
  backup false
  notifies :restart, "service[serf]" unless node['serf']['compiletime']
end.run_action(:create) if node['serf']['compiletime']

# Create init.d script
template "/etc/init.d/serf" do
  source  "serf_service.erb"
  group node["serf"]["group"]
  owner node["serf"]["user"]
  mode  00755
  variables(:helper => helper)
  backup false
  notifies :restart, "service[serf]"  unless node['serf']['compiletime']
end.run_action(:create) if node['serf']['compiletime']

# Ensure everything is owned by serf user/group
execute "chown -R #{node["serf"]["user"]}:#{node["serf"]["group"]} #{node["serf"]["base_directory"]}" do
  action :run
end.run_action(:run) if node['serf']['compiletime']

# Start agent service
serf_service = service "serf" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end

if node['serf']['compiletime']
  serf_service.run_action(:enable)
  serf_service.run_action(:start)
else
  serf_service
end


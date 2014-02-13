ip_regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:\d{2,5})?$/


actions :join, :leave, :force_leave
default_action :join

attribute :address,     :kind_of => String,                    :name_attribute => true,      :regex => ip_regex
attribute :rpc_addr,    :kind_of => String,                    :default => '127.0.0.1:7373', :regex => ip_regex
attribute :replay,      :kind_of => [ TrueClass, FalseClass ], :default => false
attribute :serf_binary, :kind_of => String,                    :default => ::File.join(node["serf"]["base_directory"], "bin", "serf")

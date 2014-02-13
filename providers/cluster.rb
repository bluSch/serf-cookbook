require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut


def whyrun_supported?
  true
end

action :join do
   if @new_resource.address
      rpc_address_option = "-rpc-addr=#{@new_resource.rpc_addr}"
      replay_option = @new_resource.replay ? "-replay" : ''
      Chef::Log.info("Joining serf cluster at #{@new_resource.address} via #{@new_resource.rpc_addr}.")
      shell_out!("#{@new_resource.serf_binary} join #{rpc_address_option} #{replay_option} #{@new_resource.address}")
   else
      Chef::Log.error("Address required in order to join cluster.")
   end
end

action :leave do
   rpc_address_option = "-rpc-addr=#{@new_resource.rpc_addr}"
   Chef::Log.info "Leaving serf cluster."
   shell_out!("#{@new_resource.serf_binary} leave #{rpc_address_option}")
end

action :force_leave do
   if @new_resource.address
      rpc_address_option = "-rpc-addr=#{@new_resource.rpc_addr}"
      Chef::Log.info("Forcing #{@new_resource.address} to leave cluster via #{@new_resource.rpc_addr}.")
      shell_out!("#{@new_resource.serf_binary} force-leave #{rpc_address_option} #{@new_resource.address}")
   else
      Chef::Log.error("A node's address is required to force leave.")
   end
end

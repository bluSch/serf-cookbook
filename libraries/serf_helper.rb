# coding: UTF-8
require 'json'
require 'chef/mixin/shell_out'

include Chef::Mixin::ShellOut


class Chef::Recipe::SerfHelper < Chef::Recipe

  SERF_VERSION_REGEX = /^Serf v\d.\d.\d/
  VERSION_REGEX = /\d.\d.\d/

  # Initializes the helper class
  def initialize chefRecipe
    super(chefRecipe.cookbook_name, chefRecipe.recipe_name, chefRecipe.run_context)

    # TODO: Support other distributions besides 'linux'
    node.default["serf"]["binary_url"] = File.join node["serf"]["base_binary_url"], "#{node["serf"]["version"]}_linux_#{node["serf"]["arch"]}.zip"

    currentVersion = getSerfInstalledVersion
    if currentVersion
      Chef::Log.info "Current Serf Version : [#{currentVersion}]"
    end
  end

  def getBinDirectory
     File.join node["serf"]["base_directory"], "bin"
  end

  def getSerfBinary
    File.join getBinDirectory, "serf"
  end

  def getEventHandlersDirectory
    File.join node["serf"]["base_directory"], "event_handlers"
  end

  def getHomeConfigDirectory
    File.join node["serf"]["base_directory"], "config"
  end

  def getAgentConfig
    File.join getHomeConfigDirectory, "serf_agent.json"
  end

  def getHomeLogDirectory
    File.join node["serf"]["base_directory"], "logs"
  end

  def getAgentLog
    File.join getHomeLogDirectory, "agent.log"
  end

  def getAgentJson
    JSON.pretty_generate(node["serf"]["agent"].to_hash)
  end

  def getMembers(rpc_addr='127.0.0.1:7373')
    members_cmd = "#{getSerfBinary} members -rpc-addr=#{rpc_addr} -format=json"

    if `pgrep #{getSerfBinary}` == ''
      raise "Unable to get serf cluster members via #{rpc_addr}."
    end

    serf_members = shell_out!(members_cmd)

    begin
      JSON.parse(serf_members.stdout)
    rescue JSON::ParserError => err
      raise "Bad output from `serf members` command: #{err.message}"
    end
  end

  def getZipFilePath
    File.join Chef::Config[:file_cache_path], "serf-#{node["serf"]["version"]}_linux_#{node["serf"]["arch"]}.zip"
  end

  def getSerfInstalledVersion
    unless File.exists? getSerfBinary
      return "NONE"
    end

    versionOutput = `#{getSerfBinary} version`.chomp
    serfMatch = SERF_VERSION_REGEX.match(versionOutput)

    if serfMatch.size == 0
      raise "Unable to parse version from `serf version` output [#{versionOutput}]"
    end

    versionMatch = VERSION_REGEX.match(serfMatch[0])

    # Should never happen
    if versionMatch.size == 0
      raise "Unable to parse version from `serf version` output [#{versionOutput}]"
    end

    versionMatch[0]
  end

end

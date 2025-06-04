# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'yaml'

module WaniKaniTUI
  CONFIG_FILE = 'config.yml'

  # Provides helper methods for managing data directory
  class DataDir
    def self.ensure!
      FileUtils.mkdir_p(path)
    end

    def self.path
      data_home = if windows?
                    ENV['LOCALAPPDATA'] || File.join(ENV['USERPROFILE'], 'AppData', 'Local')
                  else
                    ENV['XDG_DATA_HOME'] || File.join(ENV['HOME'], '.local', 'share')
                  end

      File.join(data_home, 'WaniKaniTUI')
    end

    def self.windows?
      RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    end

    def self.get_preferences
      ensure!
      config_file = File.join(path, CONFIG_FILE)
      return {} unless File.exist?(config_file)

      YAML.load_file(config_file)
    rescue Psych::SyntaxError => e
      puts "Failed to parse config file: #{e.message}"
      {}
    end
  end
end

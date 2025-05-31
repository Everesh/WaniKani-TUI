# frozen_string_literal: true

require 'fileutils'

module WaniKaniTUI
  # Provides helper methods for managing data directory
  class DataDir
    def self.ensure!
      FileUtils.mkdir_p(path)
    end

    def self.path
      data_home = ENV['XDG_DATA_HOME'] || File.join(ENV['HOME'], '.local', 'share')
      File.join(data_home, 'WaniKaniTUI')
    end
  end
end

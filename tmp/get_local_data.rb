# frozen_string_literal: true

require 'json'
require 'fileutils'

require_relative '../lib/wanikani_api'
require_relative '../lib/db/database'

class GetLocalData
  def initialize(api_key: nil)
    api = WaniKaniTUI::WaniKaniAPI.new(WaniKaniTUI::Database.new, api_key: api_key)

    # Save subjects.json if it doesn't exist
    subjects_file = File.join(__dir__, 'subjects.json')
    unless File.exist?(subjects_file)
      subjects = api.fetch_subjects(nil)
      File.write(subjects_file, JSON.pretty_generate(subjects))
    end

    # Save assignments.json if it doesn't exist
    assignments_file = File.join(__dir__, 'assignments.json')
    unless File.exist?(assignments_file)
      assignments = api.fetch_assignments(nil)
      File.write(assignments_file, JSON.pretty_generate(assignments))
    end

    # Save user.json if it doesn't exist
    user_file = File.join(__dir__, 'user.json')
    unless File.exist?(user_file)
      user_data = api.fetch_user_data(nil)
      File.write(user_file, JSON.pretty_generate(user_data))
    end
  end
end

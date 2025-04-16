require_relative 'lib/wanikani'

puts 'Welcome to WaniKani TUI!'
Wanikani.fetch_assignments
Wanikani.fetch_all_subjects

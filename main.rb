require_relative 'lib/wanikani'

puts 'Welcome to WaniKani TUI!'
puts '==> Fetching assignments...'
Wanikani.fetch_assignments
puts '==> Done!'
puts '==> Fetching subjects...'
Wanikani.fetch_all_subjects
puts '==> Done!'

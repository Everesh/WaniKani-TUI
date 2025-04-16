require_relative 'lib/wanikani'
require_relative 'lib/review'

puts 'Welcome to WaniKani TUI!'
Wanikani.fetch_assignments
Wanikani.fetch_all_subjects

review_queue = Review.new
puts review_queue.next

# frozen_string_literal: true

require_relative 'lib/wanikani'
require_relative 'lib/review'
require 'logger'
require 'romkan'

COMMAND_EXIT = ':exit'
COMMAND_REPORT = ':report'

Wanikani::LOGGER.level = Logger::UNKNOWN

puts "\n▖  ▖    ▘▖▖    ▘  ▄▖▜ ▘"
puts   '▌▞▖▌▀▌▛▌▌▙▘▀▌▛▌▌▄▖▌ ▐ ▌'
puts   "▛ ▝▌█▌▌▌▌▌▌█▌▌▌▌  ▙▖▐▖▌ v0.0.0\n"

reviews = Review.new

queue = []
while true
  while queue.length < 5 && reviews.left > 0
    queue << { 'data' => reviews.shift,
               'meaning' => { 'passed' => false, 'attempts' => 0 },
               'reading' => { 'passed' => false, 'attempts' => 0 } }
  end

  puts "\n==| Completed: #{reviews.completed} | Left: #{reviews.left + queue.count}"
  puts "==| Commands: Exit -> #{COMMAND_EXIT}, Report -> #{COMMAND_REPORT}"
  puts "\n==#   #{queue.first.dig('data', 'data', 'characters')}\n\n"

  puts "#{if queue.first.dig('meaning',
                             'passed')
            '==? Reading'
          else
            '==? Meaning'
          end} - #{queue.first.dig('data', 'object')}: "

  print '==> '
  answer = gets.chomp.downcase
  case answer
  when COMMAND_EXIT
    break
  when COMMAND_REPORT
    reviews.report_all
    queue = []
  else
    if queue.first.dig('meaning', 'passed')
      answer.to_kana!
      puts "==| Parsed as: #{answer}"
      if queue.first.dig('data', 'data', 'readings').any? { |hash| hash['reading'].downcase == answer }
        puts '==+ Correct! +++++++++++++++++++++++++++++++++'
        reviews.done(queue.first.dig('data', 'assignment_id'),
                     queue.first.dig('reading', 'attempts'),
                     queue.first.dig('meaning', 'attempts'))
        queue.shift
      else
        puts '==- Incorrect! -------------------------------'
        puts "==| Expected: #{queue.first.dig('data', 'data', 'readings').first['reading'].downcase}"
        queue.first['reading']['attempts'] += 1
        queue << queue.shift
      end
    elsif queue.first.dig('data', 'data', 'meanings').any? { |hash| hash['meaning'].downcase == answer } ||
          queue.first.dig('data', 'data', 'auxiliary_meanings').any? { |hash| hash['meaning'].downcase == answer }
      puts '==+ Correct! +++++++++++++++++++++++++++++++++'
      queue.first['meaning']['passed'] = true
      if queue.first.dig('data', 'object') == 'radical'
        reviews.done(queue.first.dig('data', 'assignment_id'),
                     queue.first.dig('reading', 'attempts'),
                     queue.first.dig('meaning', 'attempts'))
        queue.shift
      else
        queue << queue.shift
      end
    else
      puts '==- Incorrect! -------------------------------'
      puts "==| Expected: #{queue.first.dig('data', 'data', 'meanings').first['meaning'].downcase}"
      queue.first['meaning']['attempts'] += 1
      queue << queue.shift
    end
  end
end

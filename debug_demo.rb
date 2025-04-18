# frozen_string_literal: true

require_relative 'lib/wanikani'
require_relative 'lib/review'

Wanikani::LOGGER.info('▖  ▖    ▘▖▖    ▘  ▄▖▖▖▄▖')
Wanikani::LOGGER.info('▌▞▖▌▀▌▛▌▌▙▘▀▌▛▌▌▄▖▐ ▌▌▐ ')
Wanikani::LOGGER.info('▛ ▝▌█▌▌▌▌▌▌█▌▌▌▌  ▐ ▙▌▟▖ v.0.0.0')
Wanikani.fetch_assignments
Wanikani.fetch_all_subjects

review_queue = Review.new
Wanikani::LOGGER.info('=============================')
Wanikani::LOGGER.info("Next item: #{review_queue.next['data']['characters']}")
Wanikani::LOGGER.info('=============================')
Wanikani::LOGGER.info('Readings: <Press-enter-to-reveal>')
gets
Wanikani::LOGGER.info("#{review_queue.next['data']['readings'].reduce('') do |str, reading|
  str += ', ' unless str.length.zero?
  str += reading['reading'] if reading['accepted_answer']
  str
end}")
Wanikani::LOGGER.info('=============================')
Wanikani::LOGGER.info('Meanings: <Press-enter-to-reveal>')
gets
Wanikani::LOGGER.info("#{review_queue.next['data']['meanings'].reduce('') do |str, meaning|
  str += ', ' unless str.length.zero?
  str += meaning['meaning'] if meaning['accepted_answer']
  str
end}")
Wanikani::LOGGER.info('=============================')
Wanikani::LOGGER.info('Got it right? [y/N]')
answer = gets.chomp.downcase
if answer.start_with?('y')
  review_queue.pass_next
  Wanikani::LOGGER.info('=============================')
  Wanikani::LOGGER.info('Send to WaniKani? [y/N]')
  answer = gets.chomp.downcase
  if answer.start_with?('y')
    Wanikani::LOGGER.info('=============================')
    review_queue.report_all
  end
end
Wanikani::LOGGER.info('=============================')

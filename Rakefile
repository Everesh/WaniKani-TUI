# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test_*.rb']
end

task :lint do
  sh 'rubocop -A'
end

task :setup do
  puts 'Installing Ruby gems...'
  system('bundle install') || abort('Failed to install Ruby gems!')

  puts 'Installing Python packages...'

  venv_dir = './venv'
  venv_pip = "#{venv_dir}/bin/pip"
  venv_python = "#{venv_dir}/bin/python"
  if File.exist?(venv_pip)
    puts 'Using existing virtualenv...'
  else
    puts 'Installing into venv...'
    python_cmd = `which python3`.strip
    abort('Python3 not found!') if python_cmd.empty?
    system("#{python_cmd} -m venv #{venv_dir}") || abort('Failed to create virtualenv!')
  end

  puts 'Installing Python packages in virtualenv...'
  system("#{venv_pip} install --upgrade pip") # upgrade pip first
  system("#{venv_pip} install numpy pillow") || abort('Failed to install Python packages!')

  puts 'Installation complete!'
  puts "To activate Python venv: '$ source #{venv_dir}/bin/activate'"
  puts "To run the app with: '$ bundle exec ruby bin/tui.rb'"
end

task default: :test

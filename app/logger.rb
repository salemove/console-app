require 'colorize'

def error(text)
  puts
  puts ">> #{text}".red
  puts
end

def debug(text)
  puts
  puts ">> #{text}".yellow
  puts
end

def info(text)
  puts
  puts text.green
end

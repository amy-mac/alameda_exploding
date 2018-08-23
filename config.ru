require 'dotenv/load' if File.exists?('.env')
require './app'
run Sinatra::Application

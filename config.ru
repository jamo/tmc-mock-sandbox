#$stdout.reopen("#{File.dirname(File.realpath(__FILE__))}/log/rack.log")
$stderr.reopen($stdout)
$stdout.sync = true
$stderr.sync = true

require 'rubygems'
require 'sinatra'
require "sinatra/json"
require 'rack'
require 'rack/commonlogger'
log = File.new("log/access.log", "a+")
log.sync = true
use(Rack::CommonLogger, log)


require './app'
run App.new



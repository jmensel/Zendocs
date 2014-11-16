# config.ru

require 'rubygems'
require 'bundler'
require 'sinatra'

#require File.expand_path '../app.rb', __FILE__
require "./app.rb"

run Sinatra::Application


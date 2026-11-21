require File.expand_path("config/boot", Dir.pwd)
require "rails/command"
base = Rails::Command::Base
p [:before, Rails::Command.subclasses.map(&:name), Rails::Command.instance_variable_get(:@subclasses)]
require "rails/commands/rake/rake_command"
p [:name, Rails::Command::RakeCommand.name]
p [:namespace, Rails::Command::RakeCommand.namespace]
p [:registered, Rails::Command.subclasses.map(&:name)]
p [:stored, Rails::Command.instance_variable_get(:@subclasses)&.map(&:name)]
p [:found, Rails::Command.find_by_namespace("rake")&.name]

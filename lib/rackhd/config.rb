require 'yaml'

module RackHD
  class Config
    FILE_PATH = '~/.rackhd-cli'
    def self.load_config(options)
      config = {}
      expanded_path = File.expand_path(FILE_PATH)
      if File.exist?(expanded_path)
        puts "Using configuration file at #{expanded_path}"
        config = YAML.load_file(expanded_path)
      else
        puts 'ERROR: No configuration file found.'
        puts "Please create configuration file at #{expanded_path}"
        puts 'See examples/config_template.yml for an example'
        exit(1)
      end
      config.merge(options)
    end
  end
end

require 'yaml'

module RackHD
  class Config
    FILE_PATH = '~/.rackhd-cli'
    def self.load_config_file
      expanded_path = get_config_path
      YAML.load_file(expanded_path)
    end

    def self.load_config(options)
      config = self.load_config_file
      config.merge(options)
    end

    def self.write_config_file(content)
      expanded_path = get_config_path
      File.open(expanded_path, 'w') {|f| f.write content }
    end

    private
    def self.get_config_path
      expanded_path = File.expand_path(FILE_PATH)
      if File.exist?(expanded_path)
        puts "Using configuration file at #{expanded_path}"
      else
        puts 'ERROR: No configuration file found.'
        puts "Please create configuration file at #{expanded_path}"
        puts 'See examples/config_template.yml for an example'
        exit(1)
      end
      expanded_path
    end
  end
end

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
        puts "Creating empty configuration file at #{expanded_path}"
        FileUtils.cp 'examples/config_template.yml', expanded_path
      end
      config.merge(options)
    end
  end
end

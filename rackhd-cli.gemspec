require File.expand_path('../lib/rackhd/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'rackhd-cli'
  s.version     = RackHD::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['CPT Team']
  s.email       = ['']
  s.homepage    = 'https://github.com/EMC-CMD/rackhd-cli/'
  s.summary     = 'RackHD CLI'
  s.description = 'A RackHD CLI'

  s.required_rubygems_version = '>= 1.3.6'

  s.rubyforge_project         = 'rackhd-cli'

  s.files        = Dir['{lib}/**/*.rb', 'bin/*']
  s.require_path = 'lib'

  s.executables = ['rack']
end

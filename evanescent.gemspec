Gem::Specification.new do |s|
  s.name        = 'evanescent'
  s.version     = '0.0.0'
  s.summary     = 'Ruby IO object that allows logging rotation, compression and purging.'
  s.description = "This gem provides an IO object, that can be used with any logging class (such as Ruby's native Logger). This object will save its input to a file, and allows:
  * Rotation by time / date.
  * Compression of old files.
  * Removal of old compressed files.
  Its purpuse is to supplement logging classes, allowing everything related to logging management, to be done within Ruby, without relying on external tools (such as logrotate)."
  s.authors     = ["Fabio Pugliese Ornellas"]
  s.email       = 'fabio.ornellas@gmail.com'
  s.add_development_dependency 'rspec', '~>3.3'
  s.add_development_dependency 'guard-rspec', '~>4.6', '~>4.6.4'
  s.add_development_dependency 'simplecov', '~>0.10'
  s.files       = Dir.glob('lib/**/*.rb')
  s.homepage    = 'https://github.com/fornellas/evanescent'
  s.license     = 'GPLv3'
end
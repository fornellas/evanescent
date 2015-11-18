Gem::Specification.new do |s|
  s.name        = 'evanescent'
  s.version     = '1.0.2'
  s.summary     = 'IO like object that allows logging rotation, compression and purging.'
  s.description = "This gem provides an IO like object, that can be used with any logging class (such as Ruby's native Logger). This object will save its input to a file, and allows: rotation by time / date, compression of old files and removal of old compressed files. Its purpuse is to supplement logging classes, allowing everything related to logging management, to be done within Ruby, without relying on external tools (such as logrotate)."
  s.authors     = ["Fabio Pugliese Ornellas"]
  s.email       = 'fabio.ornellas@gmail.com'
  s.add_runtime_dependency 'chronic_duration', '~>0.10', '>=0.10.6'
  s.add_development_dependency 'rspec', '~>3.3'
  s.add_development_dependency 'guard-rspec', '~>4.6', '~>4.6.4'
  s.add_development_dependency 'rake', '~>10.4', '>= 10.4.2'
  s.add_development_dependency 'simplecov', '~>0.10'
  s.add_development_dependency 'timecop', '~>0.8'
  s.files       = Dir.glob('lib/**/*.rb')
  s.homepage    = 'https://github.com/fornellas/evanescent'
  s.license     = 'GPLv3'
end

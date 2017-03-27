Gem::Specification.new do |s|
  s.name        = 'big_brother'
  s.version     = '1.0.0'
  s.date        = '2016-08-11'
  s.summary     = 'big_brother'
  s.description = 'An application monitor for Pulse applications'
  s.authors     = ['Pwnie Express']
  s.email       = 'ellery@pwnieexpress.com'
  s.files       = ['lib/big_brother.rb']
  s.add_runtime_dependency 'statsd-instrument', '~> 2.0.10'
  s.add_development_dependency 'rspec', ['>= 0']
  s.add_development_dependency 'dogapi', ['>= 0']
  s.add_development_dependency 'awesome_print', ['>= 0']
  s.add_development_dependency 'oj', ['>= 0']
  s.add_development_dependency 'activesupport', ['~> 4.2.3']
end
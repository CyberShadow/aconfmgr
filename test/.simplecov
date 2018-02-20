require 'coveralls'

SimpleCov.formatters = [
  Coveralls::SimpleCov::Formatter,
  SimpleCov::Formatter::HTMLFormatter,
]

SimpleCov.coverage_dir 'test/tmp/coverage'
SimpleCov.add_group 'Source code', '/src/'
SimpleCov.add_group 'Test suite', '/test/t/'

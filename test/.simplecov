# SimpleCov configuration (Ruby).
# Sourced by the SimpleCov library, which is used by bashcov.

integration = ENV.fetch('ACONFMGR_INTEGRATION', '0') == '1'
in_container = ENV.fetch('ACONFMGR_IN_CONTAINER', '0') == '1'
in_ci = ENV.fetch('CI', 'false') == 'true'

formatters = []
if not in_container then
  if in_ci then
    require 'coveralls'
    formatters.push(Coveralls::SimpleCov::Formatter)
  else
    formatters.push(SimpleCov::Formatter::HTMLFormatter)
  end
end
SimpleCov.formatters = formatters

if integration and not in_container then
  # Fixed-up version created by ci.sh
  SimpleCov.coverage_dir 'test/tmp/integ-coverage'
else
  SimpleCov.coverage_dir 'test/tmp/coverage'
end

SimpleCov.merge_timeout 3600

SimpleCov.root('..')

SimpleCov.add_group 'Source code', '/src/'
SimpleCov.add_group 'Test suite', '/test/t/'

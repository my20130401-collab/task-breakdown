if ENV["COVERAGE"] != "false"
  require "simplecov"
  SimpleCov.start "rails" do
    skip "/spec/"
    # モック段階のため既定は閾値なし。ロジック実装後に 80 へ戻す（MIN_COVERAGE=80 で指定可）
    minimum_coverage ENV.fetch("MIN_COVERAGE", 0).to_i
  end
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include ActiveSupport::Testing::TimeHelpers
end

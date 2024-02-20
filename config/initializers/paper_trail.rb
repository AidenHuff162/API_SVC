PaperTrail.config.track_associations = false

PaperTrail::Rails::Engine.eager_load!

PaperTrail.request.whodunnit = if Rails.const_defined?('Console')
                         "#{`whoami`.strip}: console"
                      else

                        "#{`whoami`.strip}: #{File.basename($PROGRAM_NAME)} #{ARGV.join ' '}"
                       end

class Version < ActiveRecord::Base
  attr_accessor :ip, :user_agent, :company_name
end

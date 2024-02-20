# Namespace for password tasks.
# Authors: 
#   Ramesh Doddi <ramesh@trysapling,.com>
#   Seth Little <seth.little@trysapling.com>

namespace :password_util do

  desc "Utility for rotating Super User passwords."
  # usage: 
  # bundle exec rails password_util:rotate_super_user_passwords[saplingapp] RAILS_ENV=production
  # bundle exec rails password_util:rotate_super_user_passwords[sandbox] RAILS_ENV=production
  # bundle exec rails password_util:rotate_super_user_passwords[test] RAILS_ENV=staging
  task :rotate_super_user_passwords, [:site, :passwd_length, :logfile] => :environment do |t, args|
    args.with_defaults(:site => "test", :passwd_length => "32", :logfile => "log/super_users-#{Date.today}.csv")
    file = File.open(args.logfile, "a+")
    puts "password_length: #{args.passwd_length.to_i}"
    passwd_gen = PawGen.new
                  .include_uppercase!
                  .include_symbols!
                  .include_digits!
                  .set_length!(args.passwd_length.to_i)
    folder = "#{args.site}-super_users-#{Date.today}"
    # Following header format is needed for LastPass vault
    file.puts "name,url,type,username,password,folder"
    Company.all.each do |company|
      puts "processing #{company.name} ..."
      super_user = company.users.find_by(email: "super_user@#{company.domain}")
      if !super_user
        puts "#{company.name},could not find super_user"
        next
      end
      # Replace quotes and commas so that CSV upload is not confused.
      passwd = passwd_gen.anglophonemic.gsub('"', '&').gsub(',', '|').gsub('\'','^')
      super_user.password = passwd
      super_user.save
      if super_user.errors.full_messages != []
        puts "Error: #{passwd} " + super_user.errors.full_messages.join(',')
        next
      end
      puts "processed #{company.name}"
      # Following data format is needed for LastPass vault
      # Sorround name with quotes as name carries ',' conflicting CSV format
      file.puts "\"#{company.name}\",#{company.domain},password,#{super_user.email},#{super_user.password},#{folder}"
    end
  end

end

namespace :update_smart_assignment_configuration do
  task smart_assignment_configuration: :environment do
    puts 'Fixing Smart Assignment Configurations.'
    Company.joins(:smart_assignment_configuration).where(sa_disable:  true).all.each do |c|
      meta = c.smart_assignment_configuration&.meta
      next unless meta
      meta["smart_assignment"] = true
      c.smart_assignment_configuration.update_column(:meta, meta)
      puts 'Smart Assignment Configurations Fixed.'
    end
  end 
end
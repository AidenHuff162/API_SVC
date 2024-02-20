class ReceiveUpdatedEmployeePictureFromNamelyJob < ApplicationJob
  queue_as :receive_employee_from_hr

  def perform(company)
    namely_credentials = get_namely_credentials(company)
    subdomain = namely_credentials.company_url rescue nil
    access_token = namely_credentials.permanent_access_token rescue nil

    if subdomain.present? && access_token.present?
      puts "COMPANY: #{company.name} - NAMELY TO SAPLING IMAGE UPDATION START"
      users = company.users.where("email IS NOT NULL OR personal_email IS NOT NULL")
      users.try(:find_each) do |user|
        begin
          if !user.namely_id.present?
            puts "Namely - Profile Id Pulling Start: #{user.first_name} #{user.last_name}"

            profile = {profiles: []}
            sleep 2
            if user.email.present?
              profile = HTTParty.get("https://#{subdomain}.namely.com/api/v1/profiles?filter[email]=#{user.email}",
                headers: { accept: "application/json", authorization: "Bearer #{access_token}" }
              )

              profile = JSON.parse(profile.body)
            end

            if user.personal_email.present? && !profile['profiles'].any?
              profile = HTTParty.get("https://#{subdomain}.namely.com/api/v1/profiles?filter[personal_email]=#{user.personal_email}",
                headers: { accept: "application/json", authorization: "Bearer #{access_token}" }
              )
              profile = JSON.parse(profile.body)
            end

            if profile['profiles'].any?
              user.namely_id = profile['profiles'].first['id']
              user.save!
            end
            puts "Namely - Profile Id Pulling Stop: #{user.email}"
          end
        rescue Exception => e
        end
      end

      company = company.reload

      users = company.users.where.not(namely_id: nil)
      users.try(:find_each) do |user|
        begin
          puts "Namely - Profile Image Pulling Start: #{user.namely_id}"
          sleep 2
          profile = HTTParty.get("https://#{subdomain}.namely.com/api/v1/profiles/#{user.namely_id}",
            headers: { accept: "application/json", authorization: "Bearer #{access_token}" }
          )

          profile_data = JSON.parse(profile.body)

          image_file_thumb = profile_data['profiles'].first['image']['thumbs']['450x450'] rescue nil
          if image_file_thumb.present?
            profile_photo = HTTParty.get("https://#{subdomain}.namely.com/#{image_file_thumb}",
              headers: { content_type: "image/jpeg", accept: "application/binary", authorization: "Bearer #{access_token}" }
            )

            require 'fileutils'
            unless File.directory?("#{Rails.root}/tmp/profile_image/#{company.id}/")
              FileUtils.mkdir_p("#{Rails.root}/tmp/profile_image/#{company.id}/")
            end

            File.open("#{Rails.root}/tmp/profile_image/#{company.id}/namely_profile.jpeg", "wb") do |f|
              f.write(profile_photo.body)
            end

            user_profile_image = user.profile_image || user.build_profile_image
            user_profile_image.file.store!(File.open(File.join(Rails.root, "/tmp/profile_image/#{company.id}/namely_profile.jpeg")))
            user_profile_image.save!
            History.create_history({
              company: company,
              user_id: user.id,
              description: I18n.t('history_notifications.profile.others_updated', full_name: 'Namely',field_name: 'Profile Picture',first_name: user.first_name, last_name: user.last_name)
            })
            namely_credentials.update_column(:synced_at, DateTime.now)
          end
          puts "Namely - Profile Image Pulling Stop"
        rescue Exception => e
        end
      end
    end
    puts "COMPANY: #{company.name} - NAMELY TO SAPLING IMAGE UPDATION STOP"
  end

  def get_namely_credentials(company)
    ::HrisIntegrationsService::Namely::Helper.new.fetch_integration(company)
  end
end

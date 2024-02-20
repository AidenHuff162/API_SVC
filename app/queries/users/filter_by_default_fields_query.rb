module Users
  class FilterByDefaultFieldsQuery
    def initialize(users)
      @users = users.where(super_user: false)
    end

    def filter_by_default_fields(params)
      keys = %w[location department manager buddy about github twitter linkedin job_title job_tier status first_name last_name email
                personal_email termination_type eligible_for_rehire]
      keys.map { |key| send("filter_by_#{key}", params[key]) if params[key].present? }
      %w[start_date termination_date last_day_worked].map { |key| send('filter_by_date', params, key) if params[key].present? }
      @users
    end

    def filter_by_location(location)
      return if location.blank?

      @users = @users.joins('INNER JOIN locations ON locations.id = users.location_id')
                     .where('locations.name = ?', location)
    end

    def filter_by_department(department)
      return if department.blank?

      @users = @users.joins('INNER JOIN teams ON teams.id = users.team_id')
                     .where('teams.name = ?', department)
    end

    def filter_by_manager(manager)
      @users = @users.joins(:manager).where('managers_users.guid = ?', manager) if manager
    end

    def filter_by_buddy(buddy)
      return @users unless buddy

      @users = @users.joins(:buddy).where('buddies_users.guid = ?', buddy)
    end

    def filter_by_github(github)
      return @users unless github

      @users = @users.joins(:profile).where('profiles.github = ?', github)
    end

    def filter_by_linkedin(linkedin)
      return @users unless linkedin

      @users = @users.joins(:profile).where('profiles.linkedin = ?', linkedin)
    end

    def filter_by_twitter(twitter)
      return @users unless twitter

      @users = @users.joins(:profile).where('profiles.twitter = ?', twitter)
    end

    def filter_by_about(about)
      return @users unless about

      @users = @users.joins(:profile).where('profiles.about_you = ?', about)
    end

    def filter_by_job_title(job_title)
      return @users unless job_title

      @users = @users.where(title: job_title)
    end

    def filter_by_job_tier(job_tier)
      return @users unless job_tier

      @users = @users.where(job_tier: job_tier)
    end

    def filter_by_status(status)
      return @users unless status

      @users = @users.where(state: status)
    end

    def filter_by_first_name(first_name)
      return @users unless first_name

      @users = @users.where(first_name: first_name)
    end

    def filter_by_last_name(last_name)
      return @users unless last_name

      @users = @users.where(last_name: last_name)
    end

    def filter_by_email(email)
      return @users unless email

      @users = @users.where(email: email)
    end

    def filter_by_personal_email(personal_email)
      return @users unless personal_email

      @users = @users.where(personal_email: personal_email)
    end

    def filter_by_termination_type(termination_type)
      return @users unless termination_type
      return { message: I18n.t('api_notification.invalid_filters'), status: 422 } unless %w[voluntary involuntary
                                                                                            other].include?(termination_type)

      @users = @users.where(termination_type: User.termination_types.fetch(termination_type))
    end

    def filter_by_eligible_for_rehire(eligible_for_rehire)
      return @users unless eligible_for_rehire
      return { message: I18n.t('api_notification.invalid_filters'), status: 422 } unless %w[yes no
                                                                                            upon_review].include?(eligible_for_rehire)

      @users = @users.where(eligible_for_rehire: User.eligible_for_rehires.fetch(eligible_for_rehire))
    end

    def filter_by_date_range(params, date_key)
      since = params[date_key]['since']
      untill = params[date_key]['untill']
      if since.blank? && untill.blank?
        return { message: I18n.t('api_notification.invalid_filters'), status: 422 } unless params[date_key].instance_of?(String)

        @users = @users.where("#{date_key} = ? ", params[date_key])
      else
        filter_date_based_on_since_untill({ since: since, untill: untill, date_key: date_key })
      end
    end

    def filter_date_based_on_since_untill(**kwargs)
      if kwargs[:since].present? && kwargs[:untill].present?
        @users = @users.where("#{kwargs[:date_key]} >= ? AND #{kwargs[:date_key]} <= ?", kwargs[:since], kwargs[:untill])
      elsif kwargs[:since].present?
        @users = @users.where("#{kwargs[:date_key]} >= ?", kwargs[:since])
      elsif kwargs[:untill].present?
        @users = @users.where("#{kwargs[:date_key]} <= ?", kwargs[:untill])
      end
    end

    alias filter_by_date filter_by_date_range
  end
end

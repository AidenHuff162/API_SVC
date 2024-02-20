module SaplingApiService
  class RetrieveUserProfile
    include SaplingApiService::SaplingApiHashes
    
    attr_reader :company, :custom_fields, :users, :default_fields_query_object, :custom_fields_query_object
    delegate :prepare_custom_field_hash_data, to: :helper_service

    def initialize(company)
      @company = company
      @custom_fields = company.custom_fields
      @users = company.users_without_super_user
      @default_fields_query_object = Users::FilterByDefaultFieldsQuery.new(users)
      @custom_fields_query_object = Users::FilterByCustomFieldsQuery.new
      @api_key_fields = {}
    end

    def allowable_filters
      DEFAULT_API_FIELDS_ID + FILTERS + custom_fields.pluck(:api_field_id).map(&:downcase)
    end

    def fetch_users_with_specific_data(params, api_key_fields)
      @api_key_fields = api_key_fields
      prepare_fields_specific_user_data_hash(params)
    end

    def fetch_users(params, api_key_fields)
      @api_key_fields = api_key_fields
      prepare_users_data_hash(params)
    end

    def fetch_user(params, api_key_fields)
      @api_key_fields = api_key_fields
      prepare_user_data_hash(params)
    end

    def fetch_user_for_ids_server(params, api_key_fields)
      @api_key_fields = api_key_fields
      prepare_user_data_hash_for_ids_server(params)
    end

    private

    def preference_field_id?(api_field_id)
      DEFAULT_API_FIELDS_ID.include? api_field_id
    end

    def custom_field_id?(api_field_id)
      custom_fields.pluck(:api_field_id).include? api_field_id
    end

    def remove_unnecessary_params(params)
      params.delete(:format)
      params.delete(:controller)
      params.delete(:action)
      params
    end

    def invalid_filters?(params, is_a_user = false)
      remove_unnecessary_params(params)

      if is_a_user.present?
        params.except(:id).count != 0
      else
        !params.keys.to_set.subset?(allowable_filters.to_set)
      end
    end   

    def prepare_hash(api_field_id = 'all', api_key_meta_data)
      # return SaplingApiService::ApiDataSegmentation.call(company, api_key_meta_data) if company.api_data_segmentation_feature_flag && api_field_id == 'all'
      user = api_key_meta_data[:user]
      user_data_hash = { id: user.id, guid: user.guid }

      user_data_hash[:start_date] = user.start_date if %w[start_date all].include? api_field_id
      user_data_hash[:first_name] = user.first_name if %w[first_name all].include? api_field_id
      user_data_hash[:last_name] = user.last_name if %w[last_name all].include? api_field_id
      user_data_hash[:preferred_name] = user.preferred_name if %w[preferred_name all].include? api_field_id
      user_data_hash[:job_title] = user.title if %w[job_title all].include? api_field_id
      user_data_hash[:job_tier] = user.job_tier if %w[job_tier all].include? api_field_id
      user_data_hash[:manager] = user.manager.try(:guid) if %w[manager all].include? api_field_id
      user_data_hash[:buddy] =  user.buddy.try(:guid) if %w[buddy all].include? api_field_id
      user_data_hash[:location] = user.location.try(:name) if %w[location all].include? api_field_id
      user_data_hash[:department] = user.team.try(:name) if %w[department all].include? api_field_id
      user_data_hash[:termination_type] = user.termination_type if %w[termination_type all].include? api_field_id
      user_data_hash[:eligible_for_rehire] = user.eligible_for_rehire if %w[eligible_for_rehire all].include? api_field_id
      user_data_hash[:termination_date] = user.termination_date if %w[termination_date all].include? api_field_id
      user_data_hash[:state] = user.state if %w[status all].include? api_field_id
      user_data_hash[:last_day_worked] = user.last_day_worked if %w[last_day_worked all].include? api_field_id
      user_data_hash[:company_email] = user.email if %w[company_email all].include? api_field_id
      user_data_hash[:personal_email] = user.personal_email if %w[personal_email all].include? api_field_id
      user_data_hash[:about] = user.profile.try(:about_you) if %w[about all].include? api_field_id
      user_data_hash[:github] = user.profile.try(:github) if %w[github all].include? api_field_id
      user_data_hash[:twitter] = user.profile.try(:twitter) if %w[twitter all].include? api_field_id
      user_data_hash[:linkedin] = user.profile.try(:linkedin) if %w[linkedin all].include? api_field_id
      user_data_hash[:profile_photo] = user.original_picture if %w[profile_photo all].include? api_field_id
      company.custom_tables.try(:each) do |custom_table|
        user_data_hash[custom_table.name.parameterize.underscore] = {}
      end

      if api_field_id != 'all'
        section = nil
        profile_field = fetch_preference_field_by_api_field_id(company, api_field_id)&.symbolize_keys
        section = profile_field[:section].presence || profile_field[:custom_table_property] if profile_field.present?
        user_data_hash[:section] = section.try(:titleize)
      end
      custom_fields = api_field_id == 'all' ? @custom_fields : @custom_fields.where(api_field_id: api_field_id)
      custom_fields.try(:find_each) do |custom_field|
        if api_field_id != 'all'
          user_data_hash[:id] = custom_field.api_field_id
          user_data_hash[:section] = (custom_field&.custom_section&.section || custom_field&.custom_table&.name).try(:titleize)
        end
        prepare_custom_field_hash_data(user, { custom_field: custom_field, user_data_hash: user_data_hash })
      end

      user_data_hash
    end

    def filterate_users(_users, params)
      filtered_users = default_fields_query_object.filter_by_default_fields(params)
      filtered_users = custom_fields_query_object.filter_by_custom_fields({ filtered_users: filtered_users, params: params, custom_fields: custom_fields })

      filtered_users.order(:id)
    end

    def prepare_fields_specific_user_data_hash(params)
      field_id = params.delete(:id)

      return { message: I18n.t('api_notification.invalid_filters'), status: 422 } if invalid_filters?(params)

      if !preference_field_id?(field_id) && !custom_field_id?(field_id)
        return { message: I18n.t('api_notification.invalid_field_id'), status: 422 }
      end

      users = filterate_users(users, params)

      invalid_data = begin
        users[:message]
      rescue StandardError
        nil
      end
      return users if invalid_data.present?

      limit = params[:limit].present? && params[:limit].to_i.positive? ? params[:limit].to_i : 50
      total_pages = (users.count / limit.to_f).ceil

      if params[:page].to_i.negative? || total_pages < params[:page].to_i
        return { message: I18n.t('api_notification.invalid_page_offset'), status: 422 }
      end

      page = if users.count <= 0
               0
             else
               (params[:page].blank? || params[:page].to_i.zero? ? 1 : params[:page].to_i)
             end
      users_data_hash = { current_page: page, total_pages: if users.count <= 0
                                                             0
                                                           else
                                                             (total_pages.zero? ? 1 : total_pages)
                                                           end,
                          total_users: users.count, users: [] }

      if page.positive?
        paginated_users = users.paginate(page: page, per_page: limit)
        paginated_users.each do |user|
          users_data_hash[:users].push prepare_hash(field_id, { user: user, api_key_fields: @api_key_fields })
        end
      end

      users_data_hash.merge!(status: 200)
    end

    def prepare_users_data_hash(params)
      return { message: I18n.t('api_notification.invalid_filters'), status: 422 } if invalid_filters?(params)
      users = filterate_users(users, params)

      invalid_data = begin
        users[:message]
      rescue StandardError
        nil
      end
      return users if invalid_data.present?

      limit = params[:limit].present? && params[:limit].to_i.positive? ? params[:limit].to_i : 50
      total_pages = (users.count / limit.to_f).ceil

      if params[:page].to_i.negative? || total_pages < params[:page].to_i
        return { message: I18n.t('api_notification.invalid_page_offset'), status: 422 }
      end

      page = if users.count <= 0
               0
             else
               (params[:page].blank? || params[:page].to_i.zero? ? 1 : params[:page].to_i)
             end
      users_data_hash = { current_page: page, total_pages: if users.count <= 0
                                                             0
                                                           else
                                                             (total_pages.zero? ? 1 : total_pages)
                                                           end,
                          total_users: users.count, users: [] }

      if page.positive?
        paginated_users = users.paginate(page: page, per_page: limit)
        paginated_users.each do |user|
          users_data_hash[:users].push prepare_hash({ user: user, api_key_fields: @api_key_fields })
        end
      end

      users_data_hash.merge!(status: 200)
    end

    def prepare_user_data_hash(params)
      return { message: I18n.t('api_notification.filters_not_allowed'), status: 422 } if invalid_filters?(params, true)
    
      user = users.where(guid: params[:id]).first

      if user.present?
        { user: prepare_hash({ user: user, api_key_fields: @api_key_fields }), status: 200 }
      else
        { message: I18n.t('api_notification.invalid_user_id'), status: 422 }
      end
    end

    def prepare_user_data_hash_for_ids_server(params)
      user = users.where('email ILIKE ? OR personal_email ILIKE ?', params[:email], params[:email]).take if company
      
      if user.present?
        { user: prepare_hash({ user: user, api_key_fields: @api_key_fields}), status: 200 }
      else
        { message: 'User not Found', status: 422 }
      end
    end

    def fetch_preference_field_by_api_field_id(company, api_field_id)
      company.prefrences['default_fields'].map { |field| field if field['api_field_id'] == api_field_id }.reject(&:nil?)[0]
    end

    def helper_service
      SaplingApiService::Helper.new
    end
  end
end

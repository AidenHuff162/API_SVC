module PtoRequestService
  module RestOps
    class Resource
      attr_reader :params_object, :intercepting_events, :request_unchanged, :include_comments
      cattr_accessor :request_object, :policy

      def initialize params, request_unchanged = nil, include_comments = nil
        @params_object = params
        @intercepting_events = []
        @request_object = nil
        @policy = nil
        @request_unchanged = request_unchanged
        @include_comments = include_comments
      end

      def create_request_with_partner_pto_requests
        find_or_build_new_request
        self.policy = request_object.pto_policy
        if request_not_intercepting_with_any_event? && !request_object.id.present?
          request_object.balance_hours = request_object.get_balance_used 
          request_object.save
        else
          check_for_intercepting_renewal_or_expiration_date
          create_request_and_partner_requests
        end
        request_object
      end

      private

      def request_not_intercepting_with_any_event?
        request_object.partial_day_included || only_comments_added?
      end

      def only_comments_added?
        request_object.id.present? && request_unchanged && include_comments
      end

      def find_or_build_new_request
        if persisted_request?
          self.request_object = PtoRequest.find(params_object['id'])
          self.request_object.assign_attributes params_object.except('id')
        else
          self.request_object = PtoRequest.new(params_object)
          self.request_object.status = self.request_object.pto_policy.manager_approval ? 0 : 1
        end
        self.request_object.include_comment = @include_comments
        self.request_object
      end

      def check_for_intercepting_renewal_or_expiration_date
        request_range = request_range_array
        current_date = policy.company.time.to_date
        unless policy.unlimited_policy
          renewal_date = get_renewal_date
          expiry_date = request_object.get_policy_carryover_expiration_date if policy.carryover_amount_expiry_date.present?
          intercepting_events << (get_renewal_date - 1.year) if includes_last_and_current_period?
          intercepting_events << renewal_date if request_range.include?(renewal_date)
          intercepting_events << expiry_date if policy.carryover_amount_expiry_date.present? && request_range.include?(expiry_date)
        end
        request_range.each { |date| intercepting_events << date if date == date.beginning_of_month }
        request_range.each { |date| intercepting_events << date if date.day == 16 }
        request_range.each { |date| intercepting_events << date if date .wday == 1 }
        intercepting_events.uniq!
        intercepting_events << request_object.end_date if intercepting_events.count > 0
        intercepting_events.sort!{|a, b| a <=> b }
      end

      def create_request_and_partner_requests
        ActiveRecord::Base.transaction do
          set_attributes_values
          request_object.partner_pto_requests.try(:each) {|a| a.really_destroy!}
          unless intercepting_events.length == 0
            request_object.end_date = intercepting_events.shift - 1.day
            request_object.balance_hours = request_object.get_balance_used
            request_object.save!
            create_partner_pto_requests(request_object.end_date + 1.day)
          else
            request_object.balance_hours = request_object.get_balance_used
            request_object.save!
          end
          request_object
        end
      rescue ActiveRecord::RecordInvalid => exception
        exception.message.sub('Validation failed: ', '').split(',').each do |error|
          request_object.errors.add(:base, error) if exception.record.partner_pto_request_id.present?
        end
      end
        
      def request_range_array
        ((request_object.begin_date + 1.day)..request_object.end_date).to_a
      end

      def persisted_request?
        params_object.keys.include?("id")
      end

      def create_partner_pto_requests begin_date
        return if intercepting_events.length == 0
        partner_request = PtoRequest.new(params_object.except('id', 'begin_date', 'end_date', 'comments_attributes', 'attachment_ids'))
        partner_request.partner_pto_request_id = request_object.id
        partner_request.begin_date = begin_date
        partner_end_date = intercepting_events.shift
        partner_request.end_date = (partner_end_date == @params_object['end_date'].to_date && intercepting_events.length == 0 ? partner_end_date : (partner_end_date - 1))
        partner_request.balance_hours = partner_request.get_balance_used
        partner_request.status = request_object.status
        partner_request.save!
        create_partner_pto_requests(partner_end_date == @params_object['end_date'].to_date && intercepting_events.length == 0 ? partner_request.end_date : partner_request.end_date + 1.day)
      end

      def request_ends_today_or_in_past?
        request_object.end_date <= policy.company.time.to_date && !includes_last_and_current_period?
      end 

      def includes_last_and_current_period?
        request_range_array.include?(get_renewal_date - 1.year)
      end

      def get_renewal_date
        pto_policy = request_object.pto_policy
        date = request_object.begin_date < pto_policy.company.time.to_date ? pto_policy.company.time.to_date : request_object.begin_date
        request_object.get_renewal_date(date)
      end

      def set_attributes_values
        request_object.real_balance = @params_object['balance_hours']
        request_object.real_end_date_was = PtoRequest.find(@params_object['id']).get_end_date if request_object.id.present?
        request_object.real_end_date = @params_object['end_date'].to_date if @params_object['end_date']
      end
    end
  end
end
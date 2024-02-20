module UserSerializer
  class HeapProperties < ActiveModel::Serializer
  	attribute  :sign_in_count, key: :total_sign_ins
  	attribute  :state, key: :user_state
    attributes :id, :first_name, :last_name, :full_name, :preferred_name, :preferred_full_name, :email, :title, 
    		   		 :personal_email, :role, :user_account_owner, :termination_date, :current_stage, :start_date, :location_name, 
               :email_notification, :slack_notification, :permissions

    has_one :company, serializer: CompanySerializer::HeapProperties

   	def role
   		object.user_role.role_type
   	end

   	def user_account_owner
   		object.account_owner?
   	end

    def permissions
    	@instance_options[:permissions]
    end
  end
end


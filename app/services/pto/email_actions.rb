module Pto
  class EmailActions
    def self.approve_pto pto, user_id
      current_user = User.friendly.find(user_id)
      pto = PtoRequestService::CrudOperations.new.approve_or_deny(pto, 1, current_user, true, "email")
      return pto
    end

    def self.deny_pto pto, user_id
      current_user = User.friendly.find(user_id)
      pto = PtoRequestService::CrudOperations.new.approve_or_deny(pto, 2, current_user, true, "email")
      return pto
    end

    def self.add_comment pto, comment, company_id, user_id
      user = pto.user
      Comment.create!(description: comment, commentable_id: pto.id, commentable_type: "PtoRequest", commenter_id: User.friendly.find(user_id).id, company_id: company_id, create_activity: true)
    end
  end
end

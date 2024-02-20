module Interactions
  module TaskUserConnections
    class DestroyByWorkstream
       attr_reader :workstream_id, :user_id, :owner_id, :filter, :due_date

      def initialize(params)
        @filter = params[:filter]
        @due_date = params[:due_date]
        @workstream_id = params[:workstream_id]
        @user_id = params[:user_id]
        @owner_id = params[:owner_id]
      end

      def perform
        if filter == "employee"
          TaskUserConnection.where(user_id: user_id, owner_id: owner_id).destroy_all if owner_id && user_id

        elsif filter == "due_date"
          if owner_id
            TaskUserConnection.where(due_date: due_date, owner_id: owner_id).destroy_all
          elsif user_id
            TaskUserConnection.where(due_date: due_date, user_id: user_id).destroy_all
          end

        else
          if owner_id
            TaskUserConnection.joins(task: :workstream)
                              .where(workstreams: {id: workstream_id}, owner_id: owner_id)
                              .destroy_all
          elsif user_id
            TaskUserConnection.joins(task: :workstream)
                              .where(workstreams: {id: workstream_id}, user_id: user_id)
                              .destroy_all
          end
        end
      end
    end
  end
end

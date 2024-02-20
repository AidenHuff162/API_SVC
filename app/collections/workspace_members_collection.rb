class WorkspaceMembersCollection < BaseCollection
  private

  def relation
    @relation ||= WorkspaceMember.all
  end

  def ensure_filters
    workspace_filter
    sorting_filter
  end

  def workspace_filter
    filter { |relation| relation.joins(:workspace).where('workspace_members.workspace_id = workspaces.id AND workspaces.id = ? AND workspaces.company_id = ?', params[:workspace_id], params[:company_id]) } if params[:workspace_id]
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:order_column] == '3'
        filter { |relation| relation.joins("LEFT JOIN users ON users.id = workspace_members.member_id
          LEFT JOIN locations ON locations.id = users.location_id").order("locations.name #{order_in}") }
      elsif params[:order_column] == '2'
        filter { |relation| relation.joins(:member).order("title #{order_in}") }
      elsif params[:order_column] == '1'
        company_default_name_format = relation.first.workspace.company.display_name_format if relation.first
        if company_default_name_format == 0 || company_default_name_format == 1
          filter { |relation| relation.joins(:member).order("users.preferred_full_name #{order_in}") }
        elsif company_default_name_format == 2
          filter { |relation| relation.joins(:member).order(Arel.sql("concat_ws(' ', users.first_name, users.last_name) #{order_in}")) }
        elsif company_default_name_format == 3
          filter { |relation| relation.joins(:member).order(Arel.sql("concat_ws(' ', users.first_name, users.preferred_name, users.last_name) #{order_in}")) }
        elsif company_default_name_format == 4
          filter { |relation| relation.joins(:member).order(Arel.sql("concat_ws(' ', users.last_name, users.first_name) #{order_in}")) }
        end     
      elsif params[:order_column] == '4'
        filter { |relation| relation.order("member_role #{order_in}") }
      elsif params[:order_column] == '5'
        filter { |relation| relation.joins("LEFT JOIN users ON users.id = workspace_members.member_id
          LEFT JOIN task_user_connections ON users.id = task_user_connections.user_id AND task_user_connections.owner_type = 1")
        .group("workspace_members.id")
        .order("COUNT(task_user_connections.id) #{order_in}") }
      end
    end
  end

end

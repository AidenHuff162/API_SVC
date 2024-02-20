require 'csv'
class EmailDashboardApprovedRequestsService
	
  def perform(company_id, user_id, send_email, file_storage_path)
    begin
      company = Company.find_by_id(company_id)
      user = company.users.find_by_id(user_id)
      return if company.blank? ||  user.blank?

      collection = custom_section_query(company.id)
      return if collection.nil? || collection.values.empty?
      name = "Profile Approved Requests for #{company.name}"
      file = File.join(file_storage_path,"#{name}.csv")
      column_headers = ["CompanyId", "CompanyName", "UserId", "UserFirstName", "UserLastName", "SectionName",
                      "FieldName", "OldValue", "NewValue", "RequestId", "RequestedByFirstName",
                      "RequestedByLastName", "RequestedDate", "ApprovalStepId", "ApprovedOn", "ApproverFirstName",
                      "ApproverLastName", "SectionUpdated"]
      titleize_permanent_fields = column_headers.map { |h| h.present? ? h.titleize.tr("\n", " ")  : ''}
      user_ids = UsersCollection.new({company_id: company.id, current_user: user, lde_filter: true}).results.ids

      CSV.open(file, 'w:bom|utf-8', write_headers: true, headers: titleize_permanent_fields) do |writer|
        collection.values.each do |colec|
          current_user = company.users.find_by_id(colec[2])
          values = current_user.get_approved_csa_field_values(column_headers, colec, user_ids.include?(colec.third))
          writer << values if values.present?
        end
      end

      if send_email && !collection.values.empty?
        UserMailer.csv_approved_requests_email(user, name, file).deliver_now!
        logging.create(user.company, 'Custom Section Approval Requests Email - Pass', {report_contents: collection.values.inspect, report_title: "#{name}", report_requester: "(#{user.id}:#{user.full_name})"}, 'CustomSectionApproval') 
        File.delete(file) if file.present?
      else
        file
      end

    rescue Exception => e
      logging.create(user.company, 'Custom Section Approval Requests Email - Fail', {report_contents: collection.values.inspect, report_title: "#{name}", report_requester: "(#{user.id}:#{user.full_name})", error: e.message}, 'CustomSectionApproval') 
    end
  end


  def custom_section_query(company_id)
    begin
      query = <<-SQL
      (
      SELECT c.id AS "CompanyId", c.name AS "CompanyName", u.id AS "UserId",
        u.first_name AS "UserFirstName", u.last_name AS "UserLastName",
          cs.section AS "SectionName", rf.id as "FieldName", rf.id as "OldValue",
            rf.id as "NewValue",
              csa.id AS "RequestId", u2.first_name AS "RequestedByFirstName",
                u2.last_name AS "RequestedByLastName", csa.created_at AS "RequestedDate",
                  csac.id AS "ApprovalStepId", csac.approval_date AS "ApprovedOn",
                    u3.first_name AS "ApproverFirstName", u3.last_name AS "ApproverLastName",
                      csa.updated_at AS "SectionUpdated"
      FROM companies as c
      JOIN users as u
        ON c.id = u.company_id
      JOIN custom_section_approvals as csa
        ON u.id = csa.user_id
      JOIN custom_sections as cs
        ON csa.custom_section_id = cs.id
      JOIN requested_fields as rf
        ON rf.custom_section_approval_id = csa.id
      JOIN cs_approval_chains as csac
        ON csa.id = csac.custom_section_approval_id
      JOIN users as u2
        ON csa.requester_id = u2.id
      JOIN users as u3
        ON csac.approver_id = u3.id
      WHERE (c.account_state = 'active' AND csac.state = 2 AND c.id = ?  AND c.deleted_at IS NULL
      AND u.deleted_at IS NULL AND csa.deleted_at IS NULL 
      AND rf.deleted_at IS NULL AND csac.deleted_at IS NULL)
      ORDER BY csa.updated_at DESC, csac.approval_date DESC, csac.id DESC, u.last_name, u.first_name
      LIMIT 1000
      )
      SQL
      sanitized_query = ActiveRecord::Base.send(:sanitize_sql_array, [query, company_id])
      collection = ActiveRecord::Base.connection.execute(sanitized_query)
    rescue => e
      return []
    end
    collection
  end

  private

  def logging
    @logging ||= LoggingService::GeneralLogging.new
  end
end

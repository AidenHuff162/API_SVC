require 'csv'
class WriteApprovedCtusCSVJob
  include Sidekiq::Worker
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true
  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end

  def perform(user_id, send_email = false)
    begin
      user = User.find(user_id)
      company = Company.find(user.company.id)
      
      collection = query(company.id)
      return if collection.nil? || collection.values.empty?
      
      name = "Approved Requests for #{company.name}"
      file = File.join(FILE_STORAGE_PATH,"#{name}.csv")
      column_headers = ["CompanyId", "CompanyName", "UserId", "UserFirstName", "UserLastName", "TableName",
                        "FieldName", "OldValue", "NewValue", "EffectiveDate", "RequestId", "RequestedByFirstName",
                        "RequestedByLastName", "RequestedDate", "ApprovalStepId", "ApprovedOn", "ApproverFirstName",
                        "ApproverLastName", "TableUpdated"]
      titleize_permanent_fields = column_headers.map { |h| h.present? ? h.titleize.tr("\n", " ")  : ''}
      user_ids = UsersCollection.new({company_id: company.id, current_user: user, lde_filter: true}).results.ids

      CSV.open(file, 'w:bom|utf-8', write_headers: true, headers: titleize_permanent_fields) do |writer|
        collection.values.each do |colec|
          writer << user.get_approved_ctus_field_values(column_headers, colec, user_ids.include?(colec.third))
        end
      end

      if send_email && !collection.values.empty?
        user = company.users.find_by(id: user_id)
        UserMailer.csv_approved_requests_email(user, name, file).deliver_now!
        File.delete(file) if file.present?
      else
        file
      end
    
    rescue => e
      return
    end
  end

  def query(company_id)
    begin
      query = <<-SQL
        (
        SELECT c.id AS "CompanyId", c.name AS "Company", u.id AS "UserId",
         u.first_name AS "UserFirstName", u.last_name AS "UserLastName",
          ct.name AS "TableName", cf.name as "FieldName", cs.id as "OldValue",
           cs.id as "NewValue", ctus.effective_date AS "EffectiveDate",
            ctus.id AS "RequestId", u2.first_name AS "RequestedByFirstName",
             u2.last_name AS "RequestedByLastName", ctus.created_at AS "RequestedDate",
              cta.id AS "ApprovalStepId", cta.approval_date AS "ApprovedOn",
               u3.first_name AS "ApproverFirstName", u3.last_name AS "ApproverLastName",
                ctus.updated_at AS "TableUpdated"
        FROM companies as c
        JOIN users as u
          ON c.id = u.company_id
        JOIN custom_table_user_snapshots as ctus
          ON u.id = ctus.user_id
        JOIN custom_tables as ct
          ON ctus.custom_table_id = ct.id
        JOIN custom_fields as cf
          ON ct.id = cf.custom_table_id
        JOIN custom_snapshots as cs
          ON cs.custom_table_user_snapshot_id = ctus.id AND cs.custom_field_id = cf.id
        JOIN ctus_approval_chains as cta
          ON ctus.id = cta.custom_table_user_snapshot_id
        JOIN users as u2
          ON ctus.requester_id = u2.id
        JOIN users as u3
          ON cta.approved_by_id = u3.id
        WHERE (c.account_state = 'active' AND cta.request_state = 2 AND c.id = ?)
        ORDER BY ctus.effective_date DESC, cta.approval_date DESC, cta.id DESC, u.last_name, u.first_name
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
end

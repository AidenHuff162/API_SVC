module PendingHireServices
  class GetCsvData

    def perform(ids, current_company)
        csv_data = [["Name", "Job Title", "Department", "Location", "Manager", "Start Date", "Status"]]
        current_company.pending_hires.where(id: ids).each do |pending_hire|
    		start_date = TimeConversionService.new(current_company).perform(pending_hire.start_date.to_date) rescue pending_hire.start_date if pending_hire.start_date.present?
            csv_data << [pending_hire.full_name, pending_hire.title, pending_hire.team_name, pending_hire.location_name, pending_hire.manager_name, start_date, pending_hire.employee_type ]
      end if ids
      return csv_data
    end

  end
end

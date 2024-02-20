class CsvUploadTimeOffJob < ApplicationJob
  queue_as :pto_activities

  def perform params, current_company
    Pto::PtoPolicyBusinessLogic.new(params, current_company).upload_balance
  end
end

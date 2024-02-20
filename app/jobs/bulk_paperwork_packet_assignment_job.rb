class BulkPaperworkPacketAssignmentJob < ApplicationJob
  queue_as :bulk_assign_packets

  def perform(current_company, current_user, params)
    BulkAssignPaperworkPacketService.new(current_company, current_user, params).perform
  end
end
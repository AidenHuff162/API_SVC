#Commented for V2

class RoiEmailManagementServices::CalculateWeeklySpanBasedStatistics
#   attr_reader :company, :begin_date, :end_date

#   def initialize(company, begin_date, end_date)
#     @company = company
#     @begin_date = begin_date
#     @end_date = end_date
#   end

#   def perform
#     fetch_statistics
#   end

#   private

#   def build_attributes
#     attributes = {}

#     attributes[:paperwork_requests] = PaperworkRequest.company_based(@company.id)
#     attributes[:task_user_connections] = TaskUserConnection.company_based(@company.id)

#     attributes
#   end

#   def calculate_growth(first_week_statistics, second_week_statistics)
#     total_week_statistics = first_week_statistics + second_week_statistics

#     first_week_growth = (first_week_statistics/total_week_statistics)*100
#     second_week_growth = (second_week_statistics/total_week_statistics)*100

#     second_week_growth - first_week_growth
#   end

#   def calculate_statistics(first_week_statistics, second_week_statistics)
#     statistics = second_week_statistics

#     assigned_tasks_growth = calculate_growth(first_week_statistics[:assigned_tasks_count], second_week_statistics[:assigned_tasks_count])
#     completed_tasks_growth = calculate_growth(first_week_statistics[:completed_tasks_count], second_week_statistics[:completed_tasks_count])
#     pending_tasks_growth = calculate_growth(first_week_statistics[:pending_tasks_count], second_week_statistics[:pending_tasks_count])
    
#     statistics[:assigned_tasks_growth] = assigned_tasks_growth.abs
#     statistics[:completed_tasks_growth] = completed_tasks_growth.abs
#     statistics[:pending_tasks_growth] = pending_tasks_growth.abs

#     statistics[:negative_assigned_tasks_growth] = assigned_tasks_growth.negative?
#     statistics[:negative_completed_tasks_growth] = completed_tasks_growth.negative?
#     statistics[:negative_pending_tasks_growth] = pending_tasks_growth.negative?

#     assigned_ptos_growth = calculate_growth(first_week_statistics[:assigned_ptos_count], second_week_statistics[:assigned_ptos_count])
#     approved_ptos_growth = calculate_growth(first_week_statistics[:approved_ptos_count], second_week_statistics[:approved_ptos_count])
#     pending_ptos_growth = calculate_growth(first_week_statistics[:pending_ptos_count], second_week_statistics[:pending_ptos_count])

#     statistics[:assigned_ptos_growth] = assigned_ptos_growth.abs
#     statistics[:approved_ptos_growth] = approved_ptos_growth.abs
#     statistics[:pending_ptos_growth] = pending_ptos_growth.abs

#     statistics[:negative_assigned_ptos_growth] = assigned_ptos_growth.negative?
#     statistics[:negative_approved_ptos_growth] = approved_ptos_growth.negative?
#     statistics[:negative_pending_ptos_growth] = pending_ptos_growth.negative?

#     statistics
#   end

#   def fetch_statistics
#     attributes = build_attributes

#     first_week_statistics = RoiEmailManagementServices::CalculateWeeklyStatistics.new(@company, @begin_date, attributes).perform

#     attributes[:pto_requests] = PtoRequest.company_based(@company.id)
#     second_week_statistics = RoiEmailManagementServices::CalculateWeeklyStatistics.new(@company, @end_date, attributes).perform

#     calculate_statistics(first_week_statistics, second_week_statistics)
#   end
end
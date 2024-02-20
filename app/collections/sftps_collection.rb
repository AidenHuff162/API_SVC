class SftpsCollection < BaseCollection
  private

  def relation
    @relation ||= Sftp.all
  end

 def ensure_filters
    company_filter
    sorting_filter
  end
  
  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id])} if params[:company_id]
  end

  def sorting_filter
    if params[:order_column] && params[:sort_order]
      sort_order = params[:sort_order].downcase == 'asc' ? 'asc' : 'desc'
      if params[:order_column] == 'name'
        filter { |relation| relation.reorder("sftps.name #{sort_order}") }
      elsif params[:order_column] == 'updated_at'
        filter { |relation| relation.reorder("sftps.updated_at #{sort_order}") }
      end 
    end 
  end
end

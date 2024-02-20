class CompaniesCollection < BaseCollection
  private

  def relation
    @relation ||= Company.all
  end

  def ensure_filters
    activated_filter
    email_filter
  end

  def activated_filter
    filter { |relation| relation.where(deleted_at: nil) }
  end

  def email_filter
    if params[:email]
      filter { |relation| relation.where('LOWER(email) = LOWER(?)', params[:email]) }
    end
  end
end

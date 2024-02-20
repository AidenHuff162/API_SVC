class BaseCollection
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    @results ||= begin
      ensure_filters
      relation
      paginate
    end
  end

  def meta
    { total: total }
  end

  def total
    results.size
  end

  def meta_without_duplicate_keys
    duplicate_meta = meta
    duplicate_meta[:total].transform_keys!{ |key| key.kind_of?(Array)? key.first : key } unless duplicate_meta[:total].blank?
    duplicate_meta[:tuc_counts].transform_keys!{ |key| key.kind_of?(Array)? key.first : key } unless duplicate_meta[:tuc_counts].blank?
    duplicate_meta
  end

  def paginate
    if params[:page]
      @relation.paginate(per_page: params[:per_page], page: params[:page])
    else
      @relation
    end
  end

  def count
    @relation.count
  end

  private

  def filter
    @relation = yield(relation)
  end

  def relation
    fail(NotImplementedError)
  end

  def ensure_filters
    fail(NotImplementedError)
  end
end

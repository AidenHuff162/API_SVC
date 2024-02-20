class SubdomainValidator < ActiveModel::EachValidator
  START_END_HYPHEN_PATTERN = /\A[^-].*[^-]\z/i
  ALPHANUMERIC_PATTERN = /\A[a-z0-9\-]*\z/i

  def validate_each(object, attribute, value)
    return if value.blank?

    object.errors.add(attribute, :reserved_subdomain, subdomain: value) if reserved.include?(value)
    object.errors.add(attribute, :start_end_hyphen) unless value =~ START_END_HYPHEN_PATTERN
    object.errors.add(attribute, :alphanumeric) unless value =~ ALPHANUMERIC_PATTERN
  end

  private

  def reserved
    @reserved ||= options[:reserved] || []
  end
end

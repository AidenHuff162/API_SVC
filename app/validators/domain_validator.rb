class DomainValidator < ActiveModel::EachValidator
  HOSTNAME_PATTERN = /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}\z/i

  def validate_each(object, attribute, value)
    return if value.blank?

    object.errors.add(attribute, :bad_format) unless value =~ HOSTNAME_PATTERN
  end
end

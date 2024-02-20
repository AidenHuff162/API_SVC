class UniquenessValidator < ActiveRecord::Validations::UniquenessValidator
  def initialize(options)
    super
    @klass = options[:model] if options[:model]
  end

  def validate_each(record, attribute, value)
    if !options[:model] && !record.class.ancestors.include?(ActiveRecord::Base)
      raise ArgumentError, "Unknown validator: 'UniquenessValidator'"
    elsif !options[:model]
      super
    elsif record.class.ancestors.include?(BaseForm)
      record_org, attribute_org = record, attribute
      attribute = options[:attribute].to_sym if options[:attribute]
      form = record
      record = record.record
      record[options[:scope]] = form[options[:scope]] if options[:scope]

      super

      if record.errors.added?(attribute, :taken)
        record_org.errors.add(attribute_org, :taken,
          options.except(:case_sensitive, :scope).merge(value: value))
      end
    end
  end
end

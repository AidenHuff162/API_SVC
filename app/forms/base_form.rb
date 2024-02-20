class BaseForm
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include Virtus.model
  include ActiveModel::Serialization

  delegate :read_attribute_for_serialization, to: :record

  PLURAL_RELATIONS = []
  SINGULAR_RELATIONS = []

  attribute :id, Integer
  attribute :_destroy, String

  def self.presents(name)
    define_method name do
      record
    end
  end

  def save
    if valid?
      persist!
      true
    else
      false
    end
  end

  def save!
    save || raise(ActiveRecord::RecordInvalid.new(self))
  end

  def valid?
    [super, singular_relations_valid?, plural_relations_valid?].reduce(:&)
  end

  def record
    @record ||= id ? model_class.find(id) : model_class.new
  end

  def initialize(*)
    super
    self::class.attribute_set.map(&:name).each do |attr_name|
      self::class.send(:define_method, "#{attr_name}_changed?") do
        !(record.attributes[attr_name.to_s].eql?(attributes[attr_name]))
      end
    end
    self.attributes = record.attributes.merge(attributes.compact).with_indifferent_access
  end

  def save_attributes
    attributes.except(
      *self.class::PLURAL_RELATIONS,
      *self.class::SINGULAR_RELATIONS,
      :_destroy
    ).compact
  end

  def should_be_destroyed?(relation)
    id && _destroy && relation.include?(record)
  end

  def assign_with_relations
    record.assign_attributes(save_attributes)
    assign_singular_relations
    assign_plural_relations
  end

  private

  def relations_valid?(relations_list)
    relations_list.map do |key|
      yield(self.public_send(key), key)
    end.flatten.compact.reduce(:&).tap do |result|
      return true if result.nil?
    end
  end

  def plural_relations_valid?
    relations_valid?(self.class::PLURAL_RELATIONS) do |relation, key|
      if relation.present?
        relation.map do |relation_form|
          relation_form.valid?.tap do |valid|
            populate_relation_errors(key, relation_form)
          end
        end
      end
    end
  end

  def populate_relation_errors(relation_key, relation)
    relation.errors.messages.each do |column_key, error_list|
      error_list.each do |error|
        errors.messages[relation_key] ||= {}
        errors.messages[relation_key][column_key] ||= []
        unless errors.messages[relation_key][column_key].include?(error)
          errors.messages[relation_key][column_key] << error
        end
      end
    end
  end

  def singular_relations_valid?
    relations_valid?(self.class::SINGULAR_RELATIONS) do |relation, key|
      relation.blank? || relation.valid?.tap do |valid|
        populate_relation_errors(key, relation)
      end
    end
  end

  def persist!
    assign_with_relations
    record.save!
  end

  def assign_relations(relations_list)
    relations_list.each do |key|
      relation = self.public_send(key)
      model_relation = record.public_send(key)
      if relation.present?
        record.public_send("#{key}=", yield(relation, model_relation))
      end
    end
  end

  def assign_singular_relations
    assign_relations(self.class::SINGULAR_RELATIONS) do |relation_form|
      relation_form.assign_with_relations
      relation_form.record
    end
  end

  def records_to_destroy(records, relations)
    records.select { |rec| rec.should_be_destroyed?(relation) }
  end

  def assign_plural_relations
    assign_relations(self.class::PLURAL_RELATIONS) do |plural_relation, model_relation|
      records_to_destroy = plural_relation.select do |rec|
        rec.should_be_destroyed?(model_relation)
      end
      records_to_destroy.map(&:record).map(&:destroy!)
      (plural_relation - records_to_destroy).map do |relation_form|
        relation_form.assign_with_relations
        relation_form.record
      end
    end
  end

  def iterate_relations(relations_list)
    relations_list.each do |key|
      relation = self.public_send(key)
      yield(key, relation) if relation.present?
    end
  end

  def model_class
    self.class.to_s.gsub(/Form/, '').tap do |class_name|
      fail(NotImplementedError) if class_name == 'Base'
    end.constantize
  end
end

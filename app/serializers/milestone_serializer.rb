class MilestoneSerializer < ActiveModel::Serializer

  def self.eager_load_relation(relation)
    relation.includes(:milestone_image)
  end

  attributes :id, :name, :happened_at, :description, :position, :milestone_image_size
  has_one :milestone_image

  def milestone_image_size
    image_info = {}
    if object && object.milestone_image.present? && object.milestone_image.image_size.present?
      image_size = object.milestone_image.image_size
    else
      image_size = {width: 0}
    end
    image_info[:width] = image_size[:width]
    image_info
  end

end

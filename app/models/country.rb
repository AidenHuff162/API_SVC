class Country < ApplicationRecord
  include Orderable

  has_many :states, dependent: :destroy
end

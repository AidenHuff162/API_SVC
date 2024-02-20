class PolicyTenureship < ApplicationRecord
  belongs_to :pto_policy
  validates :year, :amount, presence: true
  validate :amount_is_greater_than_zero?

  private
  def amount_is_greater_than_zero?
    if self.amount && self.amount <= 0
      self.errors.add("The", I18n.t('errors.policy_tenureship_amount').to_s)
    end
  end
end

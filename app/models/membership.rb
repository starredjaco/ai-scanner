# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :user_id, uniqueness: { scope: :company_id, message: "already belongs to this company" }

  def self.ransackable_attributes(auth_object = nil)
    %w[id user_id company_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user company]
  end
end

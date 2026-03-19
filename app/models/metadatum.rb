class Metadatum < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.ransackable_attributes(auth_object = nil)
    [ "created_at", "id", "key", "updated_at", "value" ]
  end
end

class TaxonomyCategory < ApplicationRecord
  has_and_belongs_to_many :probes

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def self.ransackable_attributes(auth_object = nil)
    [ "created_at", "id", "id_value", "name", "updated_at" ]
  end
end

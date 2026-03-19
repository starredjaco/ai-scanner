class EnvironmentVariable < ApplicationRecord
  acts_as_tenant :company
  belongs_to :target, optional: true

  encrypts :env_value, key_provider: Encryption::TenantKeyProvider.new

  validates :env_name, presence: true,
                      format: { with: /\A[A-Za-z_][A-Za-z0-9_]*\z/, message: "must be a valid environment variable name" }
  validates :env_name, uniqueness: { scope: [ :company_id, :target_id ] }
  validates :env_value, presence: true

  scope :global, -> { where(target_id: nil) }

  def self.ransackable_attributes(auth_object = nil)
    [ "created_at", "env_name", "id", "target_id", "updated_at" ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "target" ]
  end
end

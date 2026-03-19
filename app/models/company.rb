# frozen_string_literal: true

class Company < ApplicationRecord
  # OSS defaults: all features unlocked, no limits.
  # Engine overrides these with tier-based behavior.
  include OssDefaults

  # M:N relationship with users via memberships
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  has_many :targets, dependent: :destroy
  has_many :scans, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :output_servers, dependent: :destroy

  # Keep tier enum for column compatibility (engine overrides behavior)
  enum :tier, {
    tier_1: 0,
    tier_2: 1,
    tier_3: 2,
    tier_4: 3
  }, default: :tier_1

  validates :name, presence: true
  validates :slug, uniqueness: true  # Presence ensured by generate_slug callback
  validates :tier, presence: true

  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  # Incremented when a pending scan is claimed for starting
  def increment_scan_count!
    self.class.where(id: id).update_all(
      "weekly_scan_count = weekly_scan_count + 1, total_scans_count = total_scans_count + 1, updated_at = NOW()"
    )
    reload
  end

  # Reverts the count when a scan fails or is stopped
  def decrement_scan_count!
    self.class.where(id: id).update_all(
      "weekly_scan_count = GREATEST(weekly_scan_count - 1, 0), total_scans_count = GREATEST(total_scans_count - 1, 0), updated_at = NOW()"
    )
    reload
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id name slug external_id tier weekly_scan_count total_scans_count created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[users memberships targets scans reports output_servers]
  end

  private

  def generate_slug
    base_slug = name.to_s.parameterize
    self.slug = base_slug

    counter = 1
    while Company.exists?(slug: slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end

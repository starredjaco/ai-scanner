# frozen_string_literal: true

# OSS defaults for Company - all features unlocked, no limits.
# The engine overrides these with tier-based behavior.
module OssDefaults
  extend ActiveSupport::Concern

  def scan_allowed?
    true
  end

  def scans_remaining
    Float::INFINITY
  end

  def can_add_user?
    true
  end

  def users_remaining
    Float::INFINITY
  end

  def can_use?(_feature)
    true
  end

  def unlimited_scans?
    true
  end

  def scans_per_week_limit
    nil
  end
end

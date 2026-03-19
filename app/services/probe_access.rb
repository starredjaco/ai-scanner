# frozen_string_literal: true

# Service to filter available probes based on company access level.
# OSS default: all enabled probes are accessible to all companies.
#
# The engine overrides this with tier-based hash filtering via
# Scanner.configuration.probe_access_class.
#
# Usage:
#   probe_access = ProbeAccess.new(company)
#   probe_access.accessible_probes          # => ActiveRecord::Relation
#   probe_access.can_access?(probe)         # => true/false
#   probe_access.filter_accessible(probes)  # => filtered relation
#
class ProbeAccess
  attr_reader :company

  def initialize(company)
    @company = company
  end

  # Returns ActiveRecord::Relation of accessible probes
  def accessible_probes
    Probe.enabled
  end

  # Check if a specific probe is accessible
  def can_access?(probe)
    probe&.enabled? || false
  end

  # Filter a collection of probes to only accessible ones
  def filter_accessible(probes)
    probes.enabled
  end

  # Count of accessible probes
  def accessible_count
    Probe.enabled.count
  end
end

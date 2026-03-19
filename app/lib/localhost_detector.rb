# Utility module for detecting localhost across different contexts
# Provides a single source of truth for localhost detection logic
# that can be reused by controllers, helpers, and ActionCable connections
module LocalhostDetector
  # Localhost hostnames to check against
  LOCALHOST_HOSTS = [ "localhost", "127.0.0.1", "::1" ].freeze

  # Regex pattern for 127.0.0.x IP range
  LOCALHOST_IP_RANGE = /\A127\.0\.0\.\d{1,3}\z/.freeze

  # Check if a given host is localhost
  # @param host [String] the hostname to check
  # @return [Boolean] true if the host is localhost
  def self.localhost?(host)
    return false if host.nil? || host.empty?

    LOCALHOST_HOSTS.include?(host) || host.match?(LOCALHOST_IP_RANGE)
  end
end

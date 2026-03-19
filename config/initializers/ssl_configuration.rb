# SSL Configuration for Production Environment
# This initializer ensures proper protocol handling in production,
# with special handling for localhost to allow HTTP access

if Rails.env.production?
  # Middleware to handle SSL assumptions based on host
  class LocalhostSSLMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      # Check if this is a localhost request (including IPv6)
      localhost_hosts = [ "localhost", "127.0.0.1", "::1" ]
      is_localhost = localhost_hosts.include?(request.host) ||
                     request.host.match?(/\A127\.0\.0\.\d{1,3}\z/)

      # Store in request env for other parts of the app to use
      env["rack.is_localhost"] = is_localhost

      # For localhost, ensure we don't assume SSL unless explicitly set
      if is_localhost && ENV.fetch("ASSUME_SSL", "false") != "true"
        # Temporarily disable SSL assumptions for this request
        env["rack.url_scheme"] = request.headers["X-Forwarded-Proto"] || request.scheme
      end

      @app.call(env)
    end
  end

  # Insert our middleware early in the stack
  # ActionDispatch::SSL is only present when force_ssl is true, so insert before a different middleware
  Rails.application.config.middleware.insert_before ActionDispatch::Cookies, LocalhostSSLMiddleware

  # Override URL generation to respect localhost HTTP access
  ActionController::Base.class_eval do
    # Override url_for to handle localhost properly
    def url_for(options = nil)
      if options.is_a?(Hash) && request
        localhost_hosts = [ "localhost", "127.0.0.1", "::1" ]
        is_localhost = localhost_hosts.include?(request.host) ||
                       request.host.match?(/\A127\.0\.0\.\d{1,3}\z/)

        # For localhost, always respect the actual protocol
        if is_localhost && !options.key?(:protocol)
          # Check X-Forwarded-Proto header set by load balancer/ingress
          forwarded_proto = request.headers["X-Forwarded-Proto"]
          actual_protocol = forwarded_proto.presence || request.protocol
          options = options.merge(protocol: actual_protocol.sub("://", ""))
        elsif !is_localhost && !options.key?(:protocol) && ENV.fetch("ASSUME_SSL", "false") != "true"
          # For non-localhost, still respect X-Forwarded-Proto if ASSUME_SSL is not true
          forwarded_proto = request.headers["X-Forwarded-Proto"]
          if forwarded_proto.present?
            options = options.merge(protocol: forwarded_proto)
          end
        end
      end
      super(options)
    end
  end
end

module OutputServers
  class Rsyslog
    attr_reader :report

    def initialize(report)
      @report = report
    end

    def call
      return unless output_server
      return unless output_server.enabled
      return unless output_server.server_type == "rsyslog"

      begin
        case output_server.protocol
        when "udp"
          send_via_udp
        when "tcp"
          send_via_tcp
        when "tls"
          send_via_tls
        when "http", "https"
          send_via_http
        else
          Rails.logger.error "Unsupported protocol for RSyslog: #{output_server.protocol}"
        end
      rescue => e
        Rails.logger.error "Failed to send data to RSyslog: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    private

    def output_server
      report.scan.output_server
    end

    def send_via_udp
      socket = UDPSocket.new
      message = format_syslog_message

      begin
        socket.send(message, 0, output_server.host, output_server.port || 514)
        Rails.logger.info "Successfully sent report data to RSyslog (UDP) server: #{report.uuid}"
      rescue => e
        Rails.logger.error "Failed to send data to RSyslog via UDP: #{e.message}"
      ensure
        socket.close
      end
    end

    def send_via_tcp
      socket = TCPSocket.new(output_server.host, output_server.port || 514)
      message = format_syslog_message

      begin
        socket.puts(message)
        Rails.logger.info "Successfully sent report data to RSyslog (TCP) server: #{report.uuid}"
      rescue => e
        Rails.logger.error "Failed to send data to RSyslog via TCP: #{e.message}"
      ensure
        socket.close
      end
    end

    def send_via_tls
      context = OpenSSL::SSL::SSLContext.new

      # Apply additional TLS settings if available
      if output_server.additional_settings.present?
        begin
          settings = JSON.parse(output_server.additional_settings)

          # Add client certificates if provided
          if settings["tls_cert_file"] && settings["tls_key_file"]
            context.cert = OpenSSL::X509::Certificate.new(File.read(settings["tls_cert_file"]))
            context.key = OpenSSL::PKey::RSA.new(File.read(settings["tls_key_file"]))
          end

          # Add CA certificate if provided
          if settings["ca_file"]
            context.ca_file = settings["ca_file"]
            context.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Invalid additional_settings JSON: #{e.message}"
        end
      end

      tcp_socket = TCPSocket.new(output_server.host, output_server.port || 6514)
      ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, context)
      ssl_socket.connect

      message = format_syslog_message

      begin
        ssl_socket.puts(message)
        Rails.logger.info "Successfully sent report data to RSyslog (TLS) server: #{report.uuid}"
      rescue => e
        Rails.logger.error "Failed to send data to RSyslog via TLS: #{e.message}"
      ensure
        ssl_socket.close
        tcp_socket.close
      end
    end

    def send_via_http
      require "net/http"

      uri = URI.parse(output_server.connection_string)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (output_server.protocol == "https")

      request = Net::HTTP::Post.new(uri.request_uri)
      setup_headers(request)
      request.body = prepare_data.to_json

      begin
        response = http.request(request)
        if response.code.to_i >= 200 && response.code.to_i < 300
          Rails.logger.info "Successfully sent report data to RSyslog (HTTP) server: #{report.uuid}"
        else
          Rails.logger.error "Failed to send data to RSyslog. Status: #{response.code}, Body: #{response.body}"
        end
      rescue => e
        Rails.logger.error "Failed to send data to RSyslog via HTTP: #{e.message}"
      end
    end

    def setup_headers(request)
      request.content_type = "application/json"

      case output_server.authentication_method
      when :token
        request["Authorization"] = "Bearer #{output_server.access_token}"
      when :api_key
        request["X-API-Key"] = output_server.api_key
      when :basic
        request.basic_auth(output_server.username, output_server.password)
      end

      if output_server.additional_settings.present?
        begin
          settings = JSON.parse(output_server.additional_settings)
          if settings["headers"].is_a?(Hash)
            settings["headers"].each do |key, value|
              request[key] = value
            end
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Invalid additional_settings JSON: #{e.message}"
        end
      end
    end

    def format_syslog_message
      msg = SyslogProtocol::Packet.new

      # Set standard syslog fields
      msg.hostname = BrandConfig.host_url&.gsub(%r{https?://}, "") || "scanner.local"
      msg.facility = "local0"
      msg.severity = "info"
      msg.tag = "scanner_app"

      message_data = {
        report_id: report.id,
        report_uuid: report.uuid,
        report_name: report.name,
        report_status: report.status,
        scan_id: report.scan_id,
        scan_name: report.scan&.name,
        target_id: report.target_id,
        target_name: report.target&.name,
        target_model: report.target&.model,
        target_model_type: report.target&.model_type,
        created_at: report.created_at,
        updated_at: report.updated_at,
        probe_results_count: report.probe_results.count,
        detector_stats: report.detector_results_as_hash
      }

      msg.content = message_data.to_json
      msg.to_s
    end

    def prepare_data
      {
        timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
        hostname: BrandConfig.host_url&.gsub(%r{https?://}, "") || "scanner.local",
        source: "scanner_app",
        event: {
          report_id: report.id,
          report_uuid: report.uuid,
          report_name: report.name,
          report_status: report.status,
          scan_id: report.scan_id,
          scan_name: report.scan.name,
          target_id: report.target_id,
          target_name: report.target.name,
          target_model: report.target.model,
          target_model_type: report.target.model_type,
          created_at: report.created_at,
          updated_at: report.updated_at,
          probe_results_count: report.probe_results.count,
          detector_stats: report.detector_results_as_hash
        }
      }
    end
  end
end

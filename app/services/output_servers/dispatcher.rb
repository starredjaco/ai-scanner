module OutputServers
  class Dispatcher
    attr_reader :report

    def initialize(report)
      @report = report
    end

    def call
      return unless output_server
      return unless output_server.enabled

      service = case output_server.server_type
      when "splunk"
                  OutputServers::Splunk
      when "rsyslog"
                  OutputServers::Rsyslog
      else
                  Rails.logger.error "Unsupported output server type: #{output_server.server_type}"
                  return
      end

      service.new(report).call
    rescue => e
      Rails.logger.error "Failed to dispatch to output server: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    private

    def output_server
      report.scan.output_server
    end
  end
end

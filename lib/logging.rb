module Logging
  def self.with(hash)
    orig_context = context.dup
    context.merge!(hash)
    yield
  ensure
    Thread.current[:fs_log_context] = orig_context
  end

  def self.context
    Thread.current[:fs_log_context] ||= {}
  end

  class JSONFormatter < ::Logger::Formatter
    def call(level, time, progname, message)
      message ||= ""
      level ||= ""

      {
        level: level,
        progname: progname,
        message: message
      }.merge(Logging.context).compact.to_json + "\r\n"
    end
  end
end

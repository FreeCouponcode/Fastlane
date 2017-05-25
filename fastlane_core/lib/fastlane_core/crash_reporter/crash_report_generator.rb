module FastlaneCore
  class CrashReportGenerator
    class << self
      def generate(exception: nil, action: nil)
        message = format_crash_report_message(exception: exception)
        crash_report_payload(message: message, action: action)
      end

      private

      def format_crash_report_message(exception: nil)
        return if exception.nil?
        backtrace = exception.respond_to?(:trimmed_backtrace) ? exception.trimmed_backtrace : exception.backtrace
        backtrace = FastlaneCore::CrashReportSanitizer.sanitize_backtrace(backtrace: backtrace).join("\n")

        if crash_came_from_plugin?(exception: exception)
          message = '[PLUGIN_CRASH]'
        elsif exception.respond_to?(:prefix)
          message = exception.prefix
        else
          message = '[EXCEPTION]'
        end

        message += ': '

        if exception.respond_to?(:crash_report_message)
          exception_message = FastlaneCore::CrashReportSanitizer.sanitize_string(string: exception.crash_report_message)
        else
          exception_message = "#{exception.class.name}: #{FastlaneCore::CrashReportSanitizer.sanitize_string(string: exception.message)}"
        end

        message += exception_message
        message = message[0..100]
        message += "\n" unless exception.respond_to?(:could_contain_pii?) && exception.could_contain_pii?
        message + backtrace
      end

      def crash_came_from_plugin?(exception: nil)
        return false if exception.nil?
        plugin_frame = exception.backtrace.find { |frame| frame.include?('fastlane-plugin-') }
        !plugin_frame.nil?
      end

      def crash_report_payload(message: '', action: nil)
        {
          'eventTime' => Time.now.utc.to_datetime.rfc3339,
          'serviceContext' => {
            'service' => action || 'fastlane',
            'version' => Fastlane::VERSION
          },
          'message' => message
        }.to_json
      end
    end
  end
end

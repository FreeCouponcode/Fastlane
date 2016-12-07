module Scan
  class XCPrettyReporterOptionsGenerator
   
    SUPPORTED_REPORT_TYPES = %w(html junit json-compilation-database)

    # Intialize with values from Scan.config matching these param names
    def initialize(open_report, output_types, output_files, output_directory, use_clang_report_name)
      @open_report = open_report
      @output_types = output_types
      @output_files = output_files
      @output_directory = output_directory
      @use_clang_report_name = use_clang_report_name

      # might already be an array when passed via fastlane  
      @output_types = @output_types.split(',') if @output_types.kind_of?(String)

      if @output_files == nil
        @output_files = @output_types.map { |type| "report.#{type}" }
      elsif @output_files.kind_of?(String)
         # might already be an array when passed via fastlane
        @output_files.split(',')
      end

      unless @output_types.length == @output_files.length
        UI.important("WARNING: output_types and output_files do not have the same number of items. Default values will be substituted as needed.")
      end
    end

    def generate_reporter_options
      reporter = []

      @output_types.each do |raw_type|
        type = raw_type.strip

        unless SUPPORTED_REPORT_TYPES.include?(type)
        UI.error("Couldn't find reporter '#{type}', available #{SUPPORTED_REPORT_TYPES.join(', ')}")
        next
        end

        output_path = File.join(File.expand_path(@output_directory), determine_output_file_name(type))
        reporter << "--report #{type}"
        reporter << "--output #{output_path}"

        if type == "html" && @open_report
          Scan.cache[:open_html_report_path] = output_path
        end
      end

      # adds another junit reporter in case the user does not specify one
      # this will be used to generate a results table and then discarded
      require 'tempfile'
      Scan.cache[:temp_junit_report] = Tempfile.new("junit_report").path
      reporter << "--report junit"
      reporter << "--output #{Scan.cache[:temp_junit_report]}"
      return reporter
    end

    def determine_output_file_name(type)
      if @use_clang_report_name && type == "json-compilation-database"
        return "compile_commands.json"
      end

      index = @output_types.index(type)
      file = @output_files[index]
      file || "report.#{type}"
    end
  end
end
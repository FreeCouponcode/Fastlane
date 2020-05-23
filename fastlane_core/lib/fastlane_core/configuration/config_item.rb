require_relative '../ui/ui'
require_relative '../ui/errors/fastlane_error'
require_relative '../helper'
require_relative '../module'
require 'json'

module FastlaneCore
  class ConfigItem
    # [Symbol] the key which is used as command parameters or key in the fastlane tools
    attr_accessor :key

    # [String] the name of the environment variable, which is only used if no other values were found
    attr_accessor :env_name

    # [String] A description shown to the user
    attr_accessor :description

    # [String] A string of length 1 which is used for the command parameters (e.g. -f)
    attr_accessor :short_option

    # the value which is used if there was no given values and no environment values
    attr_accessor :default_value

    # [Boolean] Set if the default value is generated dynamically
    attr_accessor :default_value_dynamic

    # the value which is used during Swift code generation
    #   if the default_value reads from ENV or a file, or from local credentials, we need
    #   to provide a different default or it might be included in our autogenerated Swift
    #   as a built-in default for the fastlane gem. This is because when we generate the
    #   Swift API at deployment time, it fetches the default_value from the config_items
    attr_accessor :code_gen_default_value

    # An optional block which is called when a new value is set.
    #   Check value is valid. This could be type checks or if a folder/file exists
    #   You have to raise a specific exception if something goes wrong. Use `user_error!` for the message: UI.user_error!("your message")
    attr_accessor :verify_block

    # [Boolean] is false by default. If set to true, also string values will not be asked to the user
    attr_accessor :optional

    # [Boolean] is false by default. If set to true, type of the parameter will not be validated.
    attr_accessor :skip_type_validation

    # [Array] array of conflicting option keys(@param key). This allows to resolve conflicts intelligently
    attr_accessor :conflicting_options

    # An optional block which is called when options conflict happens
    attr_accessor :conflict_block

    # [String] Set if the option is deprecated. A deprecated option should be optional and is made optional if the parameter isn't set, and fails otherwise
    attr_accessor :deprecated

    # [Boolean] Set if the variable is sensitive, such as a password or API token, to prevent echoing when prompted for the parameter
    # If a default value exists, it won't be used during code generation as default values can read from environment variables.
    attr_accessor :sensitive

    # [Boolean] Set if the default value should never be used during code generation for Swift
    #   We generate the Swift API at deployment time, and if there is a value that should never be
    #   included in the Fastlane.swift or other autogenerated classes, we need to strip it out.
    #   This includes things like API keys that could be read from ENV[]
    attr_accessor :code_gen_sensitive

    # [Boolean] Set if the variable is to be converted to a shell-escaped String when provided as a Hash or Array
    # Allows items expected to be strings used in shell arguments to be alternatively provided as a Hash or Array for better readability and auto-escaped for us.
    attr_accessor :allow_shell_conversion

    # [Boolean] Set if the variable can be used from shell
    attr_accessor :display_in_shell

    # Creates a new option
    # @param key (Symbol) the key which is used as command parameters or key in the fastlane tools
    # @param env_name (String) the name of the environment variable, which is only used if no other values were found
    # @param description (String) A description shown to the user
    # @param short_option (String) A string of length 1 which is used for the command parameters (e.g. -f)
    # @param default_value the value which is used if there was no given values and no environment values
    # @param default_value_dynamic (Boolean) Set if the default value is generated dynamically
    # @param verify_block an optional block which is called when a new value is set.
    #   Check value is valid. This could be type checks or if a folder/file exists
    #   You have to raise a specific exception if something goes wrong. Append .red after the string
    # @param is_string *DEPRECATED: Use `type` instead* (Boolean) is that parameter a string? Defaults to true. If it's true, the type string will be verified.
    # @param type (Class) the data type of this config item. Takes precedence over `is_string`. Use `:shell_string` to allow types `String`, `Hash` and `Array` that will be converted to shell-escaped strings
    # @param skip_type_validation (Boolean) is false by default. If set to true, type of the parameter will not be validated.
    # @param optional (Boolean) is false by default. If set to true, also string values will not be asked to the user
    # @param conflicting_options ([]) array of conflicting option keys(@param key). This allows to resolve conflicts intelligently
    # @param conflict_block an optional block which is called when options conflict happens
    # @param deprecated (Boolean|String) Set if the option is deprecated. A deprecated option should be optional and is made optional if the parameter isn't set, and fails otherwise
    # @param sensitive (Boolean) Set if the variable is sensitive, such as a password or API token, to prevent echoing when prompted for the parameter
    # @param display_in_shell (Boolean) Set if the variable can be used from shell
    # rubocop:disable Metrics/ParameterLists
    def initialize(key: nil,
                   env_name: nil,
                   description: nil,
                   short_option: nil,
                   default_value: nil,
                   default_value_dynamic: false,
                   verify_block: nil,
                   is_string: true,
                   type: nil,
                   skip_type_validation: false,
                   optional: nil,
                   conflicting_options: nil,
                   conflict_block: nil,
                   deprecated: nil,
                   sensitive: nil,
                   code_gen_sensitive: false,
                   code_gen_default_value: nil,
                   display_in_shell: true)
      UI.user_error!("key must be a symbol") unless key.kind_of?(Symbol)
      UI.user_error!("env_name must be a String") unless (env_name || '').kind_of?(String)

      if short_option
        UI.user_error!("short_option for key :#{key} must of type String") unless short_option.kind_of?(String)
        UI.user_error!("short_option for key :#{key} must be a string of length 1") unless short_option.delete('-').length == 1
      end

      if description
        UI.user_error!("Do not let descriptions end with a '.', since it's used for user inputs as well for key :#{key}") if description[-1] == '.'
      end

      if conflicting_options
        conflicting_options.each do |conflicting_option_key|
          UI.user_error!("Conflicting option key must be a symbol") unless conflicting_option_key.kind_of?(Symbol)
        end
      end

      if deprecated
        # deprecated options are automatically optional
        optional = true if optional.nil?
        UI.crash!("Deprecated option must be optional") unless optional

        # deprecated options are marked deprecated in their description
        description = deprecated_description(description, deprecated)
      end

      optional = false if optional.nil?
      sensitive = false if sensitive.nil?

      @key = key
      @env_name = env_name
      @description = description
      @short_option = short_option
      @default_value = default_value
      @default_value_dynamic = default_value_dynamic
      @verify_block = verify_block
      @is_string = is_string
      @data_type = type
      @data_type = String if type == :shell_string
      @optional = optional
      @conflicting_options = conflicting_options
      @conflict_block = conflict_block
      @deprecated = deprecated
      @sensitive = sensitive
      @code_gen_sensitive = code_gen_sensitive || sensitive
      @allow_shell_conversion = (type == :shell_string)
      @display_in_shell = display_in_shell
      @skip_type_validation = skip_type_validation # sometimes we allow multiple types which causes type validation failures, e.g.: export_options in gym

      @code_gen_default_value = code_gen_default_value

      update_code_gen_default_value_if_able!
    end
    # rubocop:enable Metrics/ParameterLists

    # if code_gen_default_value is nil, use the default value if it isn't a `code_gen_sensitive` value
    def update_code_gen_default_value_if_able!
      # we don't support default values for procs
      if @data_type == :string_callback
        @code_gen_default_value = nil
        return
      end

      if @code_gen_default_value.nil?
        unless @code_gen_sensitive

          @code_gen_default_value = @default_value
        end
      end
    end

    def verify!(value)
      valid?(value)
    end

    def ensure_generic_type_passes_validation(value)
      if @skip_type_validation
        return
      end

      if data_type != :string_callback && data_type && !value.kind_of?(data_type)
        UI.user_error!("'#{self.key}' value must be a #{data_type}! Found #{value.class} instead.")
      end
    end

    def ensure_boolean_type_passes_validation(value)
      if @skip_type_validation
        return
      end

      # We need to explicitly test against Fastlane::Boolean, TrueClass/FalseClass
      if value.class != FalseClass && value.class != TrueClass
        UI.user_error!("'#{self.key}' value must be either `true` or `false`! Found #{value.class} instead.")
      end
    end

    # Make sure, the value is valid (based on the verify block)
    # Raises an exception if the value is invalid
    def valid?(value)
      # we also allow nil values, which do not have to be verified.
      return true if value.nil?

      # Verify that value is the type that we're expecting, if we are expecting a type
      if data_type == Fastlane::Boolean
        ensure_boolean_type_passes_validation(value)
      else
        ensure_generic_type_passes_validation(value)
      end

      if @verify_block
        begin
          @verify_block.call(value)
        rescue => ex
          UI.error("Error setting value '#{value}' for option '#{@key}'")
          raise Interface::FastlaneError.new, ex.to_s
        end
      end

      true
    end

    # rubocop:disable Metrics/PerceivedComplexity
    # Returns an updated value type (if necessary)
    def auto_convert_value(value)
      return nil if value.nil?

      if data_type == Array
        return value.split(',') if value.kind_of?(String)
      elsif data_type == Integer
        return value.to_i if value.to_i.to_s == value.to_s
      elsif data_type == Float
        return value.to_f if value.to_f.to_s == value.to_s
      elsif allow_shell_conversion
        return value.shelljoin if value.kind_of?(Array)
        return value.map { |k, v| "#{k.to_s.shellescape}=#{v.shellescape}" }.join(' ') if value.kind_of?(Hash)
      elsif data_type == Hash && value.kind_of?(String)
        begin
          parsed = JSON.parse(value)
          return parsed if parsed.kind_of?(Hash)
        rescue JSON::ParserError
        end
      elsif data_type != String
        # Special treatment if the user specified true, false or YES, NO
        # There is no boolean type, so we just do it here
        if %w(YES yes true TRUE).include?(value)
          return true
        elsif %w(NO no false FALSE).include?(value)
          return false
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      return value # fallback to not doing anything
    end

    # Determines the defined data type of this ConfigItem
    def data_type
      if @data_type.kind_of?(Symbol)
        nil
      elsif @data_type
        @data_type
      else
        (@is_string ? String : nil)
      end
    end

    # Replaces the attr_accessor, but maintains the same interface
    def string?
      data_type == String
    end

    # it's preferred to use self.string? In most cases, except in commander_generator.rb, cause... reasons
    def is_string
      return @is_string
    end

    def to_s
      [@key, @description].join(": ")
    end

    def deprecated_description(initial_description, deprecated)
      has_description = !initial_description.to_s.empty?

      description = "**DEPRECATED!**"

      if deprecated.kind_of?(String)
        description << " #{deprecated}"
        description << " -" if has_description
      end

      description << " #{initial_description}" if has_description

      description
    end

    def doc_default_value
      return "[*](#parameters-legend-dynamic)" if self.default_value_dynamic
      return "" if self.default_value.nil?
      return "`''`" if self.default_value.instance_of?(String) && self.default_value.empty?
      return "`:#{self.default_value}`" if self.default_value.instance_of?(Symbol)

      "`#{self.default_value}`"
    end

    def help_default_value
      return "#{self.default_value} *".strip if self.default_value_dynamic
      return "" if self.default_value.nil?
      return "''" if self.default_value.instance_of?(String) && self.default_value.empty?
      return ":#{self.default_value}" if self.default_value.instance_of?(Symbol)

      self.default_value
    end
  end
end

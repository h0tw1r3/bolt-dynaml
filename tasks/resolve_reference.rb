#!/opt/puppetlabs/bolt/bin/ruby

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'erb'
require 'psych'
require 'deep_merge'

# Extends String with method for resolving embedded ERB
class String
  def resolve(b)
    replace ERB.new(self).result(b)
  end
end

# bolt resolver plugin
class Dynaml < TaskHelper
  def loadini(filename)
    sections = {}
    current_section = nil
    File.open(File.expand_path(filename)).each_line do |line|
      next if line.match?(%r{^#?\s*$})
      if line.start_with? '['
        current_section = line.match(%r{^\[(.*?)\]}).captures[0] rescue nil
        sections[current_section] = {}
      else
        key, value = line.match(%r{(\w+)\W*=\W*(.*)\W*}).captures rescue nil
        if key && value
          sections[current_section][key] = value
        end
      end
    end
    sections
  end

  # Generic validation error
  class ValidationError < TaskHelper::Error
    def initialize(m)
      super(m, 'bolt.plugin/validation-error')
    end
  end

  def recursive_resolve(obj, b)
    if obj.is_a? Hash
      obj.transform_values! { |v| recursive_resolve(v, b) }
    elsif obj.is_a? Array
      obj.map! { |v| recursive_resolve(v, b) }
    elsif obj.is_a? String and obj.include? "<%"
      begin
        obj.resolve(b)
      rescue
        raise ValidationError, "failed to resolve value: #{obj}"
      end
    else
      obj
    end
  end

  def yamlfile_var(filename, var)
    begin
      yaml = Psych.load_file(filename)
      return yaml[var]
    rescue Exception => e
      return "failed to find #{var} in #{filename}: #{e}"
    end
  end

  def validate_options(opts)
    return if opts.key?(:merge) && opts[:merge].key?(:key)
    return if opts.key?(:value)
    raise ValidationError, "require a valid 'merge' and/or 'value' parameter"
  end

  def task(opts)
    validate_options(opts)

    template = opts.key?(:merge) && opts[:merge].key?(:file) ? opts[:merge][:file] : 'override.yaml'
    value = opts.key?(:value) ? opts[:value] : nil
    debug = opts.key?(:debug)

    template_path = "#{opts[:_boltdir]}/#{template}"
    if File.exists?(template_path)
      @dynaml = Psych.safe_load(ERB.new(File.read(template_path)).result(binding), aliases: true, symbolize_names: true)
    elsif opts.key?(:merge)
      raise ValidationError, "#{template} file not found"
    end

    if opts.key?(:merge)
      section = opts[:merge][:key]
      local_section = @dynaml.key?(section.to_sym) ? @dynaml[section.to_sym] : nil
      if value.class == local_section.class && (local_section.is_a? Array or local_section.is_a? Hash)
        value.deep_merge!(local_section)
      else
        value = local_section if local_section
      end
    end

    # resolve values that contain erb
    recursive_resolve(value, binding)
    raise ValidationError, value if debug

    { 'value' => value }
  end
end

Dynaml.run if $PROGRAM_NAME == __FILE__

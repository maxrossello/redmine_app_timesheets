module TimesheetsAppTimeReportPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :run, :timelogs
    end

  end

  module InstanceMethods

    def run_with_timelogs
      @criteria << 'version2' unless @criteria.empty?

      # add count for timelogs applied to version (no issue, nor project)
      @available_criteria['version2'] = {:sql => "#{TimeEntry.table_name}.fixed_version_id",
                                         :klass => Version,
                                         :label => :label_version}   if @available_criteria
      run_without_timelogs

      @hours.each do |h|
        h['version'] ||= h['version2']
      end unless @criteria.empty?

      @criteria.delete('version2')
      @available_criteria.delete('version2') unless @available_criteria.nil?
      @hours
    end

  end

end


module TimesheetsAppTimeReportPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :run, :timelogs
      alias_method_chain :load_available_criteria, :timelogs
    end

  end

  module InstanceMethods

    def load_available_criteria_with_timelogs
      load_available_criteria_without_timelogs
      @available_criteria['version2'] = {:sql => "#{TimeEntry.table_name}.fixed_version_id",
                                         :klass => Version,
                                         :label => :label_version}
      @available_criteria
    end

    def run_with_timelogs
      @criteria << 'version2' unless @criteria.empty?
      run_without_timelogs
      @hours.each do |h|
        h['version'] ||= h['version2']
      end
      @criteria.delete('version2')
      @hours
    end

  end

end


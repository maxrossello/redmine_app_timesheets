module TimesheetsAppVersionPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :spent_hours, :timelogs
    end

  end

  module InstanceMethods

    def spent_hours_with_timelogs
      @spent_hours ||= TimeEntry.uniq.includes(:issue).where("#{TimeEntry.table_name}.fixed_version_id = ? OR #{Issue.table_name}.fixed_version_id = ?", id, id).sum(:hours).to_f
    end

  end

end


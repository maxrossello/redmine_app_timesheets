module TimesheetsAppTimelogPatch

  def self.included(base)
    base.instance_eval do
      unloadable

      safe_attributes 'in_timesheet'
    end

  end

end


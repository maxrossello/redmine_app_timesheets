module TimesheetsAppVersionsControllerPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      before_filter :set_safe_attr

    end

  end

  module InstanceMethods

    def set_safe_attr
      Version.safe_attributes 'in_timesheet', 'in_order'
    end

  end

end


unless VersionsController.included_modules.include?(TimesheetsAppVersionsControllerPatch)
  VersionsController.send(:include, TimesheetsAppVersionsControllerPatch)
end

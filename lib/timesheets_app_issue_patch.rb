module TimesheetsAppIssuePatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :assignable_versions, :timelogs
    end

  end

  module InstanceMethods

    def assignable_versions_with_timelogs
      assignable_versions_without_timelogs
      @assignable_versions.reject! { |version| !User.current.allowed_to?(:view_issues, version.project) } unless Setting.public_versions?
      @assignable_versions
    end

  end

end


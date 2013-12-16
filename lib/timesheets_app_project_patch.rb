module TimesheetsAppProjectPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :rolled_up_versions, :timelogs
      alias_method_chain :shared_versions, :timelogs
    end

  end

  module InstanceMethods

    def rolled_up_versions_with_timelogs
      rolled_up_versions_without_timelogs
      @rolled_up_versions.reject! { |version| !User.current.allowed_to?(:view_issues, version.project) } unless Setting.public_versions?
      @rolled_up_versions
    end

    def shared_versions_with_timelogs
      shared_versions_without_timelogs
      @shared_versions.reject! { |version| !User.current.allowed_to?(:view_issues, version.project) } unless Setting.public_versions?
      @shared_versions
    end
  end

end


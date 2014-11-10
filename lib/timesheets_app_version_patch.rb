module TimesheetsAppVersionPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      has_many :time_entries, :class_name => 'TsTimeEntry', :foreign_key => 'order_id', :dependent => :destroy
    end
  end

  module InstanceMethods
  end

end


unless Version.included_modules.include?(TimesheetsAppVersionPatch)
  Version.send(:include, TimesheetsAppVersionPatch)
end

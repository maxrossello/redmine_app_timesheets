
class WorkOrder < Version

  default_scope { where(:is_order => true) }

  has_many :time_entries, :class_name => 'TsTimeEntry', :foreign_key => 'order_id', :dependent => :destroy
  has_many :permissions, :class_name => 'TsPermission', :foreign_key => 'order_id', :dependent => :destroy
  has_many :issues, :foreign_key => 'fixed_version_id', :dependent => :nullify

  safe_attributes 'in_timesheet', 'is_order'

  scope :enabled, lambda { where(:in_timesheet => true) }

  scope :disabled, lambda { where(:in_timesheet => false) }

  scope :native, lambda {
    where(:project_id => Setting.plugin_redmine_app_timesheets['project'].to_i)
  }

  scope :not_native, lambda {
    where("project_id != ?", Setting.plugin_redmine_app_timesheets['project'].to_i)
  }

  def is_native?
    return self.project_id == Setting.plugin_redmine_app_timesheets['project'].to_i
  end

  def spent_hours
    @spent_hours ||= TsTimeEntry.where(:order_id => id).sum(:hours).to_f
  end

  # native versions are not browsable
  def visible?(user=User.current)
    return super && !is_native?
  end

end
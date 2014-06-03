
class WorkOrder < Version

  scope :native, lambda {
    where(:project_id => Setting.plugin_redmine_app_timesheets['project'].to_i)
  }

  def spent_hours
    @spent_hours ||= TsTimeEntry.where(:order_id => id).sum(:hours).to_f
  end
end
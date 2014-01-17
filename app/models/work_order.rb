
class WorkOrder < Version
  def spent_hours
    @spent_hours ||= TimeEntry.uniq.includes(:issue).where("#{TimeEntry.table_name}.fixed_version_id = ? OR #{Issue.table_name}.fixed_version_id = ?", id, id).sum(:hours).to_f
  end
end
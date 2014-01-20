
class RevertTimeEntriesInTimesheet < ActiveRecord::Migration
  def up
    # all those that are in timesheet shall have fixed version id
    TimeEntry.joins(:issue).where(:in_timesheet => true).where("#{TimeEntry.table_name}.fixed_version_id is NULL").update_all(["#{TimeEntry.table_name}.fixed_version_id = #{Issue.table_name}.fixed_version_id"])
  end

  def down
  end
end

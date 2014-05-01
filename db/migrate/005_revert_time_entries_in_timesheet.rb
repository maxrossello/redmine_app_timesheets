
class RevertTimeEntriesInTimesheet < ActiveRecord::Migration
  def up
    # all those that are in timesheet shall have fixed version id
    adapter_type = connection.adapter_name.downcase.to_sym
    case adapter_type
      when :postgresql
        sql = "UPDATE time_entries SET fixed_version_id = issues.fixed_version_id FROM issues WHERE time_entries.id IN ( SELECT time_entries.id FROM time_entries INNER JOIN issues ON issues.id = time_entries.issue_id WHERE time_entries.in_timesheet = 't' AND (time_entries.fixed_version_id is NULL));"
        connection.update(sql)
      else
        TimeEntry.joins(:issue).where(:in_timesheet => true).where("#{TimeEntry.table_name}.fixed_version_id is NULL").update_all(["#{TimeEntry.table_name}.fixed_version_id = #{Issue.table_name}.fixed_version_id"])
    end

  end

  def down
  end
end

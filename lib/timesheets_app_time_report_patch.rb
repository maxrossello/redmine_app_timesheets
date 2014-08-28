module TimesheetsAppTimeReportPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :run, :timelogs
      alias_method_chain :load_available_criteria, :timelogs
    end

  end

  module InstanceMethods

    def load_available_criteria_with_timelogs
      load_available_criteria_without_timelogs

      if @available_criteria
        @available_criteria['work_order'] = {:sql => "#{TsTimeEntry.table_name}.order_id",
                                         :klass => WorkOrder,
                                         :label => :label_order,
                                         :conditions => "#{TimeEntry.table_name}.order_id is not NULL"}

        @available_criteria['order_activity'] = {:sql => "#{TsTimeEntry.table_name}.order_activity_id",
                                             :klass => TimeEntryActivity,
                                             :label => :label_order_activity,
                                             :conditions => "#{TimeEntry.table_name}.order_id is not NULL"}

        @available_criteria['version'] = {:sql => "#{Issue.table_name}.fixed_version_id",
                                        :klass => Version,
                                        :label => :label_version,
                                        :conditions => "#{Issue.table_name}.fixed_version_id is not NULL OR #{TimeEntry.table_name}.order_id is NULL"}

      end

      @available_criteria
    end

    def run_with_timelogs
      unless @criteria.empty?
        time_columns = %w(tyear tmonth tweek spent_on)
        @hours = []
        @scope.sum(:hours,
                   :include => [:issue, :activity],
                   :group => @criteria.collect{|criteria| @available_criteria[criteria][:sql]} + time_columns,
                   :joins => @criteria.collect{|criteria| @available_criteria[criteria][:joins]}.compact,
                   :conditions => @criteria.collect{|criteria| @available_criteria[criteria][:conditions]}.compact).each do |hash, hours|
          h = {'hours' => hours}
          (@criteria + time_columns).each_with_index do |name, i|
            h[name] = hash[i]
          end
          @hours << h
        end

        @hours.each do |row|
          case @columns
            when 'year'
              row['year'] = row['tyear']
            when 'month'
              row['month'] = "#{row['tyear']}-#{row['tmonth']}"
            when 'week'
              row['week'] = "#{row['spent_on'].cwyear}-#{row['tweek']}"
            when 'day'
              row['day'] = "#{row['spent_on']}"
          end
        end

        min = @hours.collect {|row| row['spent_on']}.min
        @from = min ? min.to_date : Date.today

        max = @hours.collect {|row| row['spent_on']}.max
        @to = max ? max.to_date : Date.today

        @total_hours = @hours.inject(0) {|s,k| s = s + k['hours'].to_f}

        @periods = []
        # Date#at_beginning_of_ not supported in Rails 1.2.x
        date_from = @from.to_time
        # 100 columns max
        while date_from <= @to.to_time && @periods.length < 100
          case @columns
            when 'year'
              @periods << "#{date_from.year}"
              date_from = (date_from + 1.year).at_beginning_of_year
            when 'month'
              @periods << "#{date_from.year}-#{date_from.month}"
              date_from = (date_from + 1.month).at_beginning_of_month
            when 'week'
              @periods << "#{date_from.to_date.cwyear}-#{date_from.to_date.cweek}"
              date_from = (date_from + 7.day).at_beginning_of_week
            when 'day'
              @periods << "#{date_from.to_date}"
              date_from = date_from + 1.day
          end
        end
      end
    end
  end

end


unless Redmine::Helpers::TimeReport.included_modules.include?(TimesheetsAppTimeReportPatch)
  Redmine::Helpers::TimeReport.send(:include, TimesheetsAppTimeReportPatch)
end

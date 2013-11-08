class TimesheetsController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :get_project
  before_filter :get_user
  before_filter :get_dates
  before_filter :get_timelogs

  @@DEFAULT_ACTIVITY = Enumeration.where(:type => 'TimeEntryActivity', :is_default => true).first

  def index
  end

  def save_weekly
    redirect_to :back
  end

  def delete_row
  end

  private

  def get_dates
    @current_day = DateTime.strptime(params[:day], Time::DATE_FORMATS[:param_date]) rescue nil
    @current_day = DateTime.now if @current_day.nil?

    @week_start = @current_day.beginning_of_week
    @week_end = @current_day.end_of_week

    @view = params[:view].to_sym rescue nil
    @view = :week if @view.nil?
  end

  def get_user
    render_403 unless User.current.logged?

    if params[:user_id] and params[:user_id] != User.current.id.to_s
      @user = User.find(params[:user_id]) rescue nil
      if @user.nil?
        render_404
      elsif User.current.admin? or User.current.allowed_to?(:edit_time_entries, @ts_project)
        @visibility = :edit
      elsif User.current.allowed_to?(:view_time_entries, @ts_project)
        @visibility = :view
      else
        render_403
      end
    else
      @user = User.current
      if User.current.admin? or User.current.allowed_to?(:edit_time_entries, @ts_project)
        @visibility = :edit
      else User.current.allowed_to?(:view_time_entries, @ts_project)
        @visibility = :edit_own
      end
    end

  end

  def get_project
    @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
  end

  def get_timelogs
    @orders = (Issue.where(:project_id => @ts_project).watched_by(@user).joins(:fixed_version).map {|i| i.fixed_version} +
        Project.find(@ts_project).shared_versions.visible(@user).all).uniq

    @daily_totals = {}

    (@week_start..@week_end).each do |day|
      @daily_totals[day] = TimeEntry.for_user(@user).spent_on(day).where(:in_timesheet => true).map(&:hours).inject(:+)
    end

    @week_matrix = []
    @orders.each do |order|
      row = {}
      row[:order] = order
      entries = TimeEntry.for_user(@user).where(:in_timesheet => true).where("spent_on IN (?)", @week_start..@week_end).joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").where("#{TimeEntry.table_name}.fixed_version_id = ? OR #{Issue.table_name}.fixed_version_id = ?", order.id, order.id)
      entries.all.group_by(&:activity_id).each do |activity, values|
        row[:activity] = Enumeration.find(activity)
        values.group_by(&:issue_id).each do |issue, iv|
          row[:issue] = issue.nil? ? nil : Issue.find(issue)
          iv.group_by(&:spent_on).each do |spent, sv|
            row[spent] = sv
            row[:hours] = sv.inject(0) { | sum, elem | sum + elem.hours }
          end
          @week_matrix << row
          row = row.dup
        end
      end

      if row[:activity].nil?
        row[:activity], row[:days] = @@DEFAULT_ACTIVITY, {}
        @week_matrix << row
      end
    end
    #p @week_matrix
  end

  #def get_timelogs_old
  #  @orders = Version.where(:in_timesheet => true).group_by {|x| x.project_id == @ts_project}
  #
  #  weekly_time_entries = TimeEntry.for_user(@user).spent_between(@week_start, @week_end).group_by(&:in_timesheet)
  #  #weekly_time_entries = TimeEntry.for_user(@user).spent_between(@week_start - 7, @week_end - 7).group_by(&:in_timesheet) if (weekly_time_entries[true] || []).empty?
  #
  #  @week_issue_matrix = {}
  #  (weekly_time_entries[true] || []).each do |te|
  #    key = te.project.name + (te.issue ? " - #{te.issue.subject}" : "") +  " - #{te.activity.name}"
  #    @week_issue_matrix[key] ||= {:issue_id => te.issue_id,
  #                                 :activity_id => te.activity_id,
  #                                 :project_id => te.project.id,
  #                                 :project_name => te.project.name,
  #                                 :issue_text => te.issue.try(:to_s),
  #                                 :activity_name => te.activity.name,
  #                                 :order_id => te.fixed_version_id
  #    }
  #    @week_issue_matrix[key][:issue_class] ||= te.issue.closed? ? 'issue closed' : 'issue' if te.issue
  #    @week_issue_matrix[key][:order_class] ||= te.fixed_version_id.nil? ? 'order shared' : 'order native'
  #    @week_issue_matrix[key][te.spent_on.to_s(:param_date)] = {:hours => te.hours, :te_id => te.id, :comments => te.comments}
  #  end
  #
  #  @week_issue_matrix = @week_issue_matrix.sort
  #  @daily_totals = {}
  #
  #  (@week_start..@week_end).each do |day|
  #    @daily_totals[day.to_s(:param_date)] = TimeEntry.for_user(@user).spent_on(day).where(:in_timesheet => true).map(&:hours).inject(:+)
  #  end
  #
  #  @daily_issues = @week_issue_matrix.select{|k,v| v[@current_day.to_s(:param_date)]} if @view == :day
  #
  #end

end
class TimesheetsController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :get_project
  before_filter :get_user
  before_filter :get_dates
  before_filter :get_timelogs

  def index
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
  #  @orders = Versions.where(:in_timesheet => true).group_by {|x| x.project_id == @ts_project}
  #
  #  weekly_time_entries = TimeEntry.for_user(@user).spent_between(@week_start, @week_end).group_by(&:in_timesheet)
  #
  #  @week_issue_matrix = {}
  #  weekly_time_entries.each do |te|
  #    key = te.project.name + (te.issue ? " - #{te.issue.subject}" : "") +  " - #{te.activity.name}"
  #    @week_issue_matrix[key] ||= {:issue_id => te.issue_id,
  #                                 :activity_id => te.activity_id,
  #                                 :project_id => te.project.id,
  #                                 :project_name => te.project.name,
  #                                 :issue_text => te.issue.try(:to_s),
  #                                 :activity_name => te.activity.name
  #    }
  #    @week_issue_matrix[key][:issue_class] ||= te.issue.closed? ? 'issue closed' : 'issue' if te.issue
  #    @week_issue_matrix[key][te.spent_on.to_s(:param_date)] = {:hours => te.hours, :te_id => te.id, :comments => te.comments}
  #  end
  #
  #  @week_issue_matrix = @week_issue_matrix.sort
  #  @daily_totals = {}
  #
  #  (@week_start..@week_end).each do |day|
  #    @daily_totals[day.to_s(:param_date)] = TimeEntry.for_user(@user).spent_on(day).map(&:hours).inject(:+)
  #  end
  #
  #  @daily_issues = @week_issue_matrix.select{|k,v| v[@current_day.to_s(:param_date)]} if @current_day
  #
  #  if @week_issue_matrix.empty?
  #    @week_issue_matrix = {}
  #    last_week_time_entries = TimeEntry.for_user(@user).spent_between(@week_start-7, @week_end-7).sort_by{|te| te.issue.project.name}.sort_by{|te| te.issue.subject }
  #    last_week_time_entries.each do |te|
  #      @week_issue_matrix["#{te.issue.project.name} - #{te.issue.subject} - #{te.activity.name}"] ||= {:issue_id => te.issue_id,
  #                                                                                                      :activity_id => te.activity_id,
  #                                                                                                      :project_id => te.issue.project.id,
  #                                                                                                      :project_name => te.issue.project.name,
  #                                                                                                      :issue_text => te.issue.to_s,
  #                                                                                                      :activity_name => te.activity.name
  #      }
  #      @week_issue_matrix["#{te.issue.project.name} - #{te.issue.subject} - #{te.activity.name}"][:issue_class] ||= te.issue.closed? ? 'issue closed' : 'issue'
  #    end
  #    @week_issue_matrix = @week_issue_matrix.sort
  #  end
  #
  #  logger.debug '+++++++++++++++++++++++++++++++++++'
  #  logger.debug @week_issue_matrix.inspect
  #  logger.debug '+++++++++++++++++++++++++++++++++++'
  end

end
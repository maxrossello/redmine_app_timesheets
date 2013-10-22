class TimesheetsController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :get_project
  before_filter :get_user
  before_filter :get_dates

  def index
  end

  def settings

  end

  private

  def get_dates
    @current_day = DateTime.strptime(params[:day], Time::DATE_FORMATS[:param_date]) rescue nil
    if @current_day
      @week_start = @current_day.beginning_of_week
      @week_end = @current_day.end_of_week
    else
      @week_start = params[:week].nil? ? DateTime.now.beginning_of_week : DateTime.strptime(params[:week], Time::DATE_FORMATS[:param_date]).beginning_of_week
      @week_end = params[:week].nil? ? DateTime.now.end_of_week : DateTime.strptime(params[:week], Time::DATE_FORMATS[:param_date]).end_of_week
    end
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
end
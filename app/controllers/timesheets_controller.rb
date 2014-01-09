class TimesheetsController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :get_project
  before_filter :get_user
  before_filter :access_control, :except => :index
  before_filter :get_dates
  before_filter :get_timelogs, :except => :save_period

  helper CustomFieldsHelper

  @@DEFAULT_ACTIVITY = Enumeration.where(:type => 'TimeEntryActivity', :is_default => true).first

  def index
  end

  def new
    @time_entry = TimeEntry.new
  end

  # add a timelog entry into the timesheet
  def add_entry
    entry = TimeEntry.find(params[:entry_id])
    entry.in_timesheet = true
    entry.save!
    redirect_to :back
  end

  def save_period
    if @view != :day
      entries = TimeEntry.for_user(@user).where(:in_timesheet => true).spent_between(@period_start,@period_end).joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").all
    else
      entries = []
    end

    params[:order].each_with_index do |order_id, idx|

      tlogs = entries.select {|x| (x.fixed_version_id == order_id.to_i or (x.issue.fixed_version_id == order_id.to_i rescue false)) and
          x.activity_id == params[:previous_activity][idx].to_i and
          x.issue_id == (params[:issue][idx].empty? ? nil : params[:issue][idx].to_i)} rescue []

      params[:hours].each do |s_date, hours|
        date = s_date.to_date

        if @view == :day
          # day view handles single entries
          daylogs = [ TimeEntry.find(params[:entry][idx]) ] rescue nil
          old_sum = daylogs.first.hours rescue 0
        else
          # other views handle sets of similar entries
          daylogs = tlogs.group_by(&:spent_on)[date]
          old_sum = daylogs.inject(0) { |sum,x| sum + x.hours } rescue 0
        end

        next if hours[idx].to_f < 0
        diff = hours[idx].to_f - old_sum

        while diff < 0
          item = daylogs.last
          if item.hours + diff <= 0
            diff = diff + item.hours
            TimeEntry.delete(item.id)
            daylogs.pop
          else
            # need to find entries because join makes tlogs read only
            entry = TimeEntry.find(item.id)
            entry.hours = entry.hours + diff
            entry.save!
            diff = 0
          end
        end
        if diff > 0
          if daylogs.nil?
            # this is a new row
            if params[:issue][idx].empty?
              entry = TimeEntry.create(:project => Version.find(order_id.to_i).project, :fixed_version_id => order_id.to_i, :hours => diff, :user => @user, :spent_on => date, :activity => Enumeration.find(params[:activity][idx].to_i), :in_timesheet => true)
            else
              issue = Issue.find(params[:issue][idx].to_i)
              entry = TimeEntry.create(:project => issue.project, :issue => issue, :hours => diff, :user => @user, :spent_on => date, :activity => Enumeration.find(params[:activity][idx].to_i), :in_timesheet => true)
            end
            daylogs = [entry]
          else
            # need to find entries because join makes tlogs read only
            entry = TimeEntry.find(daylogs.last.id)
            entry.hours = entry.hours + diff
            entry.save!
          end
        end

        entry = (daylogs.last rescue nil) unless entry

        if params[:comment] and entry
          # only in day view
          entry.comments = params[:comment][idx]
          entry.save!
        end

        # check for change of activity
        if params[:activity][idx] != params[:previous_activity][idx] and daylogs
          TimeEntry.find(daylogs.map(&:id)).each do |x|
            x.activity_id = params[:activity][idx].to_i
            x.save
          end
        end
      end
    end

    #:back
    redirect_to url_for({ :controller => params[:controller], :action => 'index', :user_id => params[:user_id], :view => @view, :day => @current_day})
  end

  def row_entries
    entries = TimeEntry.for_user(@user).where(:in_timesheet => true).spent_between(@period_start,@period_end).where(:activity_id => params[:activity_id])
    if params[:issue_id]
      entries = entries.joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").where("#{Issue.table_name}.fixed_version_id = ?", params[:order_id])
    else
      entries = entries.where(:fixed_version_id => params[:order_id])
    end

    entries
  end

  def delete_row
    if params[:entry_id]
      TimeEntry.delete(params[:entry_id]) rescue render_404
    else
      TimeEntry.delete(row_entries.all)
    end

    redirect_to :back
  end

  def copy_row
    if params[:entry_id]
      set = [TimeEntry.find(params[:entry_id])] rescue render_404
    else
      set = row_entries.all
    end

    set.each do |x|
      tlog = TimeEntry.find(x.id).dup
      tlog.spent_on = tlog.spent_on+@period_shift
      tlog.save!
    end

    redirect_to url_for({ :controller => params[:controller], :action => 'index', :user_id => params[:user_id], :view => @view, :day => @current_day + @period_shift})
  end

  def remove_entry
    if params[:entry_id]
      set = [TimeEntry.find(params[:entry_id])] rescue render_404
    else
      set = row_entries.all
    end

    set.each do |x|
      tlog = TimeEntry.find(x.id)
      tlog.in_timesheet = false
      tlog.save!
    end

    redirect_to :back
  end

  private

  def access_control
    render_403 unless @visibility == :edit or @user == User.current
  end

  def get_dates
    @current_day = DateTime.strptime(params[:day], Time::DATE_FORMATS[:param_date]) rescue nil
    @current_day ||= DateTime.strptime(DateTime.now.to_s, Time::DATE_FORMATS[:param_date])

    @view = params[:view].to_sym rescue nil
    @view = :week if @view.nil? or params[:view].empty?

    if @view == :week
      @period_start = @current_day.beginning_of_week
      @period_end = @current_day.end_of_week
      @period_length = 7
      @period_shift = 7
    elsif @view == :day
      @period_start = @current_day
      @period_end = @current_day
      @period_length = 0 # do not get items from side days
      @period_shift = 1
    else
      @period_length = params[:view].to_i
      @period_shift = @period_length
      @period_start = @current_day
      @period_end = @current_day + @period_length -1
    end


  end

  def get_user
    render_403 unless User.current.logged?

    if params[:user_id] and params[:user_id] != User.current.id.to_s
      @user = User.find(params[:user_id]) rescue render_404
    else
      @user = User.current
    end

    if User.current.admin? or User.current.allowed_to?(:edit_time_entries, Project.find(@ts_project))
      @visibility = :edit
    elsif User.current.allowed_to?(:view_time_entries, Project.find(@ts_project))
      @visibility = :view
    else
      redirect_to url_for params.except :user_id if @user != User.current
      @visibility = :edit_own
    end

  end

  def get_project
    @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
  end

  def get_timelogs
    # version of issues in @ts_project + shared versions visible in @ts_project
    # + versions associated to existing timelogs even if version no more visible to user
    # + versions associated to issues that are associated to some existing timelog
    @active_orders = (Issue.where(:project_id => @ts_project).watched_by(@user).joins(:fixed_version).map(&:fixed_version) +
        Project.find(@ts_project).shared_versions.visible(@user).all).uniq.sort_by{ |v| v.name.downcase}
    @active_own_orders = (Issue.where(:project_id => @ts_project).watched_by(User.current).joins(:fixed_version).map(&:fixed_version) +
        Project.find(@ts_project).shared_versions.visible.all).uniq.sort_by{ |v| v.name.downcase}
    @orders = (@active_orders +
        Version.where(:id => TimeEntry.for_user(@user).map(&:fixed_version_id)).all +
        Version.where(:id => Issue.joins(:time_entries).where('user_id = ?', @user.id).where(:fixed_version_id => Project.find(@ts_project).shared_versions.map(&:id)).map(&:fixed_version_id)).all
    ).uniq.sort_by{ |v| v.name.downcase}

    @daily_totals = {}
    @week_matrix = []
    @available = []
    @visible_orders = []

    @orders.each do |order|
      # skip orders not visible to the current user
      next if User.current != @user and !@active_own_orders.include?(order)
      @visible_orders << order if @active_orders.include?(order)

      row = {}
      row[:order] = order
      row[:spent] = {}

      unless order.project_id == @ts_project
        row[:issues] = Issue.visible(@user).where(:fixed_version_id => order.id)
      end
      # format suitable for options_for_select
      row[:activities] = TsActivity.where(:order_id => order).map {|t| [t.activity_name, t.activity_id.to_s]}
      row[:activities] = TimeEntryActivity.shared.active.map {|t| [t.name,t.id.to_s]} if row[:activities].empty?
      entries = TimeEntry.for_user(@user).where(:in_timesheet => true).spent_between(@period_start-@period_length,@period_end+@period_length).joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").where("#{TimeEntry.table_name}.fixed_version_id = ? OR #{Issue.table_name}.fixed_version_id = ?", order.id, order.id)
      entries.all.group_by(&:activity_id).each do |activity, values|
        row[:activity] = Enumeration.find(activity)
        values.group_by(&:issue_id).each do |issue, iv|
          row[:spent] = {}
          row[:entries] = {}
          row[:issue] = issue.nil? ? nil : Issue.find(issue)
          iv.group_by(&:spent_on).each do |day, sv|
            row[:spent][day] = sv.inject(0) { | sum, elem |
              sum + elem.hours }
            @daily_totals[day] = row[:spent][day] + (@daily_totals[day] || 0)
            row[:entries] = sv
          end
          @week_matrix << row unless row[:spent].empty?
          row = row.dup
        end
      end


      if row[:activity].nil?
        row[:activity], row[:days] = @@DEFAULT_ACTIVITY, {}
        @week_matrix << row unless row[:spent].empty?
      end

      TimeEntry.for_user(@user).where(:in_timesheet => false).spent_between(@period_start,@period_end).joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").where("#{TimeEntry.table_name}.fixed_version_id = ? OR #{Issue.table_name}.fixed_version_id = ?", order.id, order.id).each do |entry|
        @available << { :order => order, :timelog => entry }
      end

    end

    if params[:newrow]
      # add the new empty row
      if params[:order].nil? or params[:activity].nil?
        render_404
      else
        row = {}
        row[:order] = Version.find(params[:order])
        unless row[:order].project_id == @ts_project
          row[:issues] = Issue.visible(@user).where(:fixed_version_id => row[:order].id)
        end
        row[:activities] = TsActivity.where(:order_id => params[:order].to_i).map {|t| [t.activity_name, t.activity_id.to_s]}
        row[:activities] = TimeEntryActivity.shared.active.map {|t| [t.name,t.id.to_s]} if row[:activities].empty?
        row[:activity] = Enumeration.find(params[:activity])
        row[:issue] = (params[:issue].nil? or params[:issue].empty?) ? nil : Issue.find(params[:issue])
        row[:spent] = {}
        # add only if unique
        @week_matrix << row if @week_matrix.select{|x| x if x[:order] == row[:order] and x[:activity] == row[:activity] and x[:issue] == row[:issue]}.empty?
      end
      params.delete :order
      params.delete :activity
      params.delete :issue
      params.delete :newrow

    else
      # while building the new row
      if params[:order] and !params[:order].empty?
        new_order = Version.find(params[:order])
        @activities = TsActivity.where(:order_id => params[:order].to_i).map {|t| [t.activity_name, t.activity_id.to_s]}
        @activities = new_order.project.activities.sort{|x,y| x.name <=> y.name}.map{ |x| [ x.name, x.id] } if @activities.empty?
      end

      if params[:activity] && new_order.project_id != @ts_project
        # select among the issues linked to the version only
        @issues = new_order.fixed_issues.visible(@user).all
      end
    end

  end

end

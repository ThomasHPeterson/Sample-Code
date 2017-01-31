require 'will_paginate/array'
include ActionView::Helpers::TextHelper

class Account::PatientsController < Account::BaseController
	before_filter :authenticate_user!
	authorize_resource

	# GET /patients/active
	def active
		params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page]
		get_account
		if session[:account_diseases].include? 'DM' and session[:account_diseases].include? 'CKD'
			@header = 'All Active Patient'
			@all_dm = @account.patients.all_active_dm.includes(:patient_status, :report_visibility).order("last_name, first_name, dob")
			@all_ckd = @account.patients.all_active_ckd.includes(:patient_status, :report_visibility).order("last_name, first_name, dob")
			@all_patients = @account.patients.all_active_dm_ckd.includes(:patient_status, :report_visibility).order("last_name, first_name, dob")
      @patients = @all_patients.paginate(:per_page => @per_page, :page => params[:page])
		elsif session[:account_diseases].include? 'DM'
			@header = 'All Active DM Patient'
			@patients = @account.patients.all_active_dm.includes(:status_lookup).order("last_name, first_name, dob").paginate(:per_page => @per_page, :page => params[:page])
		elsif session[:account_diseases].include? 'CKD'
			@header = 'All Active CKD Patient'
			@patients = @account.patients.all_active_ckd.includes(:report_visibility).order("last_name, first_name, dob").paginate(:per_page => @per_page, :page => params[:page])
		elsif session[:account_diseases].empty?
			@header = 'No Patients'
		else
		end
		render 'index_account'
	end

	def active_dm
		params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page] 
		get_account
		if session[:account_diseases].include? 'DM'
			@header = 'All Active DM Patient'
			@patients = @account.patients.all_active_dm.includes(:patient_status, :report_visibility).order("last_name, first_name, dob").paginate(:per_page => @per_page, :page => params[:page])
			render 'index_account'
		else
			redirect_to active_account_patients_path, :alert => "This account is not active for Diabetes"
		end
	end

	def active_ckd
		params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page] 
		get_account
		if session[:account_diseases].include? 'CKD'
			@header = 'All Active CKD Patient'
			@patients = @account.patients.all_active_ckd.includes(:patient_state, :report_visibility).order("last_name, first_name, dob").paginate(:per_page => @per_page, :page => params[:page])
			render 'index_account'
		else
			redirect_to active_account_patients_path, :alert => "This account is not active for Kidney Disease"
		end
	end

	# GET /account/patients/inactive
	def inactive
	  params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page] 
		@header = 'Inactive Patient'
		get_account
    @is_dm_account = session[:account_diseases].include? 'DM'
    @is_ckd_account = session[:account_diseases].include? 'CKD'
    @query = @account.patients.includes(:patient_status, :patient_state, :status_lookup, :report_visibility)
		if @is_dm_account and @is_ckd_account
      @inactive = @query.all_inactive_dm_ckd
      @patients = @inactive.order(:last_name, :first_name, :middle_name, :dob).paginate(:per_page => @per_page, :page => params[:page])
	  elsif @is_dm_account
      @inactive = @query.all_inactive_dm
      @patients = @inactive.order(:last_name, :first_name, :middle_name, :dob).paginate(:per_page => @per_page, :page => params[:page])
	  elsif @is_ckd_account
      @inactive = @query.all_inactive_ckd
      @patients = @inactive.order(:last_name, :first_name, :middle_name, :dob).paginate(:per_page => @per_page, :page => params[:page])
    else
       @patients = nil
		end
		render 'index_account'
  end

  def assigned_not_accepted
    get_account
    params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page]
    @header = 'Patients Assigned to Case Managers but Not Yet Acknowledged'
    @patients = @account.patients.without_cm_acceptance.order(:last_name, :first_name, :middle_name, :dob)
    @patients = @patients.paginate(:per_page => @per_page, :page => params[:page])
  end

  def under_prov_review
    @header = 'Patients in Status: Under Provider Review'
    @dm_pats = Patient.dm_under_prov_review session[:account_id].to_s
    @ckd_pats = Patient.ckd_under_prov_review session[:account_id].to_s

    respond_to do |format|
      format.html
      format.xls {
        # Method in ApplicationController
        render_under_prov_review_spreadsheet
      }
    end
  end

  # GET /account/patients/1/flowsheet
	def flowsheet
		find_patient
		flowsheet = Flowsheet.new(@patient, session)
		@sections = flowsheet.sections
		@flowsheet = flowsheet.flowsheet
	end

	# GET /account/patients/1/test_results
	def test_results
		find_patient
		if session[:account_diseases].count == 1
			params[:tests] = nil
		end
		if session[:account_diseases].include? 'DM'
			params[:tests] ||= 'DM'
		elsif session[:account_diseases].include? 'CKD'
			params[:tests] ||= 'CKD'
		end
		if params[:tests] == 'CKD' and session[:account_diseases].include? 'CKD'
			@tests = Settings.tests_by_disease.ckd
      @test_results = @patient.test_results.includes(:test_code).with_test_codes(@tests).order("result_date DESC").group_by { |t| t.result_date.to_date }
		elsif params[:tests] == 'DM' and session[:account_diseases].include? 'DM'
			@tests = Settings.tests_by_disease.dm
      @test_results = @patient.test_results.includes(:test_code).with_test_codes(@tests).order("result_date DESC").group_by { |t| t.result_date.to_date }
		end
		render 'test_results'
	end

	# GET /account/patients/1/reports
	def reports
		params[:per_page].nil? ? @per_page = Settings.pagination.per_subpage : @per_page = params[:per_page]
		find_patient
    unless !@account.suppress_by_account.nil? and @account.suppress_by_account.suppress_pat_reminder == 'Y'
		  @pat_reminders = @patient.reports.patient_reminders.order("report_create_time DESC NULLS LAST").paginate(:page => params[:pat_reminders_page], :per_page => @per_page)
    end
    unless !@account.suppress_by_account.nil? and @account.suppress_by_account.suppress_prov_reminder == 'Y'
		  @prov_reminders = @patient.reports.provider_reminders.order("report_create_time DESC NULLS LAST").paginate(:page => params[:prov_reminders_page], :per_page => @per_page)
    end
    unless !@account.suppress_by_account.nil? and @account.suppress_by_account.suppress_pat_alert == 'Y'
		  @pat_alerts = @patient.reports.patient_alerts.order("report_create_time DESC NULLS LAST").paginate(:page => params[:pat_alerts_page], :per_page => @per_page)
    end
    unless !@account.suppress_by_account.nil? and @account.suppress_by_account.suppress_flowsheet == 'Y'
		  @flowsheets = @patient.reports.flowsheets.order("report_create_time DESC NULLS LAST").paginate(:page => params[:flowsheets_page], :per_page => @per_page)
    end
		@reports = true
  end

  def due_dates
    find_patient
    @lab_due_dates = @patient.worklist_view
    if @patient.active_dm? and @patient.active_ckd?
      @tests = Settings.worklist.tests.all
      @columns = Settings.worklist.display_columns.all
    elsif @patient.active_dm?
      @tests = Settings.worklist.tests.dm
      @columns = Settings.worklist.display_columns.dm
    elsif @patient.active_ckd?
      @columns = Settings.worklist.display_columns.ckd
      @tests = Settings.worklist.tests.ckd
    else
      @tests = []
      @columns = []
    end
  end

	# GET /patients/search
	def search
    get_account
    params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page]

    if params[:search].nil?
      # these params are always passed by the view, even when the user enters nothing, so this is just a sanity check
      raise ArgumentError, 'Search parameters not found.'
    else
      @patients = @account.patients.search_form(session, params[:search]).paginate(:per_page => @per_page, :page => params[:page])
      if @patients.count == 0
				redirect_to :back, notice: 'No patients match your search.'
			elsif @patients.count == 1
				redirect_to flowsheet_account_patient_path(obfuscate_encrypt(@patients.first.patient_id, session)), notice: 'Displaying the one matching patient.'
      else
        render "search"
			end
    end
  end

  # PUT /patients/1
  def update
    find_patient

    # Should be rare that a patient has no location, so we'll tolerate the double save in these cases.
    if !@location.persisted?
      @location.save!
      @patient.patient_home_location = @location.location_id
      @patient.save!
    end

    if @location.update_attributes!(params[:location])

      bOK = true
      plan = @patient.patient_plan
      new_id = params[:patient_plan]
      if !plan.nil? and new_id == ''
        bOK = PatientPlan.destroy @patient.patient_id
      elsif !plan.nil? and new_id != ''
        plan.plan_id = new_id.to_i
        bOK = plan.save!
      elsif plan.nil? and new_id != ''
        plan = @patient.build_patient_plan
        plan.plan_id = new_id.to_i
        bOK = plan.save!
      end

      find_patient
      if bOK
        flash.now[:notice] = 'Update successful.'
      else
        flash.now[:error] = 'Location update successful.  Insurance Plan update failed.'
      end
    else
      flash.now[:error] = 'Update failed.'
    end

    flowsheet = Flowsheet.new(@patient, session)
    @sections = flowsheet.sections
    @flowsheet = flowsheet.flowsheet
    render 'flowsheet'
  end

  private

  def find_patient
    @patient = Patient.find_by_patient_id obfuscate_decrypt(params[:id], session).to_i
    @location = @patient.location
    if @location.nil?
      # created for the form only.  This location is not persisted.
      @location = Location.new
      @patient.location = @location
    end
    @plan = @patient.patient_plan
    @activation_date = @patient.get_active_date
    @comment_option_lookups = CommentOptionLookup.order
    @request_path = request.fullpath
  end


end
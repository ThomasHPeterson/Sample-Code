class Account::RosterPendingController < Account::BaseController
	before_filter :authenticate_user!
	skip_authorization_check

	# GET /roster_pending/index
	# GET /roster_pending/index.json
	def index
    get_account
		@id = @account.id
    @case_managers = current_account.case_managers.order("contact.last_name, contact.first_name DESC")
    @is_dm_account = session[:account_diseases].include? 'DM'
    @is_ckd_account = session[:account_diseases].include? 'CKD'
    # 33, 12 = ROSTER PENDING
    # 35, 6 = EXISTING PATIENT UPDATE
    # 100, 98 = MISSING ADDRESS
    if @is_dm_account and @is_ckd_account
      @patients = @account.patients.with_status(33, 35, 100).includes(:case_managers) + @account.patients.with_ckd_particip_status(6, 12, 98).includes(:case_managers)
      @patients = @patients.uniq
      @patients.sort_by! { |pat| pat.name }
    elsif @is_dm_account
      @patients = @account.patients.with_status(33, 35, 100).includes(:case_managers)
    elsif @is_ckd_account
      @patients = @account.patients.with_ckd_particip_status(6, 12, 98).includes(:case_managers)
    else
      raise ArgumentError, 'No account diseases found for this session.'
    end
    @patients.sort_by! { |pat| pat.name }

    @ckd_stage_rollover = ckd_stage_rollover_text

    respond_to do |format|
			format.html
		end
  end

  def update

    @ckd_stage_rollover = ckd_stage_rollover_text
    @is_dm_account = session[:account_diseases].include? 'DM'
    @is_ckd_account = session[:account_diseases].include? 'CKD'
    @case_managers = current_account.case_managers.order("contact.last_name, contact.first_name DESC")
    @patients = []
    @updated_patients = []
    @updated_for_cms_message = []
    @updated_status_only = []
    params.each do |pat_id, v|

      # Only want the patient id params, which are integers as strings
      if (pat_id =~ /^(\d)+$/)
        patient = Patient.find_by_patient_id(pat_id.to_i)
        new_status = false
        new_state = false
        new_cms = false

        if params[pat_id]['dm_accept'].present?
          pstatus = patient.patient_status
          if params[pat_id]['dm_accept'] == 'true'
            # 1 = ACTIVE
            pstatus.patient_status_id = 1;
            new_status = true;
          elsif params[pat_id]['dm_status'].present?
            # this is the Do Not Accept case, and the user has chosen a reason
            pstatus.patient_status_id = params[pat_id]['dm_status'].to_i
            new_status = true;
          end
          if new_status
            pstatus.save!
          end

          if params[pat_id]['dm_comments'].present? and !params[pat_id]['dm_comments'].empty?
            history_relation = patient.patient_status_change_histories.most_recent
            history = PatientStatusChangeHistory.find history_relation
            history.reason_for_change = params[pat_id]['dm_comments']
            history.updater_user_id = current_user.id
            history.save!
          end
        end

        if params[pat_id]['ckd_accept'].present?
          pstate = patient.patient_state
          if params[pat_id]['ckd_accept'] == 'true'
            # 1 = Active
            pstate.patient_particip_status_id = 1;
            new_state = true;
          elsif params[pat_id]['ckd_status'].present?
            pstate.patient_particip_status_id = params[pat_id]['ckd_status'].to_i
            new_state = true
          end

          if new_state
            pstate.save!
          end

          if params[pat_id]['ckd_comments'].present? and !params[pat_id]['ckd_comments'].empty?
            history_relation = patient.patient_state_change_histories.most_recent.status_type('PARTICIP')
            history = PatientStateChangeHistory.find history_relation
            history.reason_for_change = params[pat_id]['ckd_comments']
            history.updater_user_id = current_user.id
            history.save!
          end
        end

        new_cms = update_case_managers patient, pat_id

        if new_status or new_state or new_cms
          @updated_patients << [patient, new_status, new_state, new_cms]
        end

        if new_status or new_state
          @updated_status_only << patient
        end

        # put patient back in the list to be displayed if they have been not dispositioned
        # or if they have been dispositioned but not for both diseases
        if ((!new_status and !new_state) or
            (patient.patient_status.patient_status_id == 33 or
            patient.patient_status.patient_status_id == 35 or
            patient.patient_status.patient_status_id == 100 or
            patient.patient_state.patient_particip_status_id == 6 or
            patient.patient_state.patient_particip_status_id == 12 or
            patient.patient_state.patient_particip_status_id == 98))
          @patients << patient
        end

      end
    end
    if (@updated_patients.size > 0)
      OpsMailer.patient_status_query_alert(current_user, @updated_patients, @is_dm_account, @is_ckd_account)
      OpsMailer.cm_patient_status_change_alert(current_user, @updated_status_only)
      flash.now[:notice] = 'Updates successful.  Patients remaining on page may not have been dispositioned for both DM and CKD.'
    else
      flash.now[:notice] = 'No edits were found.  No updates occurred.'
    end
    if (@updated_for_cms_message.size > 0)
      OpsMailer.patient_cm_change_alert(current_user, @updated_for_cms_message)
    end
    render 'index'
  end

  def update_patient

    @ckd_stage_rollover = ckd_stage_rollover_text
    @is_dm_account = session[:account_diseases].include? 'DM'
    @is_ckd_account = session[:account_diseases].include? 'CKD'
    @case_managers = current_account.case_managers.order("contact.last_name, contact.first_name DESC")
    patients = @account.patients.with_status(33, 35, 100).includes(:case_managers) + @account.patients.with_ckd_particip_status(6, 12, 98).includes(:case_managers)
    patients = patients.uniq
    patients.sort_by! { |pat| pat.name }
    @patients = []
    @updated_patients = []
    @updated_for_cms_message = []
    @updated_status_only = []

    pat_id = params[:patient_id]
    patient = Patient.find_by_patient_id(pat_id.to_i)
    new_status = false
    new_state = false
    new_cms = false

    if params[pat_id]['dm_accept'].present?
      pstatus = patient.patient_status
      if params[pat_id]['dm_accept'] == 'true'
        # 1 = ACTIVE
        pstatus.patient_status_id = 1;
        new_status = true;
      elsif params[pat_id]['dm_status'].present?
        # this is the Do Not Accept case, and the user has chosen a reason
        pstatus.patient_status_id = params[pat_id]['dm_status'].to_i
        new_status = true;
      end
      if new_status
        pstatus.save!
      end

      if params[pat_id]['dm_comments'].present? and !params[pat_id]['dm_comments'].empty?
        history_relation = patient.patient_status_change_histories.most_recent
        history = PatientStatusChangeHistory.find history_relation
        history.reason_for_change = params[pat_id]['dm_comments']
        history.updater_user_id = current_user.id
        history.save!
      end
    end

    if params[pat_id]['ckd_accept'].present?
      pstate = patient.patient_state
      if params[pat_id]['ckd_accept'] == 'true'
        # 1 = Active
        pstate.patient_particip_status_id = 1;
        new_state = true;
      elsif params[pat_id]['ckd_status'].present?
        pstate.patient_particip_status_id = params[pat_id]['ckd_status'].to_i
        new_state = true
      end

      if new_state
        pstate.save!
      end

      if params[pat_id]['ckd_comments'].present? and !params[pat_id]['ckd_comments'].empty?
        history_relation = patient.patient_state_change_histories.most_recent.status_type('PARTICIP')
        history = PatientStateChangeHistory.find history_relation
        history.reason_for_change = params[pat_id]['ckd_comments']
        history.updater_user_id = current_user.id
        history.save!
      end
    end

    new_cms = update_case_managers patient, pat_id

    #if new_status or new_state or new_cms
    #  @updated_patients << [patient, new_status, new_state, new_cms]
    #end

    #if new_status or new_state
    #  @updated_status_only << patient
    #end

    # put patient back in the list to be displayed if they have been not dispositioned
    # or if they have been dispositioned but not for both diseases
    if ((!new_status and !new_state) or
        (patient.patient_status.patient_status_id == 33 or
            patient.patient_status.patient_status_id == 35 or
            patient.patient_status.patient_status_id == 100 or
            patient.patient_state.patient_particip_status_id == 6 or
            patient.patient_state.patient_particip_status_id == 12 or
            patient.patient_state.patient_particip_status_id == 98))
      patients.each do |pat|
        if (pat.patient_id == patient.patient_id)
          @patients << patient
        else
          @patients << pat
        end
      end

    else
      @patients = patients
    end

    #if (@updated_patients.size > 0)
    #  OpsMailer.patient_status_query_alert(current_user, @updated_patients, @is_dm_account, @is_ckd_account)
    #  OpsMailer.cm_patient_status_change_alert(current_user, @updated_status_only)
    #end
    #if (@updated_for_cms_message.size > 0)
    #  OpsMailer.patient_cm_change_alert(current_user, @updated_for_cms_message)
    #end
    flash.now[:notice] = "Update for #{patient.last_name}, #{patient.first_name} successful."
    render 'index'
  end


  def update_case_managers patient, pat_id
    updated, added_cms = Account::CaseManagerAssignmentController.update_case_managers patient, pat_id, params

    if updated
      patient.save!
      @updated_for_cms_message << [patient, added_cms]
    end
    updated
  end

  def search
    get_account
    params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page]
    @ckd_stage_rollover = ckd_stage_rollover_text

    if params[:search].nil?
      # these params are always passed by the view, even when the user enters nothing, so this is just a sanity check
      raise ArgumentError, 'Search parameters not found.'
    else
      @case_managers = current_account.case_managers.order("contact.last_name, contact.first_name DESC")
      @patients = @account.patients.search_form(session, params[:search]).includes(:case_managers).paginate(:per_page => @per_page, :page => params[:page])
      @is_dm_account = session[:account_diseases].include? 'DM'
      @is_ckd_account = session[:account_diseases].include? 'CKD'
      render 'index'
    end
  end

  def ckd_stage_rollover_text

    'CKD Stages:<br>0 - No evidence of CKD.<br>2 - Early stage CKD (proteinuria with normal or near-normal filtration).  ICD9 585.2<br>3 - Established Stage 3 CKD (moderately depressed filtration). ICD9 585.3<br>4 - Established Stage 4 CKD (severely depressed filtration). ICD9 585.4<br>5 - Established Stage 5 CKD (renal failure). ICD9 585.5<br>A - Moderately depressed filtration without evidence of long-term damage. ICD9 583.9<br>H - History of renal abnormalities.  ICD-9 V13.09<br>P - Acute proteinuria (less than 90 days). ICD9 583.9'

  end

end

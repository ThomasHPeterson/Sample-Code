class Account::WorklistController < Account::BaseController
	before_filter :authenticate_user!
	skip_authorization_check

	# GET /worklist/index edit
	# GET /worklist/index.json
	def index
    get_account
    worklist

    if session[:account_diseases].include? "DM" and session[:account_diseases].include? "CKD"
      @all_active_dm = @account.patients.all_active_dm.count
      @all_active_ckd = @account.patients.all_active_ckd.count
      @all_active_total = @account.patients.all_active_dm_ckd.count
    elsif session[:account_diseases].include? "DM"
      @all_active_dm = @account.patients.all_active_dm.count
      @all_active_total = @all_active_dm
    elsif session[:account_diseases].include? "CKD"
      @all_active_ckd = @account.patients.all_active_ckd.count
      @all_active_total = @all_active_ckd
    end

		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @patients }
			format.js
      format.xls { render_xls }
		end
	end

  def worklist
    params[:per_page].nil? ? @per_page = Settings.pagination.per_page : @per_page = params[:per_page]

    unless params[:worklist_overdue_date].nil? or params[:worklist_overdue_date].empty?
      @worklist_overdue_date = Date.strptime params[:worklist_overdue_date], '%m-%d-%Y'
    end
    unless params[:worklist_due_soon_date].nil? or params[:worklist_due_soon_date].empty?
      @worklist_due_soon_date = Date.strptime params[:worklist_due_soon_date], '%m-%d-%Y'
    end

    # if user enters dates in the wrong order, just swap them
    if !@worklist_overdue_date.nil? and !@worklist_due_soon_date.nil? and
        @worklist_due_soon_date < @worklist_overdue_date
      tmp_date = @worklist_overdue_date
      @worklist_overdue_date = @worklist_due_soon_date
      @worklist_due_soon_date = tmp_date
    end

    # Can't filter columns on the test filter yet, because they're needed to populate the test filter options
    if session[:account_diseases].include?('CKD') and session[:account_diseases].include?('DM')
      default_test_filter = ['all_tests']
    elsif session[:account_diseases].include?('DM')
      default_test_filter = ['dm_tests']
    elsif session[:account_diseases].include?('CKD')
      default_test_filter = ['ckd_tests']
    end

    @all_tests = Settings.worklist.tests.all
    @test_filter_options = get_test_filter_options

    # test filter comes as an array from the form, but as a string from javascript-generated urls
    # convert strings to arrays
    if params[:test_filter].nil?
      @test_filter = default_test_filter
    elsif params[:test_filter].kind_of? Array
      @test_filter = params[:test_filter]
    else
      @test_filter = params[:test_filter].split(',')
    end

    @preset_options = get_preset_options
    @date_options = params[:date_options]
    @sort_by = params[:sort_by] ||= 'name'
    @case_managers = @account.case_managers.sort
    @case_manager = (params[:case_manager] == '' ? nil : params[:case_manager])
    @practices = @account.clients.uniq.sort
    @practice = (params[:practice]  == '' ? nil : params[:practice])
    @export_qty = params[:export_qty] ||= 'all'

    if @case_manager.nil? and @practice.nil?
      patients = @account.patients
    elsif @practice.nil?
      patients = Contact.find_by_contact_id(@case_manager.to_i).accepted_cm_patients
    elsif @case_manager.nil?
      patients = Client.find_by_client_id(@practice.to_i).patients
    else
      raise ArgumentError, 'Case Manager and Practice should not both be selected.'
    end

    # If user chooses only 'dm tests' or only 'ckd tests', then only use dm or ckd patients
    if @test_filter.size == 1 and session[:account_diseases].include? 'DM' and session[:account_diseases].include? 'CKD'
      if @test_filter[0] == 'dm_tests'
        flash.now[:notice] = "Since you chose 'DM Tests' only, results have been restricted to active DM patients."
        patients = patients.all_active_dm
      elsif @test_filter[0] == 'ckd_tests'
        flash.now[:notice] = "Since you chose 'CKD Tests' only, results have been restricted to active CKD patients."
        patients = patients.all_active_ckd
      else
        patients = patients.all_active_dm_ckd
      end
    else
      patients = patients.all_active_dm_ckd
    end

    # reduce display columns by the filter and restrict the where clause to only the relevant test due dates
    filter_columns_and_tests

    # Generate where clause
    upcoming_dm_where = ""
    upcoming_ckd_where = ""
    @dm_tests.each do |test|
      upcoming_dm_where += "("
      unless @worklist_overdue_date.nil?
        upcoming_dm_where += " #{test}_due_date >= '#{@worklist_overdue_date}' AND "
      end
      if @worklist_due_soon_date.nil?
        upcoming_dm_where += " #{test}_due_date <= '#{Date.today + 1000.days}') "
      else
        upcoming_dm_where += " #{test}_due_date <= '#{@worklist_due_soon_date}') "
      end

      unless test == @dm_tests.last
        upcoming_dm_where += " OR "
      end
    end

    @ckd_tests.each do |test|
      upcoming_ckd_where += "("
      unless @worklist_overdue_date.nil?
        upcoming_ckd_where += " #{test}_due_date >= '#{@worklist_overdue_date}' AND "
      end
      if @worklist_due_soon_date.nil?
        upcoming_ckd_where += " #{test}_due_date <= '#{Date.today + 1000.days}') "
      else
        upcoming_ckd_where += " #{test}_due_date <= '#{@worklist_due_soon_date}') "
      end

      unless test == @ckd_tests.last
        upcoming_ckd_where += " OR "
      end
    end

    if session[:account_diseases].include?('CKD') and session[:account_diseases].include?('DM')
      if !upcoming_dm_where.empty? and !upcoming_ckd_where.empty?
        upcoming = patients.joins(:worklist_view).where("#{upcoming_dm_where} OR #{upcoming_ckd_where}").includes(:status_lookup, :patient_state, :disease_stage_lookup, :patient_particip_status_lookup, :worklist_view).order('patient.last_name, patient.first_name, patient.dob ASC')
      elsif !upcoming_dm_where.empty?
        upcoming = patients.joins(:worklist_view).where(upcoming_dm_where).includes(:status_lookup, :patient_state, :disease_stage_lookup, :patient_particip_status_lookup, :worklist_view).order('patient.last_name, patient.first_name, patient.dob ASC')
      else
        upcoming = patients.joins(:worklist_view).where(upcoming_ckd_where).includes(:status_lookup, :patient_state, :disease_stage_lookup, :patient_particip_status_lookup, :worklist_view).order('patient.last_name, patient.first_name, patient.dob ASC')
      end

    elsif session[:account_diseases].include?('DM')
      upcoming = patients.joins(:worklist_view).where(upcoming_dm_where).includes(:status_lookup, :patient_state, :disease_stage_lookup, :patient_particip_status_lookup, :worklist_view).order('patient.last_name, patient.first_name, patient.dob ASC')

    elsif session[:account_diseases].include?('CKD')
      upcoming = patients.joins(:worklist_view).where(upcoming_ckd_where).includes(:status_lookup, :patient_state, :disease_stage_lookup, :patient_particip_status_lookup, :worklist_view).order('patient.last_name, patient.first_name, patient.dob ASC')
    end

    # sort by earliest due date here, before pagination
    if @sort_by == 'date'
      upcoming = filter_by_earliest_date upcoming
    end

    @upcoming = upcoming.paginate(:per_page => @per_page, :page => params[:page])

    if @export_qty == 'all'
      @upcoming_for_xls = upcoming
    else
      @upcoming_for_xls = @upcoming
    end




  end

  def get_test_filter_options
    options = []
    if session[:account_diseases].include?('CKD') and session[:account_diseases].include?('DM')
      options << ['All Tests', 'all_tests']
      options << ['DM Tests', 'dm_tests']
      options << ['CKD Tests', 'ckd_tests']
      column_options = Settings.worklist.display_columns.all
    elsif session[:account_diseases].include?('DM')
      options << ['DM Tests', 'dm_tests']
      column_options = Settings.worklist.display_columns.dm
    elsif session[:account_diseases].include?('CKD')
      options << ['CKD Tests', 'ckd_tests']
      column_options = Settings.worklist.display_columns.ckd
    end

    column_options.each do |k, v|
      if k == 'Phosphorous'
        k = 'Phos'
      end
      options << [k, v]
    end
    options
  end

  def filter_columns_and_tests
    @columns = {}
    @dm_tests = []
    @ckd_tests = []
    all_dm_tests = Settings.worklist.tests.dm
    all_ckd_tests = Settings.worklist.tests.ckd
    all_column_options = Settings.worklist.display_columns.all
    if @test_filter.include? 'all_tests'
      @columns.merge! all_column_options
      @dm_tests = all_dm_tests
      @ckd_tests = all_ckd_tests
    elsif @test_filter.include? 'dm_tests'
      @columns.merge! Settings.worklist.display_columns.dm
      @dm_tests = all_dm_tests
      if @test_filter.include? 'ckd_tests'
        @columns.merge! Settings.worklist.display_columns.ckd
        @ckd_tests = all_ckd_tests
      end
    elsif @test_filter.include? 'ckd_tests'
      @columns.merge! Settings.worklist.display_columns.ckd
      @ckd_tests = all_ckd_tests
    end

    all_column_options.each do |k, v|
      if @test_filter.include? v and !@columns.include? [k, v]
        @columns[k] = v
        if all_dm_tests.include? v and !@dm_tests.include? v
          @dm_tests << v
        end
        if all_ckd_tests.include? v and !@ckd_tests.include? v
          @ckd_tests << v
        end
      end
    end
  end

  def render_xls
    rows = []
    head_array = [ "PES Patient ID", "Patient", "Address 1", "Address 2", "City", "State", "Zip", "Phone", "Cell Phone", "E-mail", "Date of Birth", "Sex", "Provider", "Practice", "DM", "CKD Stage" ]
    col_array = [ :patient_id, :name, :address_1, :address_2, :city, :state, :zip, :phone, :phone_2, :email, :dob, :sex, :pcp, :practice, :dm, :ckd ]

    # These have been filtered by session diseases below, so they
    # will correspond to the tests that populate the col_array
    @columns.each do |k, v|
      head_array << k
      col_array << "#{v.downcase}".to_sym
    end

    tests = []
    active_dm = session[:account_diseases].include?('DM')
    active_ckd = session[:account_diseases].include?('CKD')
    if active_dm and active_ckd
      tests = @dm_tests + @ckd_tests
      tests = tests.uniq
    elsif active_ckd
      tests = @ckd_tests
    elsif active_dm
      tests = @dm_tests
    end

    #tests.each do |test|
    #  col_array << "#{test.downcase}".to_sym
    #end

    @upcoming_for_xls.each do |patient|
      pat_dob = patient.dob.strftime('%m-%d-%Y')
      if patient.location.nil?
        address_1 = ''
        address_2 = ''
        city = ''
        state = ''
        zip = ''
        phone = ''
        phone_2 = ''
        email = ''
      else
        address_1 = patient.location.address_1
        address_2 = patient.location.address_2
        city = patient.location.city
        state = patient.location.state
        zip = patient.location.zip
        phone = patient.location.phone
        phone_2 = patient.location.phone_2
        email = patient.location.email
      end

      row = WorklistRow.new(patient.patient_id, patient.name, address_1, address_2, city, state, zip, phone, phone_2, email, pat_dob, patient.sex, patient.contact.name, patient.contact.clients.first.to_s, patient.str_active_dm, patient.str_active_ckd)
      @columns.each do |k, v|
        row.send("#{v.downcase}=",
                 patient.overdue_text(k, v, tests, @worklist_overdue_date, @worklist_due_soon_date, @dm_tests, @ckd_tests))
      end
      rows << row
    end

    render :xls => rows,
           :columns => col_array,
           :headers => head_array

  end

  def get_preset_options

    options = []
    options << ['-- any --', '->']
    options << ['overdue as of today', "->#{(Date.today - 1.day).strftime('%m-%d-%Y')}"]
    options << ['overdue more than 90 days', "->#{(Date.today - 90.days).strftime('%m-%d-%Y')}"]
    options << ['overdue 60 to 90 days', "#{(Date.today - 90.days).strftime('%m-%d-%Y')}->#{(Date.today - 60.days).strftime('%m-%d-%Y')}"]
    options << ['overdue 30 to 60 days', "#{(Date.today - 60.days).strftime('%m-%d-%Y')}->#{(Date.today - 30.days).strftime('%m-%d-%Y')}"]
    options << ['overdue 0 to 30 days', "#{(Date.today - 30.days).strftime('%m-%d-%Y')}->#{(Date.today).strftime('%m-%d-%Y')}"]
    options << ['upcoming in 14 days', "#{(Date.today).strftime('%m-%d-%Y')}->#{(Date.today + 14.days).strftime('%m-%d-%Y')}"]
    options << ['-- custom --', 'custom']
  end

  def filter_by_earliest_date upcoming
    tests = @dm_tests + @ckd_tests
    date_hash = {}
    this_upcoming = []
    upcoming.each do |patient|
      earliest = nil
      @columns.each do |k, v|
        if tests.include?(v)
          this_date = patient.worklist_view.due_date v
          unless this_date.nil?
            if ((earliest.nil? or this_date < earliest) and
                (@worklist_overdue_date.nil? or this_date >= @worklist_overdue_date) and
                (@worklist_due_soon_date.nil? or this_date <= @worklist_due_soon_date))
              earliest = this_date
            end
          end
        end
      end
      unless earliest.nil?
        # patients could have the same earliest date, so make sure the hash key is unique
        date_hash["#{earliest.to_date}|#{patient.last_name}|#{patient.first_name}|#{patient.middle_name}|#{patient.dob.to_date}"] = patient
      end
    end

    date_hash.sort.map do |k, v|
      this_upcoming << v
    end
    this_upcoming
  end

  end
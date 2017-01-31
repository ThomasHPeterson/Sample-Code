class ApplicationController < ActionController::Base
	protect_from_forgery
	check_authorization :unless => :devise_controller?, :except => :change_session_variables_in_dev
	before_filter :log_tracker
  helper_method :current_account, :user_has_permission?, :generate_password, :get_home_path, :obfuscate_encrypt, :obfuscate_decrypt
	
	def current_account
	  current_user.account
	end
	
	def user_has_permission?
	 current_user.account.include?(resource.account)
	end

	def help
		Helper.instance
	end

	class Helper
		include Singleton
		include ActionView::Helpers::TextHelper
		include ActionView::Helpers::TagHelper
		include ActionView::Helpers::AssetTagHelper
	end

	rescue_from CanCan::AccessDenied do |exception|
		if Rails.env.developmentdb?
			begin
				redirect_to :back, :alert => "Access denied on #{exception.action} #{exception.subject.inspect}"
			rescue ActionController::RedirectBackError
				redirect_to root_url, :alert => "Access denied on #{exception.action} #{exception.subject.inspect}"
			end
		else
			redirect_to root_url, :alert => exception.message
		end
	end

	def change_session_variables_in_dev
		if Rails.env.developmentdb?
			params[:account_diseases] ||= []
			session[:account_diseases] = params[:account_diseases]
		end
		redirect_to :back
	end

	def log_tracker
		Rails.logger.add(1, "Log Date: #{DateTime.now}")
	end

	protected

	def audit_log
		@@audit_log ||= Logger.new("#{Rails.root}/log/audit.log")
	end

	def log_resource(resource)
		ip = request.remote_ip
		klass = resource.class
		audit_log.info("#{Time.now}: #{current_user.id} from #{ip} received #{klass} #{resource.inspect}")
	end

	def log_url
		if request.get?
			url = request.fullpath
			params = request.request_parameters
			ip = request.remote_ip
			audit_log.info("#{Time.now}: #{current_user.id} from #{ip} requested #{url} with params #{params}")
		end
	end

  def after_sign_in_path_for(resource)

    account = current_user.account

    if current_user.has_role? 'AccountUser', 'User'# , 'PatientUser'

      session[:account_diseases] = []
      session[:account_diseases] << "DM" if account.covers_disease?(1)
      session[:account_diseases] << "CKD" if account.covers_disease?(2)
    elsif current_user.has_role? 'CaseManager'
      session[:account_diseases] = []
      session[:account_diseases] << "DM" if account.covers_disease?(1)
      session[:account_diseases] << "CKD" if account.covers_disease?(2)
    else
      session[:account_diseases] = ["DM", "CKD"]
    end

    if current_user.has_role? 'AccountUser', 'CaseManager', 'User', 'PatientUser'
      session[:account_id] = current_user.account_id
    end

    if current_user.user_security_question.nil?
      user_new_question_path
    else
      set_session_ints
      get_home_path
    end

  end


  def set_session_ints
    # purposely using magic number symbols, to be unclear what they're for
    session[:num_1] = rand(10...100)
    session[:num_2] = rand(10...100)
    session[:num_3] = rand(10...100)
    session[:num_4] = rand(10...100)
    session[:num_5] = rand(100000000000...1000000000000)
  end

  def obfuscate_encrypt id, session
    Obfuscate.encrypt_with_session id, session
  end

  def obfuscate_decrypt id, session
    Obfuscate.decrypt_with_session id, session
  end

  def obfuscate_decrypt_array ids, session
    Obfuscate.decrypt_array_with_session ids, session
  end



  def get_home_path
    # Account and Case Managers for a CKD-only account should have their root pages on the CKD Data dashboard
    if session[:account_diseases].nil? or session[:account_diseases].include? 'DM'
      root_path
    elsif current_user.nil?
      root_path
    else
      if current_user.has_role? 'AccountUser'
        account_ckd_path
      elsif current_user.has_role? 'CaseManager'
        case_manager_ckd_path
      else
        root_path
      end
    end

  end


	private
	
	# Overwriting the sign_out redirect path method
  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  def check_session_expiration

    unless current_user.nil?
      if current_user.has_role?("Admin", "SuperAdmin", "Operations")
        time_interval = 15.minutes.ago
      else
        time_interval = 5.minutes.ago
      end

      if !session[:last_seen].nil? and session[:last_seen] < time_interval
        session[:last_seen] = nil
        if user_signed_in?
          sign_out current_user
        end
        # notice is not being displayed; redirect appears to reset the flash hash.
        flash[:notice] = "Your session has expired.  Please sign in again to continue."
        redirect_to root_url
      else
        session[:last_seen] = Time.now
      end
    end
  end

  def generate_password
    pwd = ''
    chars = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a - %w(0 1 I O)
    8.times { pwd << chars[SecureRandom.random_number(chars.length)] }
    unless ( ('A'..'Z').to_a.any? { |ch| pwd.include? ch } and
             ('a'..'z').to_a.any? { |ch| pwd.include? ch } and
             ('0'..'9').to_a.any? { |ch| pwd.include? ch } )
      pwd = generate_password

    end
    pwd
  end

  # Called by account and admin/patient/under_prov_review tabs
  def render_under_prov_review_spreadsheet

    Spreadsheet.client_encoding = 'UTF-8'
    book = Spreadsheet::Workbook.new

    bold_format = Spreadsheet::Format.new :weight => :bold
    red_format = Spreadsheet::Format.new :color => :red
    green_format = Spreadsheet::Format.new :color => :green

    if params[:type] == 'dm'

      filename = 'DM_Patients_Under_Provider_Review.xls'
      sheetname = 'DM Patients'

      sheet = book.create_worksheet :name => sheetname

      i = 0;
      total_dm_pats = 0;
      @dm_pats.each do |contact, patients|
        sheet.row(i).set_format(0, bold_format)
        sheet.row(i).push contact.name, '', '', contact.clients.first.to_s
        i += 1
        [*0..6].each do |col|
          sheet.row(i).set_format(col, bold_format)
        end
        sheet.row(i).push 'Patient Name', 'PES ID', 'Date of Birth', 'Sex', 'Status Date', 'Days'
        i += 1
        patients.each do |patient|
          pat_name = "#{patient.last_name}, #{patient.first_name}"
          stat_change_date = patient.patient_status_change_histories.where("patient_status_change_history.latest_status = 'Y'").to_a()[0].date_time.to_date
          days = (Date.today - stat_change_date).to_i
          if (days < 15)
            sheet.row(i).set_format(5, green_format)
          else
            sheet.row(i).set_format(5, red_format)
          end
          sheet.row(i).push pat_name, patient.patient_id, patient.dob.to_date.strftime('%m-%d-%Y'), patient.sex, stat_change_date.strftime('%m-%d-%Y'), days
          i += 1
          total_dm_pats += 1
        end
        sheet.row(i).push "#{pluralize(patients.size, 'patient')} pending in status Under Provider Review"
        i += 1
        sheet.row(i).push ''
        i += 1
      end
      sheet.row(i).set_format(0, bold_format)
      sheet.row(i).push "#{pluralize(total_dm_pats, 'DM patient')} Under Provider Review for all PCPs"

    elsif params[:type] == 'ckd'

      filename = 'CKD_Patients_Under_Provider_Review.xls'
      sheetname = 'CKD Patients'

      sheet = book.create_worksheet :name => sheetname

      i = 0;
      total_ckd_pats = 0;
      @ckd_pats.each do |contact, patients|
        sheet.row(i).set_format(0, bold_format)
        sheet.row(i).push contact.name, '', '', contact.clients.first.to_s
        i += 1
        [*0..8].each do |col|
          sheet.row(i).set_format(col, bold_format)
        end
        sheet.row(i).push 'Patient Name', 'PES ID', 'Date of Birth', 'Sex', 'DM Status', 'CKD Stage', 'Status Date', 'Days'
        i += 1
        patients.each do |patient|
          pat_name = "#{patient.last_name}, #{patient.first_name}"
          stat_change_date = patient.patient_state_change_histories.where(" patient_state_change_history.status_type = 'PARTICIP' AND patient_state_change_history.latest_status = 'Y'").to_a()[0].date_time.to_date
          days = (Date.today - stat_change_date).to_i
          if (days < 15)
            sheet.row(i).set_format(7, green_format)
          else
            sheet.row(i).set_format(7, red_format)
          end
          sheet.row(i).push pat_name, patient.patient_id, patient.dob.to_date.strftime('%m-%d-%Y'), patient.sex, patient.status_lookup.patient_status.humanize, patient.disease_stage_lookup.short_description, stat_change_date.strftime('%m-%d-%Y'), days
          i += 1
          total_ckd_pats += 1
        end
        sheet.row(i).push "#{pluralize(patients.size, 'patient')} pending in status Under Provider Review"
        i += 1
        sheet.row(i).push ''
        i += 1
      end
      sheet.row(i).set_format(0, bold_format)
      sheet.row(i).push "#{pluralize(total_ckd_pats, 'CKD patient')} Under Provider Review for all PCPs"
    end

    blob = StringIO.new('')
    book.write blob
    send_data blob.string, :type => 'xls', :filename => filename
  end

end

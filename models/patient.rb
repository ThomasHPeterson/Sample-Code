class Patient < ActiveRecord::Base

	acts_as_commentable

	belongs_to :contact, :foreign_key => :primary_provider
	belongs_to :location, :foreign_key => :patient_home_location
	has_one :patient_status
	has_one :patient_state
  has_one :patient_plan
  has_one :status_lookup, :through => :patient_status
  has_one :patient_plan_lookup, :through => :patient_plan
  has_many :test_results
	has_many :reports
	has_many :test_codes, :through => :test_results
	has_one :overdue_dm
	has_one :patient_account
	has_one :account, :through => :patient_account
	has_many :comments, :as => :commentable
	has_one :patient_lab_history
	has_many :patient_status_change_histories
	has_many :patient_state_change_histories
  has_many :primary_prvdr_change_histories
	has_one :patient_particip_status_lookup, :through => :patient_state
	has_one :patient_coverage_status_lookup, :through => :patient_state
	has_one :ordering_provider_status_lookup, :through => :patient_state
	has_one :patient_pcp_status_lookup, :through => :patient_state
	has_one :disease_stage_lookup, :through => :patient_state
  has_one :dm_extended_lookup, :through => :status_lookup, :source => :patient_extended_status_lookup
  has_one :ckd_extended_lookup, :through => :patient_particip_status_lookup, :source => :patient_extended_status_lookup
	has_many :alternative_patient_ids
	has_one :overdue
  has_one :worklist_view
  has_one :report_visibility
  has_one :ckd_pop_report_last_results
  has_one :dm_pop_report_last_results
  has_many :case_manager_patients
  has_many :case_managers, :through => :case_manager_patients, :source => :contact
  has_one :user
  has_one :ckd_patient_staging_data
  has_one :demo_pat_mapping, foreign_key: 'prod_patient_id'
  has_one :last_report_sent
  has_many :overdue_tests
  has_many :parsed_outreach_results, foreign_key: 'vdis_patient_id'
  has_many :parsed_results_archives, foreign_key: 'vdis_patient_id'
  has_many :parsed_results_dupes, foreign_key: 'vdis_patient_id'
  has_many :patient_account_change_histories
  has_many :patient_change_histories
  has_one :patient_lab_history_status
  has_one :patient_reports
  has_many :patient_reports_dues
  has_many :patient_test_due_dates
  has_many :patient_reminder_due_dates
  has_many :reminder_test_datas
  has_many :patient_events
  belongs_to :epmg_study_roster
  has_one :patient_display_data

  attr_accessible :last_name, :first_name, :middle_name, :dob, :assign_status, :assign_status_comment, :assign_ckd_particip_status, :assign_ckd_particip_status_comment, :assign_ckd_coverage_status, :assign_ckd_coverage_status_comment, :assign_ckd_particip_updater_user_id, :assign_ckd_coverage_updater_user_id, :assign_dm_updater_user_id, :assign_account, :assign_pcp_change_comment, :pcp

	audited :protect => false

	# Sorts. None of these are being used.
	scope :order, order('last_name, first_name, middle_name, dob ASC')
	scope :sort_by_last_name_asc, order('last_name, first_name, middle_name, dob ASC')
	scope :sort_by_last_name_desc, order('last_name DESC, first_name, middle_name, dob ASC')
	scope :sort_by_first_name_asc, order('first_name, last_name, middle_name, dob ASC')
	scope :sort_by_first_name_desc, order('first_name DESC, last_name, middle_name, dob ASC')
	scope :sort_by_dob_asc, order('dob, last_name, first_name, middle_name ASC')
	scope :sort_by_dob_desc, order('dob DESC, last_name, first_name, middle_name ASC')
	scope :sort_by_status_asc, includes(:status_lookup).order('patient_status_lookup.patient_status, last_name, first_name, middle_name, dob ASC')
	scope :sort_by_status_desc, includes(:status_lookup).order('patient_status_lookup.patient_status DESC, last_name, first_name, middle_name, dob ASC')
	
  # all active patients
  # This is actually only all active dm patients.  Replaced with :all_active_dm and Using :all_active_dm_ckd wherever "all active" is really meant.
  #scope :all_active, joins(:patient_status).where('patient_status.patient_status_id' => 1.0)
	# pop report statuses per disease
	# Diabetes
  # added by sam in august
	scope :all_active_dm, joins(:patient_status).where('patient_status.patient_status_id' => 1)
	scope :inactive_dm, joins(:patient_status).where('patient_status.patient_status_id' => [6,8,21,22,23,26,27,29,33,35,100])
  # old queries
	scope :pop_active_dm, joins(:status_lookup).where("pcp_panel_type = 'A'")
	scope :pop_inactive_dm, joins(:status_lookup).where("pcp_panel_type = 'I'")
	scope :pop_active_or_inactive_dm, joins(:status_lookup).where("pcp_panel_type in ('A', 'I')")
	scope :pop_inactive_or_invisible_dm, joins(:status_lookup).where("pcp_panel_type in ('I', 'N')")
	scope :pop_invisible_dm, joins(:status_lookup).where("pcp_panel_type = 'N'")
	# Chronic Kidney Disease
  # added by Sam in August 2013
	scope :all_active_ckd, joins(:patient_state).where('patient_state.patient_particip_status_id' => 1)
	scope :covered_ckd, joins(:patient_state).where("patient_state.patient_coverage_status_id" => [1,2])
  scope :particip_ckd, joins(:patient_state).where("patient_state.patient_particip_status_id" => [3,5,6,8,10,12,13,14,15,98])
  
  # old queries
	scope :pop_active_ckd, joins(:report_visibility).where("visibility = 'ACTIVE'")

	#scope :pop_inactive_ckd, joins(:report_visibility).where("visibility = 'INACTIVE'")
  # Updated by Tom P., 1/13/2014, to match the conditions in the Crystal Pop Reports
  scope :pop_inactive_ckd, joins(:patient_state).joins(:disease_stage_lookup).joins(:patient_particip_status_lookup).where("patient_state.patient_particip_status_id" => [2,3,8,10,11,15]).where('patient_state.disease_stage_id > 3')

  scope :pop_active_or_inactive_ckd, joins(:report_visibility).where("visibility in ('ACTIVE', 'INACTIVE')")
	scope :pop_inactive_or_invisible_ckd, joins(:report_visibility).where("visibility in ('INACTIVE', 'INVISIBLE')")
	scope :pop_invisible_ckd, joins(:report_visibility).where("visibility = 'INVISIBLE'")
	# Both Diabetes and Chronic Kidney Disease
  # added by Sam in August 2013
	scope :all_active_dm_ckd, joins(:patient_status, :patient_state).where("patient_status.patient_status_id = ? OR patient_state.patient_particip_status_id = ?", 1,1)
  # added by Tom, 2/11/2014, to replace inactive defined as particip_ckd
  #scope :all_inactive_dm_ckd, joins(:patient_status, :patient_state).where("patient_status.patient_status_id <> ? AND patient_state.patient_particip_status_id <> ?AND patient_state.patient_particip_status_id <> ?", 1,1,2)
  # changed by Tom, 4/16/2014, restricting to just patients on inactive roster (filters out healthy patients with no tests)
  scope :all_inactive_dm_ckd, joins(:patient_status, :patient_state).where("(patient_status.patient_status_id IN (6, 8, 21, 22, 23, 26, 27, 29, 33, 35, 100) AND patient_state.patient_particip_status_id <> 1) OR (patient_status.patient_status_id <> 1 AND patient_state.patient_particip_status_id IN (2, 3, 5, 6, 8, 10, 12, 13, 14, 15, 98))")
  scope :all_inactive_dm, joins(:patient_status).where("patient_status.patient_status_id IN (6, 8, 21, 22, 23, 26, 27, 29, 33, 35, 100) AND patient_state.patient_particip_status_id <> 1")
  scope :all_inactive_ckd, joins(:patient_state).where("patient_status.patient_status_id <> 1 AND patient_state.patient_particip_status_id IN (2, 3, 5, 6, 8, 10, 12, 13, 14, 15, 98)")

  # Old queries
	scope :pop_active_dm_and_ckd, joins(:status_lookup, :report_visibility).where("pcp_panel_type = 'A' and visibility = 'ACTIVE'")
	scope :pop_inactive_dm_and_ckd, joins(:status_lookup, :report_visibility).where("pcp_panel_type = 'I' and visibility = 'INACTIVE'")
	scope :pop_inactive_or_invisible_dm_and_ckd, joins(:status_lookup, :report_visibility).where("pcp_panel_type in ('I', 'N') and visibility in ('INACTIVE', 'INVISIBLE')")
	scope :pop_invisible_dm_and_ckd, joins(:status_lookup, :report_visibility).where("pcp_panel_type = 'N' and visibility = 'INVISIBLE'")
	# Either Diabetes or Chronic Kidney Disease
	scope :pop_active_dm_or_ckd, joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id").where("patient_status_lookup.pcp_panel_type = 'A' or v_report_visibility.visibility = 'ACTIVE'")
	scope :pop_inactive_dm_or_ckd, joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id").where("patient_status_lookup.pcp_panel_type = 'I' or v_report_visibility.visibility = 'INACTIVE'")
	scope :pop_inactive_or_invisible_dm_or_ckd, joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id").where("patient_status_lookup.pcp_panel_type in ('I', 'N') or v_report_visibility.visibility in ('INACTIVE', 'INVISIBLE')")
	scope :pop_invisible_dm_or_ckd, joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id").where("patient_status_lookup.pcp_panel_type = 'N' or v_report_visibility.visibility = 'INVISIBLE'")
	scope :pop_not_invisible_dm_and_ckd, joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id").where("patient_status_lookup.pcp_panel_type <> 'N' or v_report_visibility.visibility <> 'INVISIBLE'")

	# Error status states. Patients who are REFUSED, DECEASED, or UNDERAGE need to be set to that status for all diseases
	scope :deceased_errors, joins(:status_lookup, :patient_particip_status_lookup).where("(patient_status_lookup.patient_status = 'DECEASED' and patient_particip_status_lookup.patient_particip_status <> 'Deceased') OR (patient_status_lookup.patient_status <> 'DECEASED' and patient_particip_status_lookup.patient_particip_status = 'Deceased')")
	scope :refused_errors, joins(:status_lookup, :patient_particip_status_lookup).where("(patient_status_lookup.patient_status = 'REFUSED' and patient_particip_status_lookup.patient_particip_status <> 'Refused') OR (patient_status_lookup.patient_status <> 'REFUSED' and patient_particip_status_lookup.patient_particip_status = 'Refused')")
  # These next three altered to ignore statuses of diseases not covered by the account. Tom P., iTracker 285, 12/17/2014
	scope :underage_errors, joins(:status_lookup, :patient_particip_status_lookup).where("(patient_status_lookup.patient_status = 'INELIGIBLE-UNDERAGE' and patient_particip_status_lookup.patient_particip_status <> 'Ineligible - Underage') OR (patient_status_lookup.patient_status not in ('INELIGIBLE-UNDERAGE', 'NOT COVERED') and patient_particip_status_lookup.patient_particip_status = 'Ineligible - Underage')").joins("LEFT JOIN patient_account ON patient_account.patient_id = patient.patient_id").where("patient_account.patient_account_status = 1").joins("INNER JOIN account_covers_disease acr1 ON acr1.account_id = patient_account.account_id").where("acr1.disease_id = 1").joins("INNER JOIN account_covers_disease acr2 ON acr2.account_id = patient_account.account_id").where("acr2.disease_id = 2")
	scope :should_be_underage, joins("left join patient_status on patient_status.patient_id = patient.patient_id left join patient_state on patient_state.patient_id = patient.patient_id LEFT JOIN patient_account ON patient_account.patient_id = patient.patient_id INNER JOIN account_covers_disease ON account_covers_disease.account_id = patient_account.account_id").where("patient.dob > ?", 18.years.ago).where("((patient_state.patient_particip_status_id <> 7 and patient_account.patient_account_status = 1 and account_covers_disease.disease_id = 2) OR ((patient_status.patient_status_id not in (9, 36)) and patient_account.patient_account_status = 1 and account_covers_disease.disease_id = 1))").uniq
  scope :now_of_age, joins("LEFT JOIN patient_status ON patient_status.patient_id = patient.patient_id LEFT JOIN patient_state ON patient_state.patient_id = patient.patient_id LEFT JOIN patient_account ON patient_account.patient_id = patient.patient_id LEFT JOIN account_covers_disease ON account_covers_disease.account_id = patient_account.account_id").where("patient.dob <= ?", 18.years.ago).where("(patient_state.patient_particip_status_id = 7 and patient_account.patient_account_status = 1 and account_covers_disease.disease_id = 2) OR (patient_status.patient_status_id = 36 and patient_account.patient_account_status = 1 and account_covers_disease.disease_id = 1)").uniq

	scope :with_provider, where("patient.primary_provider <> 0 and patient.primary_provider is not null")
  scope :with_plan, lambda { |plan_id| joins(:patient_plan).where("patient_plan.plan_id = ?", plan_id) }
  scope :with_status, lambda { |*patient_statuses| joins(:patient_status).where("patient_status.patient_status_id IN (?)", patient_statuses) }
	scope :without_status, lambda { |*patient_statuses| joins(:patient_status).where("patient_status.patient_status_id NOT IN (?)", patient_statuses) }
	scope :high_result, lambda { |test| joins(:test_results).joins(:test_codes).where("service_directory.test_code = ? and test_result.result_range = 'HIGH'", test) }
  # work-around method to avoid bad data in VDISDEV.  Used by admin/patients_controller.
  scope :with_any_status, joins(:patient_status).joins(:patient_account).order("patient.last_name, patient.first_name, patient.middle_name, patient.dob ASC")
  # TODO: These simple methods are only dm, so misleading.  Replace.
	scope :active, joins(:patient_status).where("patient_status.patient_status_id = 1")
	scope :inactive, joins(:patient_status).where("patient_status.patient_status_id in (21, 22, 26, 27, 29)")
	scope :ckd_active, joins(:patient_state).where("patient_state.disease_stage_id not in (3, 99) AND patient_state.patient_particip_status_id = 1 AND patient_state.patient_coverage_status_id in (1,2)")
  scope :dm_or_ckd_active, where("(patient_state.disease_stage_id not in (3, 99) AND patient_state.patient_particip_status_id = 1 AND patient_state.patient_coverage_status_id in (1,2)) OR (patient_status.patient_status_id = 1)").includes(:patient_state, :patient_status)
	scope :with_ckd_coverage_status, lambda { |*coverage_statuses| joins(:patient_state).where("patient_state.patient_coverage_status_id IN (?)", coverage_statuses) }
	scope :with_ckd_particip_status, lambda { |*particip_statuses| joins(:patient_state).where("patient_state.patient_particip_status_id IN (?)", particip_statuses) }
	scope :without_ckd_particip_status, lambda { |*particip_statuses| joins(:patient_state).where("patient_state.patient_particip_status_id NOT IN (?)", particip_statuses) }
	scope :with_ckd_disease_stage, lambda { |*disease_stages| joins(:patient_state).where("patient_state.disease_stage_id IN (?)", disease_stages) }
  scope :has_test, lambda { |test| joins(:test_results).joins(:test_codes).where("service_directory.test_code = ?", test) }
  scope :for_case_manager, lambda { |case_manager| joins(:case_manager_patients).where("case_manager_patient.case_manager_id = ? AND case_manager_patient.accepted = ?", case_manager.contact_id, 'Y') }
  scope :in_account, lambda { |account| joins(:patient_account).where("patient_account.account_id = ?", account.account_id) }
  scope :in_account_with_cm, lambda { |account| joins(:patient_account).where("patient_account.account_id = ?", account.account_id).includes(:case_managers) }
  scope :in_account_with_cm_assigned, lambda { |account| joins(:patient_account).where("patient_account.account_id = ? AND EXISTS (SELECT case_manager_patient.patient_id FROM case_manager_patient WHERE case_manager_patient.patient_id = patient.patient_id)", account.account_id) }
  scope :in_account_with_cm_unassigned, lambda { |account| joins(:patient_account).where("patient_account.account_id = ? AND NOT EXISTS (SELECT case_manager_patient.patient_id FROM case_manager_patient WHERE case_manager_patient.patient_id = patient.patient_id)", account.account_id) }
  scope :in_account_with_cm_by_provider, lambda { |account, provider| joins(:patient_account).where("patient_account.account_id = ? AND patient.primary_provider = ?", account.account_id, provider.contact_id).includes(:case_managers) }
  scope :in_account_with_cm_assigned_by_provider, lambda { |account, provider| joins(:patient_account).where("patient_account.account_id = ? AND patient.primary_provider = ? AND EXISTS (SELECT case_manager_patient.patient_id FROM case_manager_patient WHERE case_manager_patient.patient_id = patient.patient_id)", account.account_id, provider.contact_id) }
  scope :in_account_with_cm_unassigned_by_provider, lambda { |account, provider| joins(:patient_account).where("patient_account.account_id = ? AND patient.primary_provider = ? AND NOT EXISTS (SELECT case_manager_patient.patient_id FROM case_manager_patient WHERE case_manager_patient.patient_id = patient.patient_id)", account.account_id, provider.contact_id) }
  scope :eighteen_to_seventyfive,  where("patient.dob <= ? and patient.dob >= ?", Date.today - 18.years, Date.today - 75.years).includes(:test_results)
  scope :recent_status_changes, includes(:patient_status_change_histories, :patient_state_change_histories).where("(patient_status_change_history.latest_status = ? AND patient_status_change_history.date_time >= ?) OR (patient.patient_id = patient_state_change_history.patient_id AND patient_state_change_history.latest_status = ? AND patient_state_change_history.status_type = ? and patient_state_change_history.date_time >= ?)", 'Y', Date.today - 30.days, 'Y', 'PARTICIP', Date.today - 30.days)
  scope :recently_assigned, lambda { |case_manager| joins(:case_manager_patients).where("(case_manager_patient.accepted is null or case_manager_patient.accepted <> ?) and case_manager_patient.case_manager_id = ?", 'Y', case_manager.contact_id) }
  scope :without_cm, includes(:case_manager_patients).where("patient.patient_id NOT IN (select case_manager_patient.patient_id from case_manager_patient)")
  scope :without_cm_acceptance, includes(:case_manager_patients).where("patient.patient_id IN (select cmp1.patient_id from case_manager_patient cmp1) AND NOT EXISTS (select cmp2.patient_id from case_manager_patient cmp2 WHERE cmp2.patient_id = patient.patient_id AND cmp2.accepted = ?)", 'Y')
  scope :with_recent_test_results, includes(:test_results).where("EXISTS (SELECT test_result.patient_id FROM test_result where patient.patient_id = test_result.patient_id AND test_result.result_date > ?)", Date.today - 3.months).order("test_result.result_date DESC")
  scope :with_test_results_since, lambda { |date| includes(:test_results).where("test_result.result_date > ?", date).order("test_result.result_date DESC")}
  scope :with_comments, includes(:comments).order('last_name, first_name, middle_name, dob ASC')
  scope :with_client, lambda { |client_id| joins(:contact).joins("INNER JOIN works_for_employs ON works_for_employs.contact_id = contact.contact_id").where("works_for_employs.client_id = ?", client_id.to_i) }
	scope :by_current_provider, lambda {|prov_id| where("current_provider = ?", prov_id)}

  # Use this method when the db is vdisdev, because there are too many duplicates there.
  if Rails.env.staging? or Rails.env.developmentdb?
    scope :duplicates, select("patient.*").where("patient.first_name = p2.first_name AND patient.last_name = p2.last_name AND patient.dob = p2.dob AND patient.patient_id <> p2.patient_id and patient.last_name LIKE 'AN%' and rownum < 100").from("patient, patient p2").order("patient.last_name, patient.first_name, patient.dob ASC")
  else
    # Switch to the method below when going to production.
    scope :duplicates, select("patient.*").where("patient.first_name = p2.first_name AND patient.last_name = p2.last_name AND patient.dob = p2.dob AND patient.patient_id <> p2.patient_id").from("patient, patient p2").order("patient.last_name, patient.first_name, patient.dob ASC")
  end

  scope :duplicate, lambda { |patient_id| select("patient.patient_id").where("patient.first_name = p2.first_name AND patient.last_name = p2.last_name AND patient.dob = p2.dob AND patient.patient_id <> p2.patient_id and p2.patient_id = ?", patient_id).from("patient, patient p2") }

	scope :upcoming, lambda { |overdue_days, upcoming_days| joins(:overdue_dm).joins("LEFT JOIN patient_lab_history_status plhs ON  v_vdis_reminder_overdue_data.patient_id = plhs.patient_id").where("(a1c_next_test_date < sysdate + #{upcoming_days} AND a1c_next_test_date >= sysdate - #{overdue_days})
										OR (ldl_next_test_date < sysdate + #{upcoming_days} AND ldl_next_test_date >= sysdate - #{overdue_days})
										OR (uab_next_test_date < sysdate + #{upcoming_days} AND uab_next_test_date >= sysdate - #{overdue_days})
										OR (a1c_next_test_date IS NULL AND plhs.history_start_date + 180 < sysdate + #{upcoming_days} AND plhs.history_start_date + 180 >= sysdate - #{overdue_days}) 
										OR (ldl_next_test_date IS NULL AND plhs.history_start_date + 365 < sysdate + #{upcoming_days} AND plhs.history_start_date + 365 >= sysdate - #{overdue_days}) 
										OR (uab_next_test_date IS NULL AND plhs.history_start_date + 365 < sysdate + #{upcoming_days} AND plhs.history_start_date + 365 >= sysdate - #{overdue_days})") }


	search_methods :active, :pop_active_dm, :pop_active_ckd, :pop_active_dm_or_ckd, :pop_active_or_inactive_dm, :pop_active_and_inactive_ckd, :pop_not_invisible_dm_and_ckd, :active_only, :with_client


	self.table_name = "patient"
	self.primary_key = "patient_id"
	alias_attribute "date_of_birth", "dob"

	def self.find_patients(letter, options = {})
		paginate :per_page => options[:per_page], :page => options[:page],
						 :order => 'last_name, first_name, middle_name',
						 :conditions => ["last_name LIKE ?", letter+"%"]
	end

  def self.find_patients_without_pagination(letter)
    where("last_name LIKE ?", letter+"%")
  end

  # should be good
	def ckd_reporting_status
	  if self.patient_state.present?
	    if self.patient_state.patient_coverage_status_id == 1 or self.patient_state.patient_coverage_status_id == 2
  	    if self.patient_state.patient_particip_status_id == 1
  	      "Y"
        else
          "N"
        end
      else
        "N"
      end
    else
      "N"
    end
	end

	def dm_reporting_status
	  if patient_status.patient_status_id == 1
	    "Y"
    else
      "N"
    end
	end

	def assign_account
		account
	end

	def assign_account=(id)
		if self.account.nil?
			patient_account = PatientAccount.new(:patient_id => self.id, :account_id => id, :patient_account_status => 1)
			patient_account.save!
		else
			self.account = Account.find(id)
		end
	end

	def pcp
		contact
	end

	def pcp=(id)
		self.contact = Contact.find(id)
	end

  def assign_pcp_change_comment
  end

  def assign_pcp_change_comment=(string)
    status = self.primary_prvdr_change_histories.most_recent.first
    # patient_controller code handles the recognition that a pcp change has been made or not
    # and this method is not called unless there's a change, so we don't need to test this
    # status to see if it is the immediate status in question, like we do for other
    # status changes below.
    status.update_attribute(:reason_for_change, string)
  end

  def assign_status
		status_lookup
	end

	def assign_status=(id)
		self.status_lookup = PatientStatusLookup.find(id)
	end

	def assign_status_comment
	end

	def assign_status_comment=(string)
		status = self.patient_status_change_histories.most_recent.first
    # a trigger adds the history row only when the attribute has really been changed
    # don't add the comment otherwise, because it would go on an old row and be inaccurate
    # The six hour adjustment is 5 hours due to Time.now being GMT and 1 hour because
    # the SYSDATE set by the trigger SQL as the status.date_time is one hour earlier
    # than now, for some reason.  5 seconds is just to give some cushion for processing
    # between the patient attribute change trigger and the reason for change insertion
    # Really this only takes a second or two.
    if status.date_time >= ((Time.now - 6.hours) - 5.seconds)
		  status.update_attribute(:reason_for_change, string)
    end
	end

  def assign_dm_updater_user_id=(id)
    status = self.patient_status_change_histories.most_recent.first
    # See comment in assign_status_comment=
    if status.date_time >= ((Time.now - 6.hours) - 5.seconds)
      status.update_attribute(:updater_user_id, id)
    end
  end

  def status_comment
    self.patient_status_change_histories.most_recent.first.reason_for_change
  end

  def assign_ckd_particip_status
		patient_particip_status_lookup
	end

	def assign_ckd_particip_status=(id)
		self.patient_particip_status_lookup = PatientParticipStatusLookup.find(id)
	end

	def assign_ckd_particip_status_comment
	end

	def assign_ckd_particip_status_comment=(string)
		status = self.patient_state_change_histories.status_type("PARTICIP").most_recent.first
    # See comment in assign_status_comment=
    if status.date_time >= ((Time.now - 6.hours) - 5.seconds)
		  status.update_attribute(:reason_for_change, string)
    end
	end

  def ckd_particip_status_comment
    self.patient_state_change_histories.status_type("PARTICIP").most_recent.first.reason_for_change
  end

  def assign_ckd_particip_updater_user_id=(id)
    assign_ckd_updater_user_id(id, 'PARTICIP')
  end

  def assign_ckd_coverage_status
    patient_coverage_status_lookup
  end

  def assign_ckd_coverage_status=(id)
    self.patient_coverage_status_lookup = PatientCoverageStatusLookup.find(id)
  end

  def assign_ckd_coverage_status_comment
  end

  def assign_ckd_coverage_status_comment=(string)
    status = self.patient_state_change_histories.status_type("COVERAGE").most_recent.first
    # See comment in assign_status_comment=
    if status.date_time >= ((Time.now - 6.hours) - 5.seconds)
      status.update_attribute(:reason_for_change, string)
    end
  end

  def assign_ckd_coverage_updater_user_id=(id)
    assign_ckd_updater_user_id(id, 'COVERAGE')
  end

  def assign_ckd_updater_user_id(id, status_type)
    status = self.patient_state_change_histories.status_type(status_type).most_recent.first
    # See comment in assign_status_comment=
    if status.date_time >= ((Time.now - 6.hours) - 5.seconds)
      status.update_attribute(:updater_user_id, id)
    end
  end

  def ckd_coverage_status_comment
    self.patient_state_change_histories.status_type("COVERAGE").most_recent.first.reason_for_change
  end

  #string formatted version of date of birth
	def str_dob
		unless self.date_of_birth.nil?
			self.date_of_birth.strftime('%m-%d-%Y')
		end
	end

	#string formatted version of date of death
	def str_dod
		unless self.date_of_death.nil?
			self.date_of_death.strftime("%v")
		end
	end

	def name
		self.last_name + ", " + self.first_name
	end

	def most_recent_test(test)
		self.test_results.includes(:details).joins(:test_code).where(:service_directory => {:test_code => test}).order('result_date DESC').first
	end

	def second_most_recent_test(test)
		self.test_results.includes(:details).joins(:test_code).where(:service_directory => {:test_code => test}).order('result_date DESC').second
	end

	def flowsheet
		self.reports.search(:report_file_name_contains => 'FlowSheet.pdf').order("report_create_time DESC").first
	end

  #TODO: This is only dm active.  Replace or fix.
	def active?
		self.patient_status.patient_status_id == 1.0
	end

	def patient_reminders
		self.reports.patient_reminders.order("report_create_time DESC NULLS LAST")
	end

	def provider_reminders
		self.reports.provider_reminders.order("report_create_time DESC NULLS LAST")
	end

	def flowsheets
		self.reports.flowsheets.order("report_create_time DESC NULLS LAST")
	end

	def alerts
		self.reports.patient_alerts.order("report_create_time DESC NULLS LAST")
	end

	def self.eligible
		Patient.search(:status_lookup_patient_status_equals => 'ELIGIBLE PER PCP').where("patient.primary_provider not in (4434, 4447)")
	end

	def self.eligible_ckd
		Patient.search(:patient_particip_status_lookup_patient_particip_status_equals => 'Eligible per PCP').where("patient.primary_provider not in (4434, 4447)")
	end

	def self.under_provider_review_without_providers
		Patient.includes(:patient_state, :patient_status).search(:primary_provider_is_blank => true).where('patient_state.patient_particip_status_id = 12 or patient_status.patient_status_id = 33')
	end

	def self.under_provider_review
		Patient.includes(:contact, :status_lookup).search(:status_lookup_patient_status_equals => 'UNDER PROV REVIEW').joins(:contact).order('contact.last_name, contact.first_name, patient.last_name, patient.first_name, patient.middle_name ASC')
	end

	def pending_parsed_outreach_results
		ParsedOutreachResult.where("pat_first_name = ? and pat_last_name = ? and sex = ? and dob = ? and (ckdis_validated_flag is null or validated_flag is null)", self.first_name, self.last_name, self.sex, self.dob).order('result_date DESC')
	end

	def get_results_grid(tests, max_results = nil)
		if tests.size == 1
			return self.test_results.includes(:details).search(:test_code_test_code_equals => tests.values.first).order("result_date DESC").limit(max_results)
		elsif tests.size > 1
			results_by_date = self.test_results.includes(:details, :test_code).search(:test_code_test_code_equals_any => tests.values).order("result_date DESC").group_by { |t| t.result_date.to_date }
			results_by_date.each { |date, z| results_by_date[date] = z.group_by { |y| y.test_code.name } }
			results = Hash.new
			number_of_rows = 0;
			results_by_date.each_key do |date|
				if (results_by_date[date].keys & tests.values).any?
					results[date] = results_by_date[date]
					number_of_rows += 1
				end
				# we only want up to max_result so break once you have them
				if max_results.present?
					break if number_of_rows >= max_results
				end
			end
			return results
		else
			return nil
		end
	end

	def get_clinical_support_text(function_name, *args)
		begin
			method(function_name).call(*args)
		rescue
			""
		end
	end

	def a1c_support_text
		most_recent_a1c = self.most_recent_test('A1C')
		if most_recent_a1c.present?
			a1c_result_range = most_recent_a1c.result_range
		end
		a1c_result_range ||= 'MISSING'
		DbStoredProcedure.fetch_val_from_sp "select get_a1c_text('#{a1c_result_range}','#{self.overdue_dm.overdue_a1c_yn}') from dual"
	end

	def acr_support_text
		most_recent_acr = self.most_recent_test('UAB')
		second_most_recent_acr = self.second_most_recent_test('UAB')
		if most_recent_acr.present?
			most_recent_acr_result_range = most_recent_acr.result_range
		end
		if second_most_recent_acr.present?
			second_most_recent_acr_result_range = second_most_recent_acr.result_range
		end
		most_recent_acr_result_range ||= 'MISSING'
		second_most_recent_acr_result_range ||= 'MISSING'
		DbStoredProcedure.fetch_val_from_sp "select get_uab_text('#{second_most_recent_acr_result_range}','#{most_recent_acr_result_range}','#{self.overdue_dm.overdue_uab_yn}') from dual"
	end

	def crea_support_text
		most_recent_crea = self.most_recent_test('CREA')
		second_most_recent_crea = self.second_most_recent_test('CREA')
		if most_recent_crea.present?
			most_recent_crea_result_range = most_recent_crea.result_range
		end
		if second_most_recent_crea.present?
			second_most_recent_crea_result_range = second_most_recent_crea.result_range
		end
		most_recent_crea_result_range ||= 'MISSING'
		second_most_recent_crea_result_range ||= 'MISSING'
		DbStoredProcedure.fetch_val_from_sp "select get_crea_text('#{second_most_recent_crea_result_range}','#{most_recent_crea_result_range}','#{self.overdue_dm.overdue_crea_yn}') from dual"

	end

	def lipids_support_text
		most_recent_ldl = self.most_recent_test('MLDL')
		most_recent_trig = self.most_recent_test('TRIG')
		if most_recent_ldl.present?
			ldl_result_range = most_recent_ldl.result_range
		end
		if most_recent_trig.present?
			trig_result_range = most_recent_trig.result_range
		end
		trig_result_range ||= 'MISSING'
		ldl_result_range ||= 'MISSING'
		lipids_text = DbStoredProcedure.fetch_val_from_sp "select get_lipid_text('#{trig_result_range}','#{ldl_result_range}','#{self.overdue_dm.overdue_ldl_yn}') from dual"
	end

	def ckd_support_text(section_name)
		disease_stage = self.disease_stage_lookup.disease_stage
		row = CkdSectionText.where(:section_name => section_name, :disease_stage => disease_stage).limit(1)
		row.first.text
	end

  #TODO this method will be obsolete once I move new worklist code to CM's and Providers
	def overdue?(test)
		if self.overdue.present?
			self.overdue.overdue?(test)
		else
			false
		end
	end

  def overdue_since_date?(test, date)
    if self.worklist_view.present?
      self.worklist_view.overdue_since_date?(test, date)
    else
      false
    end
  end

  #TODO this method will be obsolete once I move new worklist code to CM's and Providers
  def upcoming?(test, days)
		if self.overdue.present?
			self.overdue.upcoming?(test, days)
		else
			false
		end
	end

  def upcoming_by_date?(test, date)
    if self.worklist_view.present?
      self.worklist_view.upcoming_by_date?(test, date)
    else
      false
    end
  end

  def <=>(other)
		[self.last_name, self.first_name] <=> [other.last_name, other.first_name]
	end

	def letter_sent?
		letter_sent_for_dm = self.patient_status_change_histories.where("patient_status_change_history.patient_status_id = 8").count > 0
		letter_sent_for_ckd = self.patient_state_change_histories.where("patient_state_change_history.status_type = 'PARTICIP' and patient_state_change_history.status_id = 13").count > 0
		(letter_sent_for_dm or letter_sent_for_ckd)
	end

	def active_dm?
		if self.status_lookup.present?
			(self.status_lookup.patient_status_id == 1)
		else
			false
		end
	end

	def active_ckd?
		if self.patient_particip_status_lookup.present?
			(self.patient_particip_status_lookup.patient_particip_status_id == 1)
		else
			false
		end
	end

	def refused?
		if self.patient_particip_status_lookup.present? and self.patient_particip_status_lookup.patient_particip_status_id == 11
			true
		elsif self.status_lookup.present? and self.status_lookup.patient_status_id == 7
			true
		else
			false
		end
	end

	def last_result(test)
		self.test_results.includes(:details).joins(:test_code).where(:service_directory => {:test_code => test}).order('result_date DESC').first
	end

  def last_result_before(test, date)
    self.test_results.includes(:details).joins(:test_code).where(:service_directory => {:test_code => test}).where("result_date <= ?", date).order('result_date DESC').first
  end

  def last_result_above_value(test, val)
    self.test_results.joins(:details).joins(:test_code).where(:service_directory => {:test_code => test}).where("test_result_detail_numeric >= ?", val).order('result_date DESC').first
  end

  def prov_response_after(date)
		self.patient_status_change_histories.where("patient_status_id in (21, 22, 23, 24, 26, 29) and date_time > ?", date).order("date_time ASC").first
	end

	def self.active_for_display(session)
		if session[:account_diseases].include? 'DM' and session[:account_diseases].include? 'CKD'
			self.all_active_dm_ckd.includes(:status_lookup, :report_visibility).order("patient.last_name, patient.first_name, patient.dob")
		elsif session[:account_diseases].include? 'DM'
			self.all_active_dm.includes(:status_lookup).order("patient.last_name, patient.first_name, patient.dob")
		elsif session[:account_diseases].include? 'CKD'
			self.all_active_ckd.includes(:report_visibility).order("patient.last_name, patient.first_name, patient.dob")
		end
	end

	def self.search_form(session, search_params)
		search_params[:last_name_starts_with] = search_params[:last_name_starts_with].upcase
		search_params[:first_name_starts_with] = search_params[:first_name_starts_with].upcase
		search_params.reject { |k, v| v.blank? }

    # admin should see all patients, no exceptions, so these filters are being removed and
    # replaced by the simple self.order command below. Issue 325, 12/23/2013, Tom P.
		#if session[:account_diseases].include? 'DM' and session[:account_diseases].include? 'CKD'
		#	self.pop_not_invisible_dm_and_ckd.order(:last_name, :first_name, :middle_name, :dob).includes(:status_lookup, :report_visibility).search(search_params)
		#elsif session[:account_diseases].include? 'DM'
		#	self.pop_active_or_inactive_dm.order(:last_name, :first_name, :middle_name, :dob).includes(:status_lookup, :report_visibility).search(search_params)
		#elsif session[:account_diseases].include? 'CKD'
		#	self.pop_active_or_inactive_ckd.order(:last_name, :first_name, :middle_name, :dob).includes(:status_lookup, :report_visibility).search(search_params)
    #end

    self.order(:last_name, :first_name, :middle_name, :dob).includes(:status_lookup, :report_visibility).search(search_params)

  end

  def str_active_dm

    if self.active_dm?
      'YES'
    else
      'NO'
    end

  end

  def str_active_ckd

    if self.active_ckd?
      self.disease_stage_lookup.disease_stage
    else
      'NO'
    end

  end


  def overdue_text(test_label, test_name, tests, overdue_target_date, upcoming_target_date, dm_tests, ckd_tests)

    @value = "-"

    if tests.include?(test_name)
      if (dm_tests.include?(test_name)) or
         (ckd_tests.include?(test_name))

        if self.overdue_since_date?(test_name, overdue_target_date)
          @value = self.worklist_view.text_for_xls(test_name, overdue_target_date, test_label)
        elsif self.upcoming_by_date?(test_name, upcoming_target_date)
          @value = self.worklist_view.text_for_xls(test_name, upcoming_target_date, test_label)
        end
      end
    end

    @value
  end

  # returns a boolean, true if the case manager has accepted the patient, false otherwise
  def accepted_by_case_manager case_manager

    cmp = self.case_manager_patients.find_by_case_manager_id case_manager.contact_id
    cmp.accepted == 'Y'

  end

  def has_dm_status_to_review?
    self.patient_status.present? and
      (self.patient_status.patient_status_id == 33 or
       self.patient_status.patient_status_id == 35 or
       self.patient_status.patient_status_id == 100)

  end

  def has_ckd_status_to_review?
    self.patient_state.present? and
      (self.patient_state.patient_particip_status_id == 6 or
       self.patient_state.patient_particip_status_id == 12 or
       self.patient_state.patient_particip_status_id == 98)

  end

  def self.all_active_a1c(range)
    pats = self.all_active_dm_ckd.reject{|x| x.worklist_view.nil?}.reject{|x| x.dm_pop_report_last_results.a1c_result.nil?}.reject{|x| x.dm_pop_report_last_results.a1c_result == '--'}
    result_hash = {}
    new_pats = []

    pats.each do |pat|
      result = pat.dm_pop_report_last_results.a1c_result
      num_result = get_num_result result

      if ((range == 'gt8' and num_result > 8) or
          (range == 'eq7to8' and num_result >= 7 and num_result <= 8) or
          (range == 'lt7' and num_result < 7))
        new_pats << pat
        result_hash[result] = num_result
      end

    end

    # The minus puts it in descending order
    new_pats.sort_by{ |pat| - result_hash[pat.dm_pop_report_last_results.a1c_result] }

  end

  def self.all_active_mldl(range)
    pats = self.all_active_dm_ckd.reject{|x| x.worklist_view.nil?}.reject{|x| x.dm_pop_report_last_results.ldl_result.nil?}.reject{|x| x.dm_pop_report_last_results.ldl_result == '--'}
    result_hash = {}
    new_pats = []

    pats.each do |pat|
      result = pat.dm_pop_report_last_results.ldl_result
      num_result = get_num_result result

      if ((range == 'gteq130' and num_result >= 130) or
          (range == 'eq100to129' and num_result >= 100 and num_result <= 129) or
          (range == 'lt100' and num_result < 100))
        new_pats << pat
        result_hash[result] = num_result
      end

    end

    new_pats.sort_by{ |pat| - result_hash[pat.dm_pop_report_last_results.ldl_result] }

  end

  def self.all_active_uab(range)
    pats = self.all_active_dm_ckd.reject{|x| x.worklist_view.nil?}.reject{|x| x.dm_pop_report_last_results.acr_result.nil?}.reject{|x| x.dm_pop_report_last_results.acr_result == '--'}
    result_hash = {}
    new_pats = []

    pats.each do |pat|
      result = pat.dm_pop_report_last_results.acr_result
      num_result = get_num_result result

      if ((range == 'gteq300' and num_result >= 300) or
          (range == 'eq30to299' and num_result >= 30 and num_result <= 299) or
          (range == 'lt30' and num_result < 30))
        new_pats << pat
        result_hash[result] = num_result
      end

    end

    new_pats.sort_by{ |pat| - result_hash[pat.dm_pop_report_last_results.acr_result] }

  end

  # get a number for sorting purposes, when the real value is like "<18.0" or ">5.9"
  # Push the numeric value negligibly in the < or > direction so that it sorts just before or after the real value.
  def self.get_num_result result
    if result.start_with? '<'
      num_result = result[1..-1].to_f - 0.000001
    elsif result.start_with? '>'
      num_result = result[1..-1].to_f + 0.000001
    else
      num_result = result.to_f
    end

  end

  def reports_display_count

    count = 0

    if self.account.suppress_by_account.nil?
      count += self.reports.patient_reminders.count
      count += self.reports.provider_reminders.count
      count += self.reports.patient_alerts.count
      count += self.reports.flowsheets.count
    else
      unless self.account.suppress_by_account.suppress_pat_reminder == 'Y'
        count += self.reports.patient_reminders.count
      end
      unless self.account.suppress_by_account.suppress_prov_reminder == 'Y'
        count += self.reports.provider_reminders.count
      end
      unless self.account.suppress_by_account.suppress_pat_alert == 'Y'
        count += self.reports.patient_alerts.count
      end
      unless self.account.suppress_by_account.suppress_flowsheet == 'Y'
        count += self.reports.flowsheets.count
      end
    end

    count
  end

  def display_name
    "#{self.last_name}, #{self.first_name} #{self.middle_name}"
  end

  def display_name_dob
    "#{self.last_name}, #{self.first_name} #{self.middle_name} (#{self.dob.strftime('%m-%d-%Y')})"
  end

  def full_display_name
    "#{self.last_name}, #{self.first_name} #{self.middle_name} (#{self.dob.strftime('%m-%d-%Y')}) [#{self.contact.nil? ? 'No Provider' : self.contact.name}]"
  end

  def get_active_date

    # Patients can have multiple change history entries when the status doesn't really change.  So look at them
    # in descending order.  They should start with status 1 (active).  Capture the earliest date that the patient is
    # active in consecutive history entries.
    active_date = nil

    if self.active_dm?
      history_items = self.patient_status_change_histories.date_ordered
      history_items.each do |hist|
        dm_status_id = hist.patient_status_id
        if dm_status_id != 1
          break
        end
        active_date = hist.date_time.to_date
      end
    end

    if self.active_ckd?
      ckd_date = nil
      history_items = self.patient_state_change_histories.status_type_date_ordered('PARTICIP')
      history_items.each do |hist|
        ckd_status_id = hist.status_id
        if ckd_status_id != 1
          break
        end
        ckd_date = hist.date_time.to_date
      end

      # just a sanity check on nil here.  There should always be at least one active date if the
      # patient is active
      if !ckd_date.nil? and (active_date.nil? or ckd_date < active_date)
        active_date = ckd_date
      end
    end

    if active_date.nil?
      active_date = 'Not Active'
    else
      active_date = active_date.strftime('%m-%d-%Y')
    end
    active_date

  end

  def get_dm_active_date

    # Patients can have multiple change history entries when the status doesn't really change.  So look at them
    # in descending order.  They should start with status 1 (active).  Capture the earliest date that the patient is
    # active in consecutive history entries.
    active_date = nil

    if self.active_dm?
      history_items = self.patient_status_change_histories.date_ordered
      history_items.each do |hist|
        dm_status_id = hist.patient_status_id
        if dm_status_id != 1
          break
        end
        active_date = hist.date_time.to_date
      end
    end

    active_date

  end

  def get_ckd_active_date

    # Patients can have multiple change history entries when the status doesn't really change.  So look at them
    # in descending order.  They should start with status 1 (active).  Capture the earliest date that the patient is
    # active in consecutive history entries.
    active_date = nil

    if self.active_ckd?
      history_items = self.patient_state_change_histories.status_type_date_ordered('PARTICIP')
      history_items.each do |hist|
        ckd_status_id = hist.status_id
        if ckd_status_id != 1
          break
        end
        active_date = hist.date_time.to_date
      end

    end

    active_date

  end

  def contact_name

    if self.contact.nil?
      '<None>'
    else
      self.contact.name
    end

  end

  def get_alternative_id description

    alt_pat_id = nil
    # get the latest if there are multiple
    self.alternative_patient_ids.order("date_added DESC").each do |alt_pat|
      if alt_pat.alt_id_description == description
        alt_pat_id = alt_pat
        break
      end
    end
    alt_pat_id
  end

  def get_alternative_ids description

    alt_pat_ids = []
    # get the latest if there are multiple
    self.alternative_patient_ids.order("patient_alternative_id DESC").each do |alt_pat|
      if alt_pat.alt_id_description == description
        alt_pat_ids << alt_pat
      end
    end
    alt_pat_ids
	end

  def self.with_provider_status_mismatch
		joins(:contact, :patient_state).joins("left join provider_status_by_disease psbd on psbd.provider_id = contact.contact_id").where("psbd.disease_id = 2 AND psbd.provider_status <> patient_state.patient_pcp_status_id")
	end

  def self.empire_non_study_low_ckd
		joins(:patient_account, :patient_state).where("(patient_account.account_id = 1022 OR patient_account.account_id = 1024) AND patient_state.disease_stage_id IN (6,9,14,15,16) and patient_state.patient_particip_status_id IN (1,5,12,13,14) AND patient.patient_id NOT IN (SELECT patient_id FROM epmg_study_roster_current WHERE group_name = 'STUDY') AND patient.patient_id NOT IN (SELECT patient_id FROM patient_status WHERE patient_status_id = 1)")
	end

  def self.dm_deactivated letter
		# Patients may appear twice in this collection if they've been activated more than once.
		# That's ok, the hash will be populated twice, but ultimately with only one pat id value.
		patients = joins(:patient_status, :patient_status_change_histories).where("patient_status.patient_status_id <> 1 AND patient_status_change_history.patient_status_id = 1 AND patient_status_change_history.latest_status = 'N'").uniq
		patients = patients.find_patients_without_pagination(letter).order('last_name, first_name, middle_name, dob ASC')
		# order by most recently active
		patient_hash = {}
		patients.each do |pat|
			hists = pat.patient_status_change_histories
			latest_date = 50.years.ago
			hists.each do |hist|
				if hist.patient_status_id == 1 and hist.latest_status == 'N' and hist.date_time_status_end > latest_date
					patient_hash[pat] = hist.date_time_status_end
				end
				latest_date = hist.date_time_status_end
			end
		end

		patient_hash
	end

	def self.ckd_deactivated letter
		# Patients may appear twice in this collection if they've been activated more than once.
		# That's ok, the hash will be populated twice, but ultimately with only one pat id value.
		patients = joins(:patient_state, :patient_state_change_histories).where("patient_state.patient_particip_status_id <> 1 AND patient_state_change_history.status_type = 'PARTICIP' AND patient_state_change_history.status_id = 1 AND patient_state_change_history.latest_status = 'N'").uniq
		patients = patients.find_patients_without_pagination(letter).order('last_name, first_name, middle_name, dob ASC')
		# order by most recently active
		patient_hash = {}
		patients.each do |pat|
			hists = pat.patient_state_change_histories
			latest_date = 50.years.ago
			hists.each do |hist|
				if hist.status_type == 'PARTICIP' and hist.status_id == 1 and hist.latest_status == 'N' and hist.date_time_status_end > latest_date
					patient_hash[pat] = hist.date_time_status_end
				end
				latest_date = hist.date_time_status_end
			end
		end

		patient_hash
	end

  def self.dm_under_prov_review account_id
		pat_hash = {}
		if account_id == '1022'
			# For Empire, must include any patients in Study Control group as well
			pats = joins(:patient_account, :contact, :patient_status).where("patient_status.patient_status_id = 6 AND (patient_account.account_id = ? OR patient_account.account_id = 1024)", account_id).includes(:patient_status_change_histories).order("patient.last_name, patient.first_name, patient.dob ASC")
		else
			pats = joins(:patient_account, :contact, :patient_status).where("patient_status.patient_status_id = 6 AND patient_account.account_id = ?", account_id).includes(:patient_status_change_histories).order("patient.last_name, patient.first_name, patient.dob ASC")
		end

		pats.each do |pat|
			if pat_hash[pat.contact].nil?
				pat_hash[pat.contact] = []
			end
			pat_hash[pat.contact] << pat
		end
		pat_hash = Hash[pat_hash.sort_by {|k, v| k.last_name} ]
	end

	def self.ckd_under_prov_review account_id
		pat_hash = {}
		if account_id == '1022'
			# For Empire, must include any patients in Study Control group as well
			pats = joins(:patient_account, :contact, :patient_state).where("patient_state.patient_particip_status_id = 14 AND (patient_account.account_id = ? OR patient_account.account_id = 1024)", account_id).order("patient.last_name, patient.first_name, patient.dob ASC")
		else
			pats = joins(:patient_account, :contact, :patient_state).where("patient_state.patient_particip_status_id = 14 AND patient_account.account_id = ?", account_id).order("patient.last_name, patient.first_name, patient.dob ASC")
		end

		pats.each do |pat|
			if pat_hash[pat.contact].nil?
				pat_hash[pat.contact] = []
			end
			pat_hash[pat.contact] << pat
		end
		pat_hash = Hash[pat_hash.sort_by {|k, v| k.last_name} ]
	end

end
class CommentsController < ApplicationController
	before_filter :authenticate_user!
	before_filter :load_commentable, :only => :create

	load_and_authorize_resource :patient, :as => :commentable
	authorize_resource :comment, :belongs_to => :commentable, :polymorphic => true

	def create
		respond_to do |format|
			if @comment.save
        flash[:new_comment_errors] = nil
				format.html { redirect_to :back }
				format.js
			else
        flash[:new_comment_errors] = @comment.errors.full_messages
				format.html { redirect_to :back }
				format.js
			end
		end
	end

	# GET /comments/1/edit
	def edit
		@comment = Comment.find(obfuscate_decrypt(params[:id], session))
    @option_ids = @comment.comment_options.pluck('option_id')
    @comment_option_lookups = CommentOptionLookup.order
    set_dated_options @comment.comment_options
    @this_comment = @comment.comment
 		respond_to do |format|
			format.js
      format.html
		end
	end

	# PUT /comments/1
	# PUT /comments/1.json
	def update
		@comment = Comment.find(obfuscate_decrypt(params[:id], session))
		@commentable = @comment.commentable

    bOK = false
    if params[:commit] == "Cancel"
      # if user clicks "Cancel", reload the page with original data
      bOK = true
    else
      # make database updates before reloading the page
      bOK = update_options
      if bOK
        bOK = @comment.update_attributes(params[:comment])
      end
    end

		respond_to do |format|
			if bOK
        flash[:edit_comment_errors] = nil
        @comment = Comment.find(obfuscate_decrypt(params[:id], session))
        @option_ids = @comment.comment_options.pluck('option_id')
        @comment_option_lookups = CommentOptionLookup.order
        @this_comment = @comment.comment
        format.html { redirect_to flowsheet_user_patient_path(obfuscate_encrypt(@comment.commentable.patient_id, session)), notice: 'Comment was successfully updated.' }
				format.json { head :ok }
				format.js
      else
        flash[:edit_comment_errors] = @comment.errors.full_messages
				format.html { redirect_to flowsheet_user_patient_path(obfuscate_encrypt(@comment.commentable.patient_id, session)), notice: "There were problems updating your comment. Please try again:" }
				format.json { render json: @comment.errors, status: :unprocessable_entity }
				format.js { render action: 'edit' }
			end
		end
	end

  # DELETE /comments/1
	# DELETE /comments/1.json
	def destroy
    @comment = Comment.find(obfuscate_decrypt(params[:id], session))
		@commentable = @comment.commentable
    @comment.comment_options.each do |co|
      co.destroy
    end
		@comment.destroy

		respond_to do |format|
      @comment_option_lookups = CommentOptionLookup.order
			format.html { redirect_to :back }
			format.json { head :ok }
			format.js
		end
	end

  protected

	def load_commentable
		@commentable = params[:commentable_type].camelize.constantize.find(params[:commentable_id])
		@comment = @commentable.comments.build(params[:comment])
    if params['options']
      params['options'].each do |opt|
        comment_option = @comment.comment_options.build
        comment_option.option_id = opt.to_i
        add_dated_option_note comment_option, opt.to_i, false
      end
    end
		@comment.user = current_user
    @comment_option_lookups = CommentOptionLookup.order

  end

  private

  def update_options
    bOK = true
    existing_ids = @comment.comment_options.pluck('option_id')
    new_ids = params['options']
    if new_ids
      new_ids.each do |new_id|
        new_id_int = new_id.to_i
        option_str = CommentOptionLookup.find(new_id.to_i).comment_option
        if existing_ids.include? new_id_int
          existing_ids.delete new_id_int
          existing_co = CommentOption.find(@comment.id, new_id_int)
          bUpdated = add_dated_option_note existing_co, new_id_int, true
          if bUpdated
            existing_co.save!
          end
        else
          if bOK
            new_co = @comment.comment_options.build
            new_co.option_id = new_id_int
            add_dated_option_note new_co, new_id_int, true
            bOK = new_co.save!
          end
        end
      end
    end

    existing_ids.each do |existing|
      if bOK
        co = CommentOption.find(@comment.id, existing)
        bOK = co.destroy
      end
    end

    bOK

  end

  def set_dated_options comment_opts

    comment_opts.each do |cmmt_opt|
      opt_text = cmmt_opt.comment_option_lookup.comment_option
      if opt_text == 'Member terminated'
        @terminated_date = cmmt_opt.notes.nil? ? nil : Date.strptime(cmmt_opt.notes, '%m-%d-%Y').strftime('%m-%d-%Y')
      elsif opt_text == 'Member deceased'
        @deceased_date = cmmt_opt.notes.nil? ? nil : Date.strptime(cmmt_opt.notes, '%m-%d-%Y').strftime('%m-%d-%Y')
      end
    end
  end

  def add_dated_option_note comment_option_obj, option_id, is_edit

    bUpdated = false
    terminated_date_sym = :member_terminated_date
    deceased_date_sym = :member_deceased_date
    if is_edit
      terminated_date_sym = :member_terminated_date_edit
      deceased_date_sym = :member_deceased_date_edit
    end

    option_text = CommentOptionLookup.find(option_id).comment_option
    if option_text == 'Member terminated'
      comment_option_obj.notes = params[terminated_date_sym]
      bUpdated = true
    elsif option_text == 'Member deceased'
      comment_option_obj.notes = params[deceased_date_sym]
      bUpdated = true
    end

    bUpdated
  end

end
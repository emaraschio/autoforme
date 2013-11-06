module AutoForme
  # Represents an action on a model in response to a web request.
  class Action
    attr_reader :model
    attr_reader :request
    attr_reader :type
    attr_reader :normalized_type

    NORMALIZED_ACTION_MAP = {'create'=>'new', 'update'=>'edit', 'destroy'=>'delete'}
    def initialize(model, request)
      @model = model
      @request = request
      @type = request.action_type
      @normalized_type = NORMALIZED_ACTION_MAP.fetch(@type, @type)
    end

    def supported?
      return false unless idempotent? || request.post?
      return false unless model.supported_action?(normalized_type)
      true
    end

    def h(s)
      Rack::Utils.escape_html(s.to_s)
    end

    def idempotent?
      type == normalized_type
    end

    def model_params
      request.params[model.params_name]
    end

    def url_for(page)
      "#{request.path}/#{request.model}/#{page}"
    end

    def redirect(page)
      request.redirect(url_for(page))
      nil
    end


    def handle
      send("handle_#{type}")
    end

    def tabs
      content = '<ul class="nav nav-tabs">'
      %w'browse new show edit delete search'.each do |action_type|
        if model.supported_action?(action_type)
          content << "<li class=\"#{'active' if type == action_type}\"><a href=\"#{url_for(action_type)}\">#{action_type == 'browse' ? request.model : action_type.capitalize}</a></li>"
        end
      end
      content << '</ul>'
    end

    def page
      html = tabs
      html << yield.to_s
      html
    end

    def form_opts
      opts = {}
      hidden_tags = opts[:hidden_tags] = []
      if csrf = request.csrf_token_hash
        hidden_tags << lambda{|tag| csrf if tag.attr[:method].to_s.upcase == 'POST'}
      end
      opts
    end

    def new_page(obj, opts={})
      page do
        Forme.form(obj, {:action=>url_for("create")}, form_opts) do |f|
          model.columns_for(:new).each do |column|
            f.input(column, model.column_options_for(:new, column))
          end
          f.button('Create')
        end
      end
    end
    def handle_new
      new_page(model.new)
    end
    def handle_create
      obj = model.new
      model.set_fields(obj, :new, model_params)
      model.hook(:before_create, self, obj)
      if model.save(obj)
        model.hook(:after_create, self, obj)
        request.set_flash_notice("Created #{request.model}")
        redirect("new")
      else
        request.set_flash_now_error("Error Creating #{request.model}")
        new_page(obj)
      end
    end

    def list_page(type, opts={})
      page do
        form_attributes = opts[:form] || {:action=>url_for(type.to_s)}
        Forme.form(form_attributes, form_opts) do |f|
          f.input(:select, :options=>model.select_options(self), :name=>'id', :id=>'id')
          f.button(type.to_s.capitalize)
        end
      end
    end

    def show_page(obj)
      page do
        Forme.form(obj, {}, :formatter=>:readonly) do |f|
          model.columns_for(:show).each do |column|
            f.input(column, model.column_options_for(:show, column))
          end
        end
      end
    end
    def handle_show
      if request.id
        show_page(model.with_pk(self, request.id))
      else
        list_page(:show)
      end
    end

    def edit_page(obj)
      page do
        Forme.form(obj, {:action=>url_for("update/#{obj.id}")}, form_opts) do |f|
          model.columns_for(:edit).each do |column|
            f.input(column, model.column_options_for(:edit, column))
          end
          f.button('Update')
        end
      end
    end
    def handle_edit
      if request.id
        edit_page(model.with_pk(self, request.id))
      else
        list_page(:edit)
      end
    end
    def handle_update
      obj = model.with_pk(self, request.id)
      model.set_fields(obj, :edit, model_params)
      model.hook(:before_update, self, obj)
      if model.save(obj)
        model.hook(:after_update, self, obj)
        request.set_flash_notice("Updated #{request.model}")
        redirect("edit/#{model.primary_key_value(obj)}")
      else
        request.set_flash_now_error("Error Updating #{request.model}")
        edit_page(obj)
      end
    end

    def handle_delete
      list_page(:delete, :form=>{:action=>url_for('destroy'), :method=>:post})
    end
    def handle_destroy
      obj = model.with_pk(self, request.id)
      model.hook(:before_destroy, self, obj)
      model.destroy(obj)
      model.hook(:after_destroy, self, obj)
      request.set_flash_notice("Deleted #{request.model}")
      redirect("delete")
    end

    def table_pager(type, next_page)
      html = '<ul class="pager">'
      page = request.id.to_i
      if page > 1
        html << "<li><a href=\"#{url_for("#{type}/#{page-1}?#{h request.query_string}")}\">Previous</a></li>"
      else
        html << '<li class="disabled"><a href="#">Previous</a></li>'
      end
      if next_page
        page = 1 if page < 1
        html << "<li><a href=\"#{url_for("#{type}/#{page+1}?#{h request.query_string}")}\">Next</a></li>"
      else
        html << '<li class="disabled"><a href="#">Next</a></li>'
      end
      html << "</ul>"
    end
    def table_page(type, next_page, objs)
      page do
        ModelTable.new(self, type, objs).to_s << table_pager(type, next_page)
      end
    end
    def handle_browse
      table_page(:browse, *model.browse(self))
    end

    def handle_search
      if request.id
        table_page(:search, *model.search_results(self))
      else
        page do
          Forme.form(model.new, {:action=>url_for("search/1"), :method=>:get}, form_opts) do |f|
            model.columns_for(:search_form).each do |column|
              f.input(column, model.column_options_for(:search_form, column).merge(:name=>column, :id=>column))
            end
            f.button('Search')
          end
        end
      end
    end
  end
end

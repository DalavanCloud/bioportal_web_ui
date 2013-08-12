# Methods added to this helper will be available to all templates in the application.

require 'uri'
require 'cgi'
require 'digest/sha1'
require 'pry' # used in a rescue

module ApplicationHelper

  def bp_config_json
    {
      org: $ORG,
      org_url: $ORG_URL,
      site: $SITE,
      org_site: $ORG_SITE,
      ui_url: $UI_URL,
      apikey: LinkedData::Client.settings.apikey,
      rest_url: LinkedData::Client.settings.rest_url
    }.to_json
  end

  def isOwner?(id)
    unless session[:user].nil?
      if session[:user].admin?
        return true
      elsif session[:user].id.eql?(id)
        return true
      else
        return false
      end
    end
  end

  def using_captcha?
    !ENV['USE_RECAPTCHA'].nil? && ENV['USE_RECAPTCHA'] == 'true'
  end

  def encode_param(string)
    return URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def escape(string)
    CGI.escape(string)
  end

  def clean(string)
    string = string.gsub("\"",'\'')
    return string.gsub("\n",'')
  end

  def clean_id(string)
    new_string = string.gsub(":","").gsub("-","_").gsub(".","_")
    return new_string
  end

  def to_param(string)
     "#{encode_param(string.gsub(" ","_"))}"
  end

  # Notes-related helpers that could be useful elsewhere

  def convert_java_time(time_in_millis)
    time_in_millis.to_i / 1000
  end

  def time_from_java(java_time)
    Time.at(convert_java_time(java_time.to_i))
  end

  def time_formatted_from_java(java_time)
    time_from_java(java_time).strftime("%m/%d/%Y")
  end

  def get_username(user_id)
    user = LinkedData::Client::Models::User.find(user_id)
    username = user.nil? ? user_id : user.username
    username
  end

  # end Notes-related helpers

  def remove_owl_notation(string)
    # TODO_REV: No OWL notation, but should we modify the IRI?
    return string

    unless string.nil?
      strings = string.split(":")
      if strings.size<2
        #return string.titleize
        return string
      else
        #return strings[1].titleize
        return strings[1]
      end
    end
  end

  def draw_note_tree(notes,key)
    output = ""
    draw_note_tree_leaves(notes,0,output,key)
    return output
  end

  def draw_note_tree_leaves(notes,level,output,key)
    for note in notes
      name="Anonymous"
      unless note.user.nil?
        name=note.user.username
      end
      headertext=""
      notetext=""
      if note.note_type.eql?(5)
        headertext<< "<div class=\"header\" onclick=\"toggleHide('note_body#{note.id}','');compare('#{note.id}')\">"
        notetext << " <input type=\"hidden\" id=\"note_value#{note.id}\" value=\"#{note.comment}\">
                  <span class=\"message\" id=\"note_text#{note.id}\">#{note.comment}</span>"
      else
        headertext<< "<div onclick=\"toggleHide('note_body#{note.id}','')\">"

        notetext<< "<span class=\"message\" id=\"note_text#{note.id}\">#{simple_format(note.comment)}</span>"
      end


      output << "
        <div style=\"clear:both;margin-left:#{level*20}px;\">
        <div  style=\"float:left;width:100%\">
          #{headertext}
              <div>
                <span class=\"sender\" style=\"float:right\">#{name} at #{note.created_at.strftime('%m/%d/%y %H:%M')}</span>
                <div class=\"header\"><span class=\"notetype\">#{note.type_label.titleize}:</span> #{note.subject}</div>
                              <div style=\"clear:both\"></div>
              </div>

          </div>

          <div name=\"hiddenNote\" id=\"note_body#{note.id}\" >
          <div class=\"messages\">
            <div>
              <div>
               #{notetext}"
      if session[:user].nil?
        output << "<div id=\"insert\"><a href=\"\/login?redirect=/visualize/#{@ontology.to_param}/?conceptid=#{@concept.id}#notes\">Reply</a></div>"
      else
        if @modal
          output << "<div id=\"insert\"><a href=\"#\"  onclick =\"document.getElementById('m_noteParent').value='#{note.id}';document.getElementById('m_note_subject#{key}').value='RE:#{note.subject}';jQuery('#modal_form').html(jQuery('#modal_comment').html());return false;\">Reply</a></div>"
        else
          output << "<div id=\"insert\"><a href=\"#TB_inline?height=400&width=600&inlineId=commentForm\" class=\"thickbox\" onclick =\"document.getElementById('noteParent').value='#{note.id}';document.getElementById('note_subject#{key}').value='RE:#{note.subject}';\">Reply</a></div>"
        end
      end
      output << "</div>
            </div>
          </div>

          </div>
        </div>
        </div>"
      if(!note.children.nil? && note.children.size>0)
        draw_note_tree_leaves(note.children,level+1,output,key)
      end
    end
  end

  def draw_tree(root, id = nil, type = "Menu")
    string = ""
    if id.nil?
      id = root.children.first.id
    end

    build_tree(root, nil, string, id)

    return string
  end

  def build_tree(node, parent, string, id)
    if parent.nil?
      draw_root = ''
    else
      draw_root = ""
    end

    unless node.children.nil? || node.children.length < 1
      for child in node.children
        icons = ""

        active_style =""
        child.id.eql?(id)
        if child.id.eql?(id)
          active_style="class='active'"
        end

        open = ""
        if child.expanded?
          open = "class='open'"
        end

        relation = child.relation_icon

        # This fake root will be present at the root of "flat" ontologies, we need to keep the id intact
        li_id = child.id.eql?("bp_fake_root") ? "bp_fake_root" : short_uuid

        # Return different result for too many children
        if child.prefLabel.eql?("*** Too many children...")
          number_of_terms = id.eql?("root") ? child.explore.ontology.explore.roots.length : node.childrenCount
          retry_link = "<a class='too_many_children_override' href='/ajax_concepts/#{child.explore.ontology.acronym}/?conceptid=#{CGI.escape(id)}&callback=children&too_many_children_override=true'>Get all terms</a>"
          string << "<div style='background: #eeeeee; padding: 5px; width: 80%;'>There are #{number_of_terms} terms at this level. Retrieving these may take several minutes. #{retry_link}</div>"
        else
          string << "<li #{open} #{draw_root} id='#{li_id}'><a id='#{CGI.escape(child.id)}' href='/ontologies/#{child.explore.ontology.acronym}/?p=terms&conceptid=#{CGI.escape(child.id)}' #{active_style}> #{relation} #{child.prefLabel} #{icons}</a>"
          if child.childrenCount && child.childrenCount > 0 && !child.expanded?
            string << "<ul class='ajax'><li id='#{li_id}'><a id='#{CGI.escape(child.id)}' href='/ajax_concepts/#{child.explore.ontology.acronym}/?conceptid=#{CGI.escape(child.id)}&callback=children&child_size=#{child.childrenCount}'>ajax_class</a></li></ul>"
          elsif child.expanded?
            string << "<ul>"
            build_tree(child,"child",string,id)
            string << "</ul>"
          end
          string << "</li>"
        end
      end
    end

    string
  end

  def loading_spinner(padding = false, include_text = true)
    loading_text = include_text ? " loading..." : ""
    if padding
      '<div style="padding: 1em;"><img src="/images/spinners/spinner_000000_16px.gif" style="vertical-align: text-bottom;">' + loading_text + '</div>'
    else
      '<img src="/images/spinners/spinner_000000_16px.gif" style="vertical-align: text-bottom;">' + loading_text
    end
  end

  # This gives a very hacky short code to use to uniquely represent a class
  # based on its parent in a tree. Used for unique ids in HTML for the tree view
  def short_uuid
    rand(36**8).to_s(36)
  end

  def help_icon(link, html_attribs = {})
    html_attribs["title"] ||= "Help"
    attribs = []
    html_attribs.each {|k,v| attribs << "#{k.to_s}='#{v}'"}
    return <<-BLOCK
          <a target="_blank" href='#{link}' class='pop_window help_link' #{attribs.join(" ")}>
            <span class="pop_window ui-icon ui-icon-help"></span>
          </a>
    BLOCK
  end

  def anonymous_user
    #
    # TODO: Fix and failures from removing 'DataAccess' call here.
    #
    #user = DataAccess.getUser($ANONYMOUS_USER)
    user ||= User.new({"id" => 0})
  end

  def init_ontology_picker(ontologies = nil, selected_ontologies = [])

    groups_map = {}
    categories_map = {}
    onts_in_group_or_category_map = {}

    @onts_for_select = []
    @onts_for_js = [];
    ontologies ||= LinkedData::Client::Models::Ontology.all

    ontologies.each do |ont|

      # TODO: ontologies parameter may be a list of ontology models (not ontology submission models):
      # ont.acronym instead of ont.ontology.acronym
      # ont.name instead of ont.ontology.name
      # ont.id instead of ont.ontology.id

      # TODO: resource index and annotator pass in 'custom_ontologies' to the ontologies parameter.

      acronym = ont.acronym || ""
      name = ont.name
      ont_uri = ont.id # ontology URI

      abbreviation = acronym.empty? ? "" : "(#{acronym})"
      @onts_for_select << [name.strip + " " + abbreviation, ont_uri]
      @onts_for_js << "\"#{name.strip} #{abbreviation}\": \"#{acronym}\""
    end

    @onts_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }

    @onts_in_group_or_category_for_js = Set.new

    groups = LinkedData::Client::Models::Group.all(include: "ontologies,acronym")
    @groups_for_select = groups_for_select
    @groups_for_js = []
    groups.each do |group|
      @onts_in_group_or_category_for_js += group.ontologies
      @groups_for_js << "\"#{group.id}\": #{group.ontologies.to_s}"
    end

    categories = LinkedData::Client::Models::Category.all(include: "ontologies,acronym")
    @categories_for_select = categories_for_select
    @categories_for_js = []
    categories.each do |cat|
      @onts_in_group_or_category_for_js += cat.ontologies
      @categories_for_js << "\"#{cat.id}\": #{cat.ontologies.to_s}"
    end

    @onts_in_group_or_category_for_js = @onts_in_group_or_category_for_js.to_a
  end

  def init_ontology_picker_single
    ontologies = LinkedData::Client::Models::Ontology.all
    @onts_for_select = []
    @onts_for_js = [];
    ontologies.each do |ont|
      acronym = ont.acronym || ""
      name = ont.name
      #ont_uri = ont.id # ontology submission URI
      ont_uri = ont.id # ontology URI
      abbreviation = acronym.empty? ? "" : "(#{acronym})"
      @onts_for_select << [name.strip + " " + abbreviation, ont_uri]
      @onts_for_js << "\"#{name.strip} #{abbreviation}\": \"#{acronym}\""
    end
    @onts_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }
  end

  def render_advanced_picker(custom_ontologies = nil, selected_ontologies = [], align_to_dom_id = nil)
    selected_ontologies ||= []
    init_ontology_picker(custom_ontologies, selected_ontologies)
    render :partial => "shared/ontology_picker_advanced", :locals => {
      :custom_ontologies => custom_ontologies, :selected_ontologies => selected_ontologies, :align_to_dom_id => align_to_dom_id
    }
  end

  def at_slice?
    !@subdomain_filter.nil? && !@subdomain_filter[:active].nil? && @subdomain_filter[:active] == true
  end

  def categories_for_select
    categories_for_select = []
    categories = LinkedData::Client::Models::Category.all
    categories.each do |c|
      categories_for_select << [ c.name, c.id ]
    end
    categories_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }
    categories_for_select
  end

  def groups_for_select
    groups_for_select = []
    groups = LinkedData::Client::Models::Group.all
    groups.each do |group|
      acronym = group.acronym || ""
      acronym = acronym.empty? ? "" : " (#{acronym})"
      groups_for_select << [ group.name + acronym, group.id ]
    end
    groups_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }
    groups_for_select
  end

  def truncate_with_more(text, options = {})
    length ||= options[:length] ||= 30
    trailing_text ||= options[:trailing_text] ||= " ... "
    link_more ||= options[:link_more] ||= "[more]"
    link_less ||= options[:link_less] ||= "[less]"
    more_text = " <a href='javascript:void(0);' class='truncated_more'>#{link_more}</a></span><span class='truncated_less'>#{text} <a href='javascript:void(0);' class='truncated_less'>#{link_less}</a></span>"
    more = text.length > length ? more_text : "</span>"
    output = "<span class='more_less_container'><span class='truncated_more'>#{truncate(text, :length => length, :omission => trailing_text)}" + more + "</span>"
  end


  # BACKPORTED RAILS 3 HELPERS

  def csrf_meta_tag
    if protect_against_forgery?
      out = %(<meta name="csrf-param" content="%s"/>\n)
      out << %(<meta name="csrf-token" content="%s"/>)
      out % [ Rack::Utils.escape_html(request_forgery_protection_token),
              Rack::Utils.escape_html(form_authenticity_token) ]
    end
  end

  DECIMAL_UNITS = {0 => :unit, 1 => :ten, 2 => :hundred, 3 => :thousand, 6 => :million, 9 => :billion, 12 => :trillion, 15 => :quadrillion,
    -1 => :deci, -2 => :centi, -3 => :mili, -6 => :micro, -9 => :nano, -12 => :pico, -15 => :femto}.freeze

  def number_to_human(number, options = {})
    options.symbolize_keys!

    number = begin
      Float(number)
    rescue ArgumentError, TypeError
      if options[:raise]
        raise InvalidNumberError, number
      else
        return number
      end
    end

    units = { :unit => "", :ten => "", :hundred => "", :thousand => "Thousand", :million => "Million", :billion => "Billion", :trillion => "Trillion", :quadrillion => "Quadrillion" }
    units.merge!(options.delete :units)
    options[:units] = units

    defaults = I18n.translate('number.format''number.format', :locale => options[:locale], :default => {})
    human    = I18n.translate('number.human.format''number.human.format', :locale => options[:locale], :default => {})
    defaults = defaults.merge(human)

    options = options.reverse_merge(defaults)
    #for backwards compatibility with those that didn't add strip_insignificant_zeros to their locale files
    options[:strip_insignificant_zeros] = true if not options.key?(:strip_insignificant_zeros)

    units = options.delete :units
    unit_exponents = case units
    when Hash
      units
    when String, Symbol
      I18n.translate("#{units}""#{units}", :locale => options[:locale], :raise => true)
    when nil
      I18n.translate("number.human.decimal_units.units""number.human.decimal_units.units", :locale => options[:locale], :raise => true)
    else
      raise ArgumentError, ":units must be a Hash or String translation scope."
    end.keys.map{|e_name| DECIMAL_UNITS.invert[e_name] }.sort_by{|e| -e}

    number_exponent = number != 0 ? Math.log10(number.abs).floor : 0
    display_exponent = unit_exponents.find{|e| number_exponent >= e }
    number /= 10 ** display_exponent

    unit = case units
    when Hash
      units[DECIMAL_UNITS[display_exponent]]
    when String, Symbol
      I18n.translate("#{units}.#{DECIMAL_UNITS[display_exponent]}""#{units}.#{DECIMAL_UNITS[display_exponent]}", :locale => options[:locale], :count => number.to_i)
    else
      I18n.translate("number.human.decimal_units.units.#{DECIMAL_UNITS[display_exponent]}""number.human.decimal_units.units.#{DECIMAL_UNITS[display_exponent]}", :locale => options[:locale], :count => number.to_i)
    end

    decimal_format = options[:format] || I18n.translate('number.human.decimal_units.format''number.human.decimal_units.format', :locale => options[:locale], :default => "%n %u")
    formatted_number = number_with_precision(number, options)
    decimal_format.gsub(/%n/, formatted_number).gsub(/%u/, unit).strip
  end

  # http://stackoverflow.com/questions/1293573/rails-smart-text-truncation
  def smart_truncate(s, opts = {})
    opts = {:words => 20}.merge(opts)
    if opts[:sentences]
      return s.split(/\.(\s|$)+/)[0, opts[:sentences]].map{|s| s.strip}.join('. ') + '. ...'
    end
    a = s.split(/\s/) # or /[ ]+/ to only split on spaces
    n = opts[:words]
    a[0...n].join(' ') + (a.size > n ? '...' : '')
  end

end

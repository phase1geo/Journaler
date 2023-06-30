public class Templates {

  private List<Template> _templates;

  public List<Template> templates {
    get {
      return( _templates );
    }
  }

  public signal void changed( string name, bool added );

  /* Default constructor */
  public Templates() {
    
    _templates = new List<Template>();

  }

  /* Returns the directory containing the templates.snippets file */
  private string xml_dir() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler" ) );
  }

  /* Returns the pathname of the templates.snippets file */
  private string xml_file() {
    return( GLib.Path.build_filename( xml_dir(), "templates.snippets" ) );
  }

  /* Adds the given template and sorts the result */
  public void add_template( Template template ) {

    if( find_by_name( template.name ) == null ) {
      _templates.append( template );
      _templates.sort((a, b) => {
        return( strcmp( a.name, b.name ) );
      });
    }

    save();
    changed( template.name, true );

  }

  /* Removes the given template based on its name */
  public bool remove_template( string name ) {

    var template = find_by_name( name );
    if( template != null ) {
      _templates.remove( template );
      save();
      changed( name, false );
      return( true );
    }

    return( false );

  }

  /* Returns the template associated with the given name.  If was not found, returns null */
  public Template? find_by_name( string name ) {

    foreach( var template in _templates ) {
      if( template.name == name ) {
        return( template );
      }
    }

    return( null );

  }

  /* Returns the snippet associated with the given template name */
  public GtkSource.Snippet? get_snippet( string name ) {

    var mgr = GtkSource.SnippetManager.get_default();
    var search_path = mgr.search_path;
    search_path += xml_dir();
    mgr.search_path = search_path;

    var snippet = mgr.get_snippet( "journaler-templates", null, Template.get_snippet_trigger( name ) );
    set_variables( snippet );

    return( snippet );

  }

  public void set_variables( GtkSource.Snippet snippet ) {

    try {
      var weather_cmd = "curl 'wttr.in?1uTFq'";
      var output      = "";
      Process.spawn_command_line_sync( weather_cmd, out output );
      snippet.get_context().set_constant( "WEATHER", output );
    } catch( SpawnError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Saves the current templates in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "snippets" );

    root->set_prop( "_group", "journaler-templates" );

    foreach( var template in _templates ) {
      root->add_child( template.save( doc ) );
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the available templates from XML format */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    Xml.Node* root = doc->get_root_element();

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "snippet") ) {
        var loaded   = false;
        var template = new Template.from_xml( it, out loaded );
        if( loaded ) {
          _templates.append( template );
        }
      }
    }

    delete doc;

    if( _templates.length() > 0 ) {
      changed( "", false );
    }

  }

}

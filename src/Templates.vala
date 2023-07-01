public class Templates {

  private List<Template> _templates;

  private Gee.HashMap<string,string> _snippet_vars;

  public List<Template> templates {
    get {
      return( _templates );
    }
  }
  public string news_feed_url  { get; set; default = "macworld.com/feed"; }
  public int    news_max_items { get; set; default = 5; }

  public signal void changed( string name, bool added );
  public signal void vars_available();

  /* Default constructor */
  public Templates() {
    
    _templates    = new List<Template>();
    _snippet_vars = new Gee.HashMap<string,string>();

    /* TODO - I don't really want to do this here */
    Idle.add(() => {
      collect_variables();
      return( false );
    });

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
    if( snippet != null ) {
      set_variables( snippet );
    }

    return( snippet );

  }

  /* Retrieves the daily weather */
  public void get_weather() {

    try {
      var lang        = Environment.get_variable( "LANGUAGE" );
      var weather_cmd = "wget -q -O - wttr.in/54703?1uTFQn&lang=%s".printf( lang );
      var output      = "";
      Process.spawn_command_line_sync( weather_cmd, out output );
      _snippet_vars.set( "WEATHER", "```\n" + output.chomp() + "\n```" );
    } catch( SpawnError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Gets the daily news from the stored RSS feeds */
  public void get_news() {

    try {
      var rss_cmd = "wget -q -O - %s".printf( news_feed_url );
      var output  = "";
      Process.spawn_command_line_sync( rss_cmd, out output );
      var rss = new RSS( output, news_max_items );
      _snippet_vars.set( "NEWS", rss.items );
    } catch( SpawnError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Gets the current location */
  public void get_location() {

    try {
      var simple   = new GClue.Simple.sync( "com.github.phase1geo.journaler", GClue.AccuracyLevel.STREET );
      var location = simple.get_location();
      _snippet_vars.set( "LOCATION", "lat: %g, long: %g".printf( location.latitude, location.longitude ) );
    } catch( Error e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Collects the available variables */
  public void collect_variables() {

    get_weather();
    get_news();
    // get_location();

    /* Indicate that the variables are now available */
    vars_available();

  }

  /* Returns the number of available variables */
  public int num_variables() {
    return( _snippet_vars.size );
  }

  /* Returns the variable at the given location */
  public string get_variable( int index ) {
    var name = "";
    var num  = 0;
    _snippet_vars.map_iterator().foreach((key, val) => {
      if( num++ == index ) {
        name = key;
        return( false );
      }
      return( true );
    });
    return( name );
  }

  /* Adds the available variable values to the provided snippet */
  public void set_variables( GtkSource.Snippet snippet ) {
    _snippet_vars.map_iterator().foreach((key, val) => {
      snippet.get_context().set_constant( key, val );
      return( true );
    });
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

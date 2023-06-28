public class Templates {

  private List<Template> _templates;

  public List<Template> templates {
    get {
      return( _templates );
    }
  }

  public signal void changed();

  /* Default constructor */
  public Templates() {
    
    _templates = new List<Template>();

  }

  /* Returns the pathname of the journals.xml file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "templates.xml" ) );
  }

  /* Adds the given template and sorts the result */
  public void add_template( Template template ) {

    _templates.append( template );
    _templates.sort((a, b) => {
      return( strcmp( a.name, b.name ) );
    });

    changed();

  }

  /* Removes the given template based on its name */
  public bool remove_template( string name ) {

    var template = find_by_name( name );
    if( template != null ) {
      _templates.remove( template );
      changed();
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

  /* Saves the current templates in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "templates" );

    root->set_prop( "version", Journaler.version );

    foreach( var template in _templates ) {
      root->add_child( template.save() );
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

    var v = root->get_prop( "version" );
    if( v != null ) {
      check_version( v );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "template") ) {
        var loaded   = false;
        var template = new Template.from_xml( it, out loaded );
        if( loaded ) {
          _templates.append( template );
        }
      }
    }

    delete doc;

  }

  /* Allows us to check the stored version against our own to do any necessary updates */
  private void check_version( string version ) {

    // TBD

  }

}

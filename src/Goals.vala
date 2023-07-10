using Gee;

public class Goals {

  private HashMap<string,int> _goals;

  /* Default constructor */
  public Goals() {

    _goals = new HashMap<string,int>();

  }

  /* Returns the pathname of the XML file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "goals.xml" ) );
  }

  /* Saves the goal information in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "goals" );

    root->set_prop( "version", Journaler.version );

    _goals.map_iterator().foreach((key,val) => {
      Xml.Node* node = new Xml.Node( null, "goal" );
      node->set_prop( "name", key );
      node->set_prop( "value", val.to_string() );
      root->add_child( node );
      return( true );
    });

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the stored goal information in XML format */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var verson = root->get_prop( "version" );
    if( verson != null ) {
      check_version( verson );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "goal") ) {
        var n = it->get_prop( "name" );
        var v = it->get_prop( "value" );
        if( (n != null) && (v != null) ) {
          _goals.set( n, int.parse( v ) );
        }
      }
    }

    delete doc;

  }

  /* Allows us to make upgrades based on version information */
  private void check_version( string version ) {

    // TBD

  }

}

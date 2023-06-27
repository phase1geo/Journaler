public class Template {

  public string name { get; set; default = "Template"; }
  public string text { get; set; default = ""; }

  /* Default constructor */
  public Template() {
  }

  /* Constructor */
  public Template.from_xml( Xml.Node* node, out bool loaded ) {

    loaded = load( node );

  }

  /* Saves the template in XML format */
  public Xml.Node* save() {

    Xml.Node* node = new Xml.Node( null, "template" );

    node->set_prop( "name", name );
    node->set_content( text );

    return( node );

  }

  /* Loads the template data from XML format */
  public bool load( Xml.Node* node ) {

    var loaded = false;

    var n = node->get_prop( "name" );
    if( n != null ) {
      name   = n;
      loaded = true;
    }

    if( (node->children != null) && (node->children->type == Xml.ElementType.TEXT_NODE) ) {
      text = node->children->get_content();
    }

    return( loaded );

  }

}
